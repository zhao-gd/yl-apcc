# AGENTS.md

## 用户与角色

- 用户：**人类用户**（owner / owner）。不要用"小明"。
- 数字员工（Gitea 账号 = dsh preset id）：
  - 职能角色：`yl-planner`（规划）、`yl-dev`（开发）、`yl-tester`（测试）、`yl-ops`（运维·谛听）、`yl-releaser`（发布）
  - 业务角色：由项目自己定义（见项目层 AGENTS.md）
- 职能角色走 PR 到 main，**不直 push main**；合并权集中在 `yl-tester`（验收即放行）。

## Git 拓扑（ECS all-in-one）

- 单一托管 = **Gitea**（本地 `<gitea地址>`，组织 `<org>`，仓库 `<org>/<repo>`）。
- 代码工作区 = **`<工作区>`**（git 仓库根，职能角色 dsh 会话的 cwd）。
- 单一分支 = **main**；临时分支命名 `type/issueN-slug`（如 `fix/125-trigger-restore`），**issue 号必填**，合并回 main 后立即删除，禁止长期分支。

## Git 身份纪律（谁干的活用谁的账号 + commit SSH 签名）

- 数字员工提交时**动态指定身份**，禁止用 owner 身份；commit 一律走 SSH 签名包装器：
  ```
  <工作区>/scripts/yl-commit <账号> "<type>(<scope>): <描述>"
  ```
  例：`<工作区>/scripts/yl-commit yl-dev "feat(agent): #237 规范微调"`
- 包装器自动带上 `user.name`/`user.email` + SSH 签名（`gpg.format=ssh` + ed25519 私钥），Gitea 端提交显示 **verified**。
- email 格式：`<账号>@<email域>`（如 `yl-dev@<email域>`、`yl-tester@<email域>`）。
- 签名私钥：`<数据目录>/git-signing/<账号>/id_ed25519`；公钥已录入 Gitea 对应账号并标记 verified。

## 提交规范

- 格式：`type(scope): #issue 描述 (#PR)`，如 `feat(agent): #237 规范微调 (#240)`。
- 关联 issue 用 `Refs: gitea issue #xx`，**不用** `Closes/Fixes`（不自动关 issue）。

## Issue 与 PR 规范（AI 原生 SDLC artifact 链）

### issue = intent（需求意图）

intent 的来源有三种，谁提出谁建新 issue（载体 = 新 Gitea issue，不是聊天口头）：

1. **用户**（人类用户）：直接提需求、改需求、报问题。
2. **业务角色**（项目自定义）：工作流中发现的改进点或 bug。
3. **yl-ops（谛听）**：巡检发现的系统级问题（定位后开 issue，不自己改）。

issue 正文按模板写（originator 用自己话描述，Claude 帮写成规范格式）：

```
## Problem
<现状痛点>

## Proposed outcome
<想要的结果>

## Affected users and systems
<影响的人和系统>

## Constraints
<约束>

## Open questions
<待澄清>
```

### 计划评论 = yl-planner 的 spec（intent → 可执行计划的桥）

issue 建好后，`yl-planner` 分析代码库与契约，在 issue 下评论计划。设计不是 planner 单方垄断：`yl-dev`（可实现性）、`yl-tester`（可测试性/验收）都有权对设计提出修改、甚至推翻、要求重新设计，planner 被推翻则重新设计；三者讨论收敛后，dev 照定稿实现：

```
## 计划（yl-planner）
- 目标：<一句话，满足什么成功标准>
- 任务清单：<拆成 N 个可执行步骤>
  - [ ] 步骤 1
  - [ ] 步骤 2
- 影响范围：<涉及哪些模块/文件；是否动一级契约 contracts/ 或 core>
- 验收标准（DoD，定案必含量化，套用 `doc/definition-of-done.md` 四要素）：
  - 关键词/残留 0 命中清单：<`rg` 具体模式，预期 0 命中>
  - 逐项 PASS 记录：<每项验收点 + PASS/FAIL + 证据来源 + 证据产生者（CI 自动 / tester 手跑 / 用户真机）>
  - 端到端证据要求：<渠道/协议/dsh bridge/执行底座类变更强制「输入 X → 日志 Y → 输出 Z」真机链路>
  - 回滚/降级标准：<失败时的回滚方式 + 降级兜底行为>
- 风险与假设：<边界情况、依赖、待澄清项>
- 建议分支：<type/issueN-slug，如 fix/125-trigger-restore，issue 号必填>
```

### PR = sprint contract（本次 done 的定义）

PR 正文按模板写，yl-dev 写、yl-tester 照验并合并：

```
## 关联 issue
Refs: gitea issue #xx

## 本次 done 的定义
- [ ] 功能：<满足什么>
- [ ] 回归：<不破坏什么>
- [ ] 测试：<跑了哪些>
```

验收标准见 `TEST-ACCEPTANCE.md`（6 项硬阈值，任一不过 = 打回）；issue 的量化验收项见定案评论的 DoD（`doc/definition-of-done.md`），tester 逐项核对证据锚。

## 分支保护（main，Gitea 已配置）

- main 禁止直 push；合并必须走 PR。
- 合并白名单 = `yl-tester`（唯一能 merge，验收即放行）；`required_approvals = 0`（CI 门禁 + 验收 6 项硬阈值兜底）。

## 状态机防幻觉四原则（详见 doc/agentic-state-machine-safety.md）

状态写入（验收 PASS / 合并 / 关单 / 部署 / 冒烟）由 LLM 执行，存在幻觉风险。四条铁律：

1. **证据锚定**：每个状态转移附可机读证据（CI URL / 测试输出 / rg 命中数 / 日志摘录 / 真机截图）；**无证据锚的 PASS 一律视为 FAIL**。
2. **确定性门禁**：测试由 CI 系统自动跑（非 LLM 手跑），合并硬前提 = CI 绿（系统客观状态，LLM 不可伪造）。
3. **人类在环**：一级契约变更 owner approve、真机冒烟人类用户执行——LLM 不判断真实世界。
4. **fail-closed**：证据不足 / 不可复核 → 打回，宁可不通过、不可错通过。

证据分级：CI 绿 / git merge 状态 / 日志 ret 值 = 系统客观状态（可信）；「我测了」「0 命中」「真机验证过」= LLM 声称（必须机读证据锚）。

## 职责边界（详见 CONTRACTS.md）

- `yl-planner`（规划）：读 intent 拆计划、评论到 issue；**不写业务代码、不 merge、不关 issue、不部署**。
- `yl-dev`（开发）：写代码、提 PR；**不 merge main、不关 issue**。
- `yl-tester`（测试）：验收、**合并 main、关 issue（唯一合并权 + 唯一关闭权）**。
- `yl-ops`（运维·谛听）：健康巡检、备份、安全审计；只读生产、不写业务代码、不部署。
- `yl-releaser`（发布）：打 tag、release、部署、回滚；**不合并 PR、不写业务代码、不关 issue**。

## 会话收尾 = 外化（记忆不长在 session 里）

职能角色 session 是易失的：换会话即失忆，且长 session 拖累底座内存。**每次会话收尾必须把该会话的产物外化到 Git 事实源**，新会话靠 persona + instructions + Git 恢复上下文，不靠长 session 续命。

收尾触发（任一即算）：
1. 任务完成（issue 到「完成」/ PR 已合并 / 部署完成）
2. 会话被打断（服务重启、人工叫停）
3. 接近上下文上限（session 明显变长、响应变慢）

外化落点（按产物类型）：
- **决策 / 定案** → issue 评论（含证据锚）
- **踩坑 / 环境坑** → `PITFALLS.md`（项目层维护）
- **回归样本 / 复现步骤** → `REGRESSION.md`（项目层维护）
- **临时代码 / 诊断脚本** → 用后即删，不留工作区垃圾

铁律：
- 外化内容必须可机读复核（含证据锚），「我记下了」这类 LLM 声称不算外化。
- 未外化的会话产物视为未发生——新会话不得依赖旧 session 记忆。

## 凭证红线

- Gitea token、密钥等凭证**禁止**写入代码、commit message、issue/PR 正文、日志。
- 取 Gitea token 一律走 `get_token <role>`（受控读取预置 token），禁止 docker exec / gitea admin 现场自造。
- 凭证疑似泄漏 → 立即轮换并报告用户。

## 术语约定（统一口径）

- 系统代号：由项目自己定义（见项目层 AGENTS.md）；本项目基于 dsh 框架，目标企业级应用。
- 整套体系 = **Agentic CI/CD**（智能体驱动的持续集成/交付）；提「流程」就说 CI/CD 流水线。
- 分支/合并 = **Trunk-based 开发**（单一 main + 短命 `feat/*`/`fix/*` 分支 + squash 合并后删分支，一 PR 一 commit）。
- 代码归属 = **Git 单一真源**（生产 Gitea 是真源，配置只改 main，运行目录是镜像）。
- 数字员工分工 = **multi-agent 协作**（规划/开发/测试/发布/运维五个职能角色各司其职）。
