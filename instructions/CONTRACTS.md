# 契约层（CONTRACTS）

> 职能数字员工之间的"硬法律"。软约束靠 persona / AGENTS.md，硬约束靠本文档 + Gitea 账号权限 / 分支保护。
> 原则：**DSH 只负责"它是谁、看见什么"；Gitea 负责"它真不能做什么"。二者绝不混。**

## 1. 契约分级

### 一级契约（动它 = 地震，改前必审 + 升版本）
| 契约 | 典型对象 | 为什么是一级 |
|---|---|---|
| 事件契约 | 平台事件定义（events 协议） | 核心发、外围收，全平台命脉 |
| 引擎契约 | 黑盒引擎协议 | 引擎 JSON-RPC 等协议 |
| 数据契约 | 数据库 schema | 审批/审计/会话的存储骨架 |
| 通道基座 | 通道抽象基类 | 各渠道共同接口 |
| 平台公共 API | 核心对外接口 | 外围模块全部依赖 |

> 具体路径由项目自己定义（见项目层 CONTRACTS.md）。

### 二级契约（配置真源，改 main 不改运行时）
项目运行配置（角色/身份配置、编排文件、环境变量）等。

### 非契约（自由区，各自深耕）
各通道 / 应用 / 插件的内部实现。

## 2. 契约变更协议（6 条铁律）

1. **加性优先**：事件契约只能新增事件类型，禁止删除/重命名已有字段。破坏性变更 = 升主版本 + 迁移计划 + owner 审批。
2. **版本号绑定**：一级契约每次变更必须带版本号，README / CHANGELOG 同步。
3. **单一真源**：配置只改 main，运行目录是镜像，禁止本地手改。
4. **破坏性变更三件套**：迁移脚本 + 回滚方案 + 全量回归，缺一不合并。
5. **跨模块 = 总工收口**：一个 issue 同时动 core + channel（或任意两个一级模块），由 `yl-dev` 牵头，模块专家只做各自片段。
6. **契约 owner 一票否决**：owner 对一级契约变更有一票否决权（PR 必须该 owner approve）。

## 3. 数字员工与 Gitea 账号

| 数字员工 | preset | Gitea 账号 | 权限 |
|---|---|---|---|
| 规划 | yl-planner | yl-planner | read + comment issue；不 push 不 merge |
| 开发 | yl-dev | yl-dev | push 分支 + 开 PR；不能 merge main |
| 测试 | yl-tester | yl-tester | write；验收 + 合并 main + 唯一关 issue |
| 发布 | yl-releaser | yl-releaser | write；发布/部署（打 tag、release、部署、回滚），不合并 PR |
| 运维·谛听 | yl-ops | yl-ops | admin；只读生产 + 巡检备份 |

## 4. 硬门禁（Gitea）

- main 禁止直 push，合并必须 PR。
- 合并白名单 = `yl-tester`（唯一 merge 角色）；`required_approvals = 0`（CI 门禁 + 验收 6 项硬阈值兜底，不再人工审批）。
- 线性历史（squash 合并，一 PR 一 commit；Gitea `default_merge_style=squash`）。

## 5. 职责切线（变更 / 发布 / 稳态）

> 三个职能各守一段：**测试 = 变更守护**（验收即放行进 main）；**发布 = 进生产执行**（从 main 打 tag 部署回滚）；**谛听 = 稳态守护**（保持健康）。

| 动作 | yl-tester·测试 | yl-releaser·发布 | yl-ops·运维 |
|---|---|---|---|
| 验收新功能 / 变更 | ✅ | ❌ | ❌ |
| 合并 PR 到 main | ✅（唯一合并权，验收即放行） | ❌ | ❌ |
| 关闭 issue | ✅（唯一关闭权） | ❌ | ❌（只开不关） |
| 打 tag / release | ❌ | ✅ | ❌ |
| 部署 / 回滚 | ❌ | ✅ 走 RELEASE.md | ❌ 只报告，不动手 |
| 健康巡检 / 告警 | ❌ | ❌ | ✅ 日常 |
| 备份 / 安全扫描 / 凭证审计 | ❌ | ❌ | ✅ |

### 硬规则
1. **合并下沉**：验收通过 = 放行进 main，`yl-tester` 是唯一能 merge 的角色；CI 门禁 + 验收 6 项硬阈值（TEST-ACCEPTANCE.md）是合并的硬前提，不再设人工审批。
2. **发布解耦**：合并 ≠ 部署。`yl-releaser` 只做"从 main 打 tag + 部署 + 回滚"，不写业务代码、不 merge、不关 issue。
3. 谛听发现需要"变更"（重启/部署/改配置）→ **开 issue 或报告用户，绝不自己执行**；变更走 yl-releaser + RELEASE.md。
4. 系统级 bug：谛听负责**定位 + 开 issue**，修复走 issue → 开发；测试负责**验收 + 合并 + 关 issue**。
5. 只有 `yl-tester` 能 merge main、能关 issue。
