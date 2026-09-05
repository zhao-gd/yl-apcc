#!/usr/bin/env bash
# yl-apcc install.sh —— 脚本就绪检查/引导（幂等）
#
# 职责：确保可执行脚本（tools/）能被正确引用和运行，仅此而已：
#   ① 边界说明：tools 外部化；instructions/preset/check.yml 框架给模板、项目方自管自优
#   ② 配置 YL_APCC_ROOT 到 dsh 服务 drop-in（角色经 $YL_APCC_ROOT/tools/... 引用脚本）
#   ③ 幂等创建 Git 平台 labels（脚本依赖的平台配置）
#   ④ 检查签名密钥 + Gitea token（脚本运行的依赖）
#
# 不做：persona / AGENTS.md 系列 / check.yml 的部署——这些归项目方自己维护，
#   框架只在 presets/ instructions/ ci/ 里给模板参考。
#
# 环境变量（不设则用默认值）：
#   YL_APCC_ROOT    APCC 安装目录（默认本脚本所在目录）
#   DSH_SERVICE     dsh systemd 服务名（默认 dsh-yingloong）
#   GITEA           Git 平台 base URL（默认 http://127.0.0.1:3000）
#   GITEA_REPO      目标业务仓库 owner/repo（默认从 $WORK 的 git remote 推断）
#   GITEA_TOKEN     Git API token（默认读 /var/lib/yingloong/gitea-token）
#   WORK            项目工作目录（git 仓库根，默认 /opt/yingloong）
#   GIT_SIGNING_DIR 签名密钥目录（默认 /var/lib/yingloong/git-signing）
#
# 用法：
#   ./install.sh                                        # 默认引导
#   WORK=/path/repo DSH_SERVICE=foo-dsh ./install.sh     # 跨项目引导
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/opt/yingloong}"
DSH_SERVICE="${DSH_SERVICE:-dsh-yingloong}"
GITEA="${GITEA:-http://127.0.0.1:3000}"
GITEA_REPO="${GITEA_REPO:-}"
GIT_SIGNING_DIR="${GIT_SIGNING_DIR:-/var/lib/yingloong/git-signing}"
TOKEN_FILE="${TOKEN_FILE:-/var/lib/yingloong/gitea-token}"
YL_APCC_ROOT="${YL_APCC_ROOT:-$REPO_DIR}"

# 仓库名推断（供 labels 配置）
if [ -z "$GITEA_REPO" ]; then
  _remote="$(git -C "$WORK" remote get-url origin 2>/dev/null || true)"
  _p="${_remote##*:}"; _p="${_p%.git}"; _p="${_p#/}"
  GITEA_REPO="$(printf '%s' "$_p" | grep -oE '[^/]+/[^/]+$' || true)"
fi

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# ── ① 边界说明（不部署 persona/instructions/check.yml）──────────────
say "① 边界：tools 外部化（\$YL_APCC_ROOT/tools/）；instructions/preset/check.yml 框架给模板、项目方自管自优"

# ── ② 配置 YL_APCC_ROOT（脚本引用核心）───────────────────────────────
say "② 配置 YL_APCC_ROOT=$YL_APCC_ROOT 到 $DSH_SERVICE drop-in"
DROPIN="/etc/systemd/system/$DSH_SERVICE.service.d/yl-apcc-root.conf"
if sudo -n true 2>/dev/null; then
  sudo mkdir -p "$(dirname "$DROPIN")"
  printf '[Service]\nEnvironment=YL_APCC_ROOT=%s\n' "$YL_APCC_ROOT" | sudo tee "$DROPIN" >/dev/null
  sudo systemctl daemon-reload
  echo "  已写入 $DROPIN（重启 $DSH_SERVICE 生效）"
else
  echo "  ⚠️ 无 sudo，跳过 drop-in 写入；请手动确保 YL_APCC_ROOT=$YL_APCC_ROOT"
fi

# ── ③ 幂等创建 Git 平台 labels（脚本依赖的平台配置）──────────────────
say "③ 幂等创建 Git 平台 labels"
TOKEN="${GITEA_TOKEN:-$(cat "$TOKEN_FILE" 2>/dev/null || true)}"
if [ -n "$TOKEN" ] && [ -f "$REPO_DIR/gitea/labels.yaml" ]; then
  python3 - "$GITEA" "$TOKEN" "$REPO_DIR/gitea/labels.yaml" "$GITEA_REPO" "$WORK" <<'PY'
import sys, json, urllib.request, subprocess

base, token, labels_file, repo_arg, work = sys.argv[1:6]

if repo_arg and "/" in repo_arg:
    owner, repo = repo_arg.split("/", 1)
else:
    out = subprocess.run(["git", "-C", work, "remote", "get-url", "origin"],
                         capture_output=True, text=True).stdout.strip()
    path = out.split(":")[-1].replace(".git", "").strip("/")
    parts = path.split("/")
    if len(parts) >= 2:
        owner, repo = parts[-2], parts[-1]
    else:
        print("  ⚠️ 无法推断 owner/repo，跳过 labels 配置"); sys.exit(0)

import yaml
wanted = [l["name"] for l in (yaml.safe_load(open(labels_file)) or {}).get("labels", [])]

def api(path, method="GET", data=None):
    req = urllib.request.Request(
        f"{base}/api/v1{path}",
        data=json.dumps(data).encode() if data else None,
        method=method,
        headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None

existing = {l["name"] for l in api(f"/repos/{owner}/{repo}/labels") or []}
created = 0
for name in wanted:
    if name in existing:
        continue
    api(f"/repos/{owner}/{repo}/labels", "POST", {"name": name, "color": "8f8f8f"})
    created += 1
print(f"  labels：已存在 {len(existing)} 个，新建 {created} 个（目标 {owner}/{repo}）")
PY
else
  echo "  ⚠️ 无 GITEA_TOKEN 或 labels.yaml，跳过 labels 配置"
fi

# ── ④ 检查签名密钥 + Gitea token（脚本运行的依赖）────────────────────
say "④ 检查签名密钥"
for r in planner dev tester ops releaser apcc; do
  key="$GIT_SIGNING_DIR/yl-$r/id_ed25519"
  [ -f "$key" ] || echo "  ⚠️ 缺少 yl-$r 签名私钥 $key（生成并录入 Git 平台）"
done

say "⑤ 检查 Gitea token"
TOKEN_DIR_CHECK="${GITEA_TOKEN_DIR:-/var/lib/yingloong/gitea-tokens}"
for r in planner dev tester ops releaser apcc; do
  t="$TOKEN_DIR_CHECK/yl-$r"
  [ -f "$t" ] || echo "  ⚠️ 缺少 yl-$r 预置 token（$t）——用 get_token.sh 受控读取，禁止现场自造"
done

say "✅ APCC 脚本就绪（tools 经 \$YL_APCC_ROOT 引用；persona/instructions/check.yml 由项目方自管）"
