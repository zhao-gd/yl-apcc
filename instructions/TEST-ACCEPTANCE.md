# TEST-ACCEPTANCE.md — yl-tester 验收硬阈值清单

> 依据：doc/ai-native-sdlc.md（对照 Anthropic 的 feature list 机制）。
> 原则：**任一硬阈值不过 = 打回，不打折；自测通过才标记 passes，禁止为了通过而删改验收项。**
> DoD 口径：issue 定案评论的量化验收项见 `doc/definition-of-done.md`（DoD 模板），是下面第 1 项「功能满足」的输入；无证据锚的 PASS 一律视为 FAIL。

## 硬阈值清单（6 项，全部必须 PASS）

| # | 验收项 | 怎么验（steps）| 通过标准（passes）|
|---|---|---|---|
| 1 | **功能满足** | 对照 PR 正文「done 的定义」+ issue 定案评论的 DoD（关键词/残留 0 命中清单、逐项 PASS 记录、端到端证据）逐条验证 | 逐条 PASS，且每条附证据锚（CI URL / 输出片段 / rg 命中数 / 日志摘录 / 截图）|
| 2 | **CI 门禁** | 查 PR 的 check status | `check / branch-discipline (pull_request)` 绿 |
| 3 | **回归不破** | 跑受影响的主流程/相关测试 | 无新增回归 |
| 4 | **测试覆盖** | `pytest`（tests/ 若有）+ 端到端验证；渠道/协议/dsh bridge/执行底座/一级契约类变更须附真机冒烟证据（`doc/true-machine-smoke.md`） | 全绿，无跳过关键用例；真机冒烟证据评论到 issue（附 ret=0 / final_buf_len / 日志摘录 / 截图） |
| 5 | **凭证安全** | CI 凭证扫描结果 | 无泄漏 |
| 6 | **提交规范** | 看 commit author + message | `yl-*@<email域>` 身份 + `Refs: gitea issue #xx` 关联 |

## 验收结论（三选一，写进 PR review）

- **✅ 通过**：6 项全 PASS → 由 yl-tester 合并（唯一合并权），并关闭对应 issue。
- **❌ 不通过**：任一 FAIL → 打回，在 review 里写清「哪一项、为什么、怎么复现」。
- **⏸️ 待补充**：缺测试/缺上下文 → 列出缺失项，等 yl-dev 补齐再验。

## 验收记录（落盘到 Gitea）

每次验收的结论，直接落盘到 Gitea（PR review + 关联 issue 评论），保持可追溯：

- **PR review**：按上面「验收结论」三选一提交——通过 = `APPROVED`、打回 = `REQUEST_CHANGES`、待补充 = `COMMENT`；review 正文写清 6 项逐条判定 + 结论。
- **关联 issue 评论**：在 issue 下追加一条验收记录评论，写明 PR、结论、时间戳。

> 验收结论只落 Gitea（PR review + issue 评论），不落业务域的技能/知识库工具。
