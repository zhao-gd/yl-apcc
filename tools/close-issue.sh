#!/usr/bin/env bash
# close-issue.sh <issue> [--comment "<text>"] [--label <label>] —— 幂等收尾：打完成 label + 留评论 + 关 issue
#
# 用途：盯执行收尾类任务（验收已 APPROVED、证据锚已齐，只差收尾三步）脚本化，
#   agent 一次调用完成，避免 36 步 max-effort 往返（对应 gh issue #3）。
# 对齐边界：可执行脚本 APCC 官方维护。
#
# 用法:
#   close-issue.sh 372
#   close-issue.sh 372 --comment "合并于 PR #165（squash）"
#   close-issue.sh 372 --label 完成
#
# 环境变量:
#   GITEA           Git 平台 base URL，默认 http://127.0.0.1:3000
#   GITEA_REPO      owner/repo，默认从当前目录 git remote 推断
#   GITEA_TOKEN_DIR token 目录，默认 /var/lib/yingloong/gitea-tokens
#   CLOSE_ROLE      收尾角色（其 token 用于关 issue），默认 yl-tester（关闭权在测试）
#   CLOSE_LABEL     完成 label 名，默认「完成」
set -euo pipefail

ISSUE="${1:?用法: close-issue.sh <issue> [--comment \"<text>\"] [--label <label>]}"
shift || true

COMMENT=""
LABEL="${CLOSE_LABEL:-完成}"
while [ $# -gt 0 ]; do
  case "$1" in
    --comment) COMMENT="${2:?--comment 需要文本}"; shift 2 ;;
    --label)   LABEL="${2:?--label 需要文本}"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

GITEA="${GITEA:-http://127.0.0.1:3000}"
GITEA_TOKEN_DIR="${GITEA_TOKEN_DIR:-/var/lib/yingloong/gitea-tokens}"
CLOSE_ROLE="${CLOSE_ROLE:-yl-tester}"

# token 受控读取（铁律：禁止现场自造，缺失即 fail-closed）
TOKEN="$(cat "$GITEA_TOKEN_DIR/$CLOSE_ROLE" 2>/dev/null || true)"
if [ -z "$TOKEN" ]; then
  echo "错误: 找不到 $CLOSE_ROLE 的预置 token（$GITEA_TOKEN_DIR/$CLOSE_ROLE）" >&2
  echo "请平台侧受控注入，勿现场自造。" >&2
  exit 1
fi

# 仓库名推断（同 install.sh：git remote → owner/repo）
if [ -z "${GITEA_REPO:-}" ]; then
  _remote="$(git remote get-url origin 2>/dev/null || true)"
  _p="${_remote##*:}"; _p="${_p%.git}"; _p="${_p#/}"
  GITEA_REPO="$(printf '%s' "$_p" | grep -oE '[^/]+/[^/]+$' || true)"
fi
REPO="${GITEA_REPO:-yingloong/yingloong}"
BASE="$GITEA/api/v1/repos/$REPO"

# 用 python3 完成全部 API 调用与 JSON 处理（label 名含中文，避开 shell 转义）
python3 - "$BASE" "$TOKEN" "$ISSUE" "$LABEL" "$COMMENT" <<'PY'
import sys, json, urllib.request, urllib.error

base, token, issue, label, comment = sys.argv[1:6]

def api(path, method="GET", data=None):
    req = urllib.request.Request(
        f"{base}{path}",
        data=json.dumps(data).encode() if data is not None else None,
        method=method,
        headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        return {"_http_error": e.code, "_body": e.read().decode(errors="replace")}

# 1) 打完成 label（幂等：label 不存在则创建）
labels = api("/labels?limit=100") or []
label_id = next((l["id"] for l in labels if l.get("name") == label), None)
if label_id is None:
    created = api("/labels", "POST", {"name": label, "color": "8f8f8f"})
    label_id = (created or {}).get("id")
    if label_id:
        print(f"  已创建 label「{label}」（id={label_id}）")
if label_id:
    api(f"/issues/{issue}/labels", "PUT", {"labels": [label_id]})
    print(f"  ✅ 已打 label「{label}」")
else:
    print(f"  ⚠️ 无法定位/创建 label「{label}」，跳过")

# 2) 留评论（可选）
if comment:
    api(f"/issues/{issue}/comments", "POST", {"body": comment})
    print("  ✅ 已留评论")

# 3) 关 issue（幂等：已关则提示）
cur = api(f"/issues/{issue}") or {}
if cur.get("state") == "closed":
    print(f"  ⚠️ issue #{issue} 已关闭，跳过")
else:
    api(f"/issues/{issue}", "PATCH", {"state": "closed"})
    print(f"  ✅ issue #{issue} 已关闭")

print(f"✅ 收尾完成：#{issue}（label={label}{'，已留评论' if comment else ''}）")
PY
