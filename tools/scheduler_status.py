#!/usr/bin/env python3
"""自动开发调度器进度面板 —— 一屏看所有 open issue 的状态机进度。

用法：scheduler_status.py
"""
import json
import os
import urllib.request

API = "http://127.0.0.1:3000/api/v1/repos/yingloong/yingloong"
TOKEN_FILE = "/var/lib/yingloong/gitea-token"
PAUSE = "/var/lib/yingloong/logs/scheduler.pause"


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
STATES = ("已定案", "待测试", "返工中", "需人工", "完成", "讨论中")


def api(path):
    req = urllib.request.Request(
        f"{API}{path}",
        headers={"Authorization": f"token {TOKEN}"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def main():
    import os
    paused = os.path.exists(PAUSE)
    print(f"调度器状态：{'⏸ 已暂停' if paused else '▶ 运行中'}")
    print()
    issues = api("/issues?state=open&type=issues&limit=100")
    active = [i for i in issues if any(l["name"] in STATES for l in i["labels"])]
    print(f"open issue 总数：{len(issues)}，其中已签入自动流水线：{len(active)}")
    print()
    if not active:
        print("（当前没有 issue 在自动流水线里）")
        return
    for i in active:
        labs = [l["name"] for l in i["labels"]]
        state = [s for s in STATES if s in labs]
        print(f"  #{i['number']} [{','.join(state) or '?'}] {i['title'][:50]}")


if __name__ == "__main__":
    main()
