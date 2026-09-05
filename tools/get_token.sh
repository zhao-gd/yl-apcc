#!/usr/bin/env bash
# get_token <role> —— 受控读取数字员工 Gitea token
#
# 用法: TOKEN="$(get_token yl-tester)"
#   <role> 为完整角色名，如 yl-dev / yl-tester / yl-planner / yl-releaser / yl-ops / yl-apcc
#
# token 预置位置: /var/lib/yingloong/gitea-tokens/<role>（平台侧受控注入，最小权限）
# 可用环境变量 GITEA_TOKEN_DIR 覆盖 token 目录。
#
# 铁律（对齐 yl-apcc #3）:
#   - 数字员工一律经本脚本取 token，禁止 docker exec / gitea admin 现场自造。
#   - token 只捕获进变量使用，禁止写入代码 / commit / issue / 日志。
#   - 缺失即报错退出，绝不临场生成（fail-closed）。
set -euo pipefail

ROLE="${1:?用法: get_token <role>（如 yl-tester）}"
TOKEN_DIR="${GITEA_TOKEN_DIR:-/var/lib/yingloong/gitea-tokens}"
TOKEN_FILE="${TOKEN_DIR}/${ROLE}"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "错误: 找不到 ${ROLE} 的预置 token（${TOKEN_FILE}）。禁止现场自造 token，请联系平台侧注入。" >&2
  exit 1
fi

# 只输出 token 本身（调用方用 $(...) 捕获，勿 echo 到日志）
cat "$TOKEN_FILE"
