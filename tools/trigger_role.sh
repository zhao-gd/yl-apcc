#!/bin/bash
# trigger_role.sh <role> <task> [--worktree <path>] [--dry-run] —— 触发 headless 任务
#
# issue #20 去串行化：headless profile 自带 persona，直接 --profile，无需切 default。
# issue #40 空任务防护：拒绝空串/占位符，防空转。
# issue #41 崩溃解耦：用 systemd-run 起独立 transient 单元，脱离 dsh-yingloong 服务
#   的 cgroup——web 服务崩溃重启（KillMode=control-group）只杀自身 cgroup，不连带 headless。
# issue #1(gh) 并行隔离：--worktree 锁按 worktree 粒度（多 issue 并行）+ --dry-run 演练
#   + flock 防重入（非阻塞，拿不到锁跳过本轮）+ 单次超时 1800s + 失败重试 1 次。
#
# 用法:
#   trigger_role.sh yl-dev "开发 issue #125 ..."                    # 固定 checkout，锁按角色（串行）
#   trigger_role.sh yl-dev "..." --worktree /opt/yingloong-wt/125   # 锁按 worktree（多 issue 并行）
#   trigger_role.sh yl-dev "..." --dry-run                          # 只打印动作，不真跑
set -euo pipefail

ROLE="${1:?用法: trigger_role.sh <role> <task> [--worktree <path>] [--dry-run]}"
TASK="${2:?需要 task}"
shift 2

# 空任务防护（#40）：拒绝空串/占位符，防空转
if [ -z "${TASK//[[:space:]]/}" ] || printf '%s' "$TASK" | grep -qE '^<[^>]*>$'; then
  echo "错误: task 为空或占位符，拒绝触发（防空转）" >&2
  exit 1
fi

# 解析可选参数（#1）
WORKTREE=""
DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) WORKTREE="${2:?--worktree 需要路径}"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    *) echo "未知参数: $1" >&2; exit 3 ;;
  esac
done

FIXED_WORKDIR="/opt/yingloong"
TIMEOUT=1800
# 运行用户/家目录（部署方可用 YL_RUN_USER/YL_RUN_HOME 覆盖；默认取当前用户，
# 框架层不硬编码账号名，开源中性化自检才能通过）
RUN_USER="${YL_RUN_USER:-$(id -un)}"
RUN_HOME="${YL_RUN_HOME:-$HOME}"

# 锁粒度（#1）：有 worktree 按 worktree（= issue 并行），否则按角色（串行）
if [ -n "$WORKTREE" ]; then
  LOCK_KEY="wt-$(basename "$WORKTREE")"
  WORKDIR="$WORKTREE"
else
  LOCK_KEY="$ROLE"
  WORKDIR="$FIXED_WORKDIR"
fi
LOCK="/tmp/trigger-${LOCK_KEY}.lock"

PROFILE="${ROLE}-headless"
UNIT="yl-headless-${ROLE}-$$"

# --dry-run：只打印将触发的动作，不校验文件、不真跑 dsh（#1）
if [ -n "$DRY_RUN" ]; then
  echo "DRY-RUN: 触发 $ROLE（工作目录=$WORKDIR，锁粒度=$LOCK_KEY，超时=${TIMEOUT}s）: $TASK"
  exit 0
fi

# flock 防重入（#1）：非阻塞，拿不到锁 = 该 issue/角色正在被触发，跳过本轮
exec 9>"$LOCK"
flock -n 9 || { echo "⚠️ $LOCK_KEY 正在被触发，跳过本轮"; exit 4; }

# 单次触发（#1：timeout 包 dsh；#41：systemd-run 解耦）
run_once() {
  if command -v systemd-run >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n systemd-run --wait --collect \
      --uid="$RUN_USER" \
      --working-directory="$WORKDIR" \
      --setenv="DSH_HOME=/var/lib/yingloong/dsh-home" \
      --setenv="HOME=$RUN_HOME" \
      --setenv="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      --setenv="YL_APCC_ROOT=${YL_APCC_ROOT:-/opt/yl-apcc}" \
      --unit="$UNIT" \
      timeout "$TIMEOUT" dsh --profile "$PROFILE" "$TASK"
  else
    # 回退：无 systemd-run/sudo 时直接前台跑（旧行为）
    cd "$WORKDIR"
    timeout "$TIMEOUT" dsh --profile "$PROFILE" "$TASK"
  fi
}

# 失败重试 1 次（#1）：仍失败则返回非 0（调用方转「需人工」）
run_once && exit 0
echo "⚠️ 首次触发失败，重试 1 次..."
run_once && exit 0
echo "❌ 重试仍失败，需人工介入" >&2
exit 2
