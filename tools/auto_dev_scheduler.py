#!/usr/bin/env python3
"""自动开发调度器 —— 按 label 状态机自动流转 issue。

工作流（两阶段）：
  阶段一【方案讨论，不自动化】：issue 建后进入「讨论中」，planner 出方案 +
  dev/tester 参与讨论，用户拍板后要求 planner 定案，打「已定案」label。
  阶段二【定案后自动化】：从这里开始才自动流转。

状态机（自动化段，label 标记）：
  已定案 ──dev──▶ 待测试 ──tester(过)──▶ 完成
      ▲               │
      └─── 返工 ──────┘ (tester 打回 → 返工中 → dev 改 → 待测试)

返工上限：同一 issue 返工 ≥ 3 轮 → 停自动 + 打「需人工」+ 告警。
「讨论中」/无状态机 label 的 issue 一律不碰（讨论环节由人主导）。

用法：auto_dev_scheduler.py [--dry-run]
  --dry-run  只打印将触发的动作，不真正触发
"""
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import urllib.request

GITEA = "http://127.0.0.1:3000"
REPO = "yingloong/yingloong"
API = f"{GITEA}/api/v1/repos/{REPO}"
TOKEN_FILE = "/var/lib/yingloong/gitea-token"
APCC_ROOT = os.environ.get("YL_APCC_ROOT", "/opt/yl-apcc")
TRIGGER = f"{APCC_ROOT}/tools/trigger_role.sh"


def _load_token():
    """从环境变量 GITEA_TOKEN 或凭证文件读取 API token（禁止硬编码）。"""
    tok = os.environ.get("GITEA_TOKEN", "").strip()
    if tok:
        return tok
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    raise SystemExit(f"缺少 Gitea token：设置 GITEA_TOKEN 环境变量或 {TOKEN_FILE}")


TOKEN = _load_token()
RETAKE_LIMIT = 3  # 返工上限
PARALLEL = int(os.environ.get("APCC_PARALLEL", "3"))  # 并行触发上限
WORKTREE_ROOT = "/opt/yingloong-wt"  # 并行 worktree 根目录
MAIN_WORK = "/opt/yingloong"  # 主仓库工作区


def api(path, method="GET", data=None):
    req = urllib.request.Request(
        f"{API}{path}",
        data=json.dumps(data).encode() if data else None,
        method=method,
        headers={"Content-Type": "application/json",
                 "Authorization": f"token {TOKEN}"},
    )
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None


def labels(issue):
    return {l["name"] for l in issue.get("labels", [])}


def _label_id_map():
    """仓库 label name → id 映射（Gitea 打 label 要 id）。"""
    return {l["name"]: l["id"] for l in api("/labels")}


def set_labels(issue_num, add=(), remove=()):
    """给 issue 打/去 label（按 name 增删，用专用 label 端点）。

    注意：Gitea 1.27 的 PATCH /issues/{n} 的 EditIssueOption 无 labels 字段，
    必须用 POST /issues/{n}/labels（增）与 DELETE /issues/{n}/labels/{id}（删）。
    """
    name2id = _label_id_map()
    cur = {l["name"] for l in api(f"/issues/{issue_num}")["labels"]}
    for n in remove:
        if n in cur and n in name2id:
            api(f"/issues/{issue_num}/labels/{name2id[n]}", "DELETE")
    add_ids = [name2id[n] for n in add if n in name2id and n not in cur]
    if add_ids:
        api(f"/issues/{issue_num}/labels", "POST", {"labels": add_ids})


def _branch_exists(issue_num):
    """检查是否已有该 issue 的活跃分支（防重复开发，fail-open）。"""
    try:
        pat = re.compile(rf'/{issue_num}($|-)')
        branches = api("/branches")
        return any(pat.search(b.get("name", "")) for b in branches)
    except Exception:
        return False  # 查询失败不阻断（靠命名纪律兜底）


def _auto_branch(issue):
    """从 issue 标题自动生成分支名 type/N-slug（与 #18 命名规范一致）。"""
    num = issue["number"]
    title = issue.get("title", "")
    m = re.match(r'^([A-Za-z]+)', title)
    typ = m.group(1).lower() if m and m.group(1).lower() in ("feat", "fix", "docs", "refactor", "chore", "test") else "fix"
    slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')[:30]
    return f"{typ}/{num}-{slug}"


def _prepare_worktree(issue_num, branch):
    """为 issue 创建独立 worktree（fail-closed）。返回 (workdir, ok)。"""
    wt = f"{WORKTREE_ROOT}/{issue_num}"
    if os.path.isdir(wt):
        return wt, True  # 已存在，复用
    try:
        subprocess.run(["git", "-C", MAIN_WORK, "fetch", "origin", "main"],
                       check=True, capture_output=True, timeout=120)
        r = subprocess.run(
            ["git", "-C", MAIN_WORK, "worktree", "add", "-b", branch, wt, "origin/main"],
            capture_output=True, text=True, timeout=120,
        )
        if r.returncode != 0:
            print(f"⚠️ issue #{issue_num} worktree 创建失败：{r.stderr.strip()[:200]}")
            return wt, False
        print(f"  已创建 worktree: {wt}（分支 {branch}）")
        return wt, True
    except Exception as e:
        print(f"⚠️ issue #{issue_num} worktree 创建异常：{e}")
        return wt, False


def _cleanup_worktrees():
    """清理对应 issue 已关闭/完成的孤儿 worktree（幂等，fail-open）。"""
    if not os.path.isdir(WORKTREE_ROOT):
        return
    for name in sorted(os.listdir(WORKTREE_ROOT)):
        if not name.isdigit():
            continue
        wt = os.path.join(WORKTREE_ROOT, name)
        if not os.path.isdir(wt):
            continue
        issue_num = int(name)
        try:
            iss = api(f"/issues/{issue_num}")
        except Exception:
            continue  # 查询失败跳过，下轮再试
        done = iss.get("state") == "closed" or "完成" in {l["name"] for l in iss.get("labels", [])}
        if not done:
            continue
        r = subprocess.run(
            ["git", "-C", MAIN_WORK, "worktree", "remove", "--force", wt],
            capture_output=True, text=True, timeout=120,
        )
        if r.returncode == 0:
            print(f"  已清理 worktree: {wt}（issue #{issue_num} 已完成）")
        else:
            subprocess.run(["git", "-C", MAIN_WORK, "worktree", "prune"], capture_output=True)
            print(f"⚠️ worktree {wt} 清理失败，需人工处理：{r.stderr.strip()[:150]}")


def trigger(role, task, dry_run, workdir=None):
    print(f"  → 触发 {role}: {task[:60]}")
    if not dry_run:
        cmd = [TRIGGER, role, task]
        if workdir:
            cmd.append(workdir)
        subprocess.run(cmd, check=False, timeout=1800)


def main():
    import os
    if os.path.exists("/var/lib/yingloong/logs/scheduler.pause"):
        print("调度器已暂停（存在 scheduler.pause，删掉它恢复）")
        return
    dry_run = "--dry-run" in sys.argv
    if not dry_run:
        _cleanup_worktrees()  # 先清理已完成的孤儿 worktree
    issues = api("/issues?state=open&type=issues&limit=50")

    todo = []  # (action, issue)
    for iss in issues:
        num = iss["number"]
        lab = labels(iss)
        # 返工计数：label「返工N」
        retake = max([int(l[2:]) for l in lab if l.startswith("返工") and l[2:].isdigit()] or [0])
        if "需人工" in lab or "完成" in lab:
            continue
        if retake >= RETAKE_LIMIT:
            if not dry_run:
                set_labels(num, add=["需人工"])
            print(f"⚠️ issue #{num} 返工 {retake} 轮，停止自动，打「需人工」（应发飞书告警）")
            continue
        if "已定案" in lab:
            if _branch_exists(num):
                print(f"⚠️ issue #{num} 已有活跃分支，跳过本次触发（防重复开发）")
                continue
            branch = _auto_branch(iss)
            if dry_run:
                workdir, ok = f"{WORKTREE_ROOT}/{num}", True  # dry-run 不真创建
            else:
                workdir, ok = _prepare_worktree(num, branch)
            if not ok:
                print(f"⚠️ issue #{num} worktree 创建失败，跳过（fail-closed）")
                continue
            todo.append(("yl-dev", f"开发 issue #{num}（分支 {branch}，在 worktree {workdir} 工作；完成后 push 分支开 PR 并打「待测试」去掉「已定案」）", iss, workdir))
        elif "返工中" in lab:
            todo.append(("yl-dev", f"按 tester 的返工意见修改 issue #{num}，更新 PR 后打「待测试」label 去掉「返工中」", iss, None))
        elif "待测试" in lab:
            todo.append(("yl-tester", f"验收 issue #{num} 的 PR（按 TEST-ACCEPTANCE.md 6 项，通过则合并+关 issue 打「完成」；失败则评论问题+打「返工{retake+1}」label）", iss, None))

    print(f"=== 调度一轮：{len(todo)} 个待推进（并行上限 {PARALLEL}）===")
    if todo and not dry_run:
        with concurrent.futures.ThreadPoolExecutor(max_workers=PARALLEL) as ex:
            list(ex.map(lambda t: trigger(t[0], t[1], False, t[3]), todo))
    else:
        for role, task, _iss, workdir in todo:
            trigger(role, task, dry_run, workdir)
    if not todo:
        print("  （无待推进）")


if __name__ == "__main__":
    main()
