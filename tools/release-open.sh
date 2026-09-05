#!/usr/bin/env bash
# release-open.sh —— 开源发布：从私有仓库导出干净快照到公开仓库
#
# 用法:
#   OPEN_REMOTE=<公开仓库地址> ./release-open.sh
#
# 流程（fail-closed，任一步失败即停）：
#   ① 中性化自检：框架层无品牌名/账号名泄漏
#   ② 导出框架层：剥离 projects/（私有层不进公开仓库）
#   ③ squash 重建：新 git 仓库，owner 身份单 commit（剥离内网历史/个人邮箱）
#   ④ 换公开 remote + push
#
# 说明：
#   - 私有仓库保留完整历史与内网 remote，本脚本不动它，只导出快照。
#   - 公开仓库不保留内网 SSH 签名链（squash 重建后重新签或免签）。
#   - 脚本只导出框架层；projects/<项目>/ 是私有资产，永不上公开。
set -euo pipefail

OPEN_REMOTE="${OPEN_REMOTE:?用法: OPEN_REMOTE=<公开仓库地址> ./release-open.sh}"
VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo dev)"

# ── ① 中性化自检（框架层无品牌/账号泄漏）─────────────────────────────
echo "① 中性化自检（框架层无品牌/账号泄漏）"
LEAK="$(grep -rInE '应龙|莺龙|赵国栋|zhaogd|zhao_gd' \
  --exclude=release-open.sh --exclude=AUTHORS.md \
  tools/ instructions/ presets/ gitea/ docs/ ci/ \
  README.md CONTRIBUTING.md CHANGELOG.md install.sh 2>/dev/null || true)"
if [ -n "$LEAK" ]; then
  echo "::error::框架层残留品牌/账号，中止发布："
  printf '%s\n' "$LEAK"
  exit 1
fi
echo "  通过（无品牌/账号泄漏）"

# ── ② 导出框架层（显式列路径，剥离 projects/）────────────────────────
echo "② 导出框架层（剥离 projects/ 私有层）"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git archive --format=tar HEAD \
  tools instructions presets gitea docs ci \
  install.sh README.md CONTRIBUTING.md AUTHORS.md LICENSE CHANGELOG.md .gitignore \
  | tar -x -C "$TMP"
echo "  已导出到临时目录（projects/ 未包含）"

# ── ③ squash 重建（新 git 仓库，owner 身份单 commit）──────────────────
echo "③ squash 重建历史（owner 身份，剥离内网历史/个人邮箱）"
cd "$TMP"
git init -q -b main
git add -A
git -c user.name="owner" -c user.email="owner@yingloong.local" \
  commit -q -m "yl-apcc ${VERSION}: Agentic PR/CI/CD framework

Open-source release. Framework layer only (projects/ excluded).
See CONTRIBUTING.md for contribution guide."
echo "  已重建为单 commit（owner 身份）"

# ── ④ 换公开 remote + push ────────────────────────────────────────────
echo "④ 推送公开仓库: ${OPEN_REMOTE}"
git remote add origin "$OPEN_REMOTE"
git push -u -f origin main

echo "✅ 开源发布完成：${VERSION} → ${OPEN_REMOTE}"
