# CHANGELOG

本文件记录 APCC 机制（框架层）的版本演进。语义化版本（semver）。

## [v0.5.2] - 2026-09-05

### 补 preset 显示元数据模板

- `presets/yl-*.preset.yml`：补 6 个角色的 preset.yml 显示元数据模板（name/description），供 web GUI preset picker 显示；此前框架层只有 agent.cordis.yml 模板、缺 preset.yml，导致 picker 显示空名

## [v0.5.1] - 2026-09-05

### 修复 yl-apcc 指令加载失效

- `presets/yl-apcc.agent.cordis.yml`：instructionFileCandidates 由含路径的 `docs/APCC-GUIDE.md` 改为纯文件名 `['AGENTS.md','CONTRACTS.md']`（dsh-agent-instructions 只接受纯文件名，含路径会被过滤成空数组，导致 yl-apcc 不加载任何 workspace 指令）
- 根目录软链接 `AGENTS.md`/`CONTRACTS.md` → `instructions/`（dsh 只在项目根找候选文件名）

## [v0.5.0] - 2026-09-05

### install.sh 定位收窄：只管脚本（边界落实）

- 移除 persona / check.yml / 项目层文档的部署——归项目方自管，框架只给 presets/instructions/ci 模板
- 新增 `YL_APCC_ROOT` 写入 dsh 服务 drop-in（脚本引用核心，角色经 `$YL_APCC_ROOT/tools/...` 引用）
- 保留 labels 幂等创建 + 签名密钥/Gitea token 检查
- `projects/yingloong/OPS.md` 采纳 gh#3 收尾硬限定（PR 已 APPROVED 只收尾，禁止重走验证）

## [v0.4.1] - 2026-09-05

### 会话治理纪律（gh#53）

- `instructions/AGENTS.md`：「会话收尾 = 外化」纪律固化——收尾触发三信号（完成/被打断/接近上限）+ 外化落点（决策→issue、踩坑→PITFALLS.md、回归→REGRESSION.md）+ 铁律（外化必须可机读复核，未外化视为未发生）

## [v0.4.0] - 2026-09-05

### 盯执行收尾提效 + 框架/项目边界固化

- `tools/close-issue.sh`：幂等收尾三步（关 issue + 打完成 label + 留合并记录评论）脚本化，agent 一次调用完成（gh#3 方案②）
- `instructions/OPS.md`：「执行既定结论」类任务硬限定——PR 已 APPROVED 收尾禁止重走验证、引用既定证据锚（gh#3 方案①）
- `README.md`：中英双语补「边界（框架 vs 项目）」章——tools 官方维护，instructions/preset/check.yml 框架给模板、项目方自管自优
- `install.sh`：①② 精简合并，定位从「部署框架」改为「项目初始化/引导」

## [v0.3.0] - 2026-09-05

### 工具增强（GitHub issue 移植）

- `tools/yl-commit` 支持 `YL_SIGN_DIR` 环境变量自定义签名密钥目录（默认 `/var/lib/yingloong/git-signing` 不变），报错信息补 ssh-keygen 生成引导（gh#2）
- `tools/trigger_role.sh` 并行隔离：`--worktree`（锁按 worktree 粒度，多 issue 并行）+ `--dry-run`（演练只打印动作）+ `flock` 非阻塞防重入 + 单次超时 1800s + 失败重试 1 次（gh#1）

## [v0.2.1] - 2026-09-04

### 框架/项目分层收尾（instructions 拆分）

- `AGENTS.md` / `CONTRACTS.md` / `TEST-ACCEPTANCE.md` / `OPS.md` 四份退出框架层部署，改为**框架参考模板 + 项目层定义**：
  - 框架层四份中性化（去 Gitea 地址 / 品牌 / 业务角色 / 业务路径 / doc 断链），开源零泄漏
  - yingloong 真实版下沉 `projects/yingloong/`，install.sh ④ 项目层部署四份
  - 解决「公开 vs 项目级」「角色 5 个 vs 7 个名字不同」的分层问题
- `release-open.sh` 修复：`git init -b main`（否则 push main 失败）+ 临时目录 trap 清理

## [v0.2.0] - 2026-09-03

### 并行开发 + 开源就绪

**并行开发地基**
- 分支命名 `type/issueN-slug`（issue 号必填），issue↔分支↔worktree 机器可解析（#18）
- `trigger_role.sh` 去串行化（349→20 行）：headless profile 自带 persona，去掉切 default/flock/引用计数，直接 `--profile`（#20）
- scheduler 并行触发（`ThreadPoolExecutor` 上限 3）+ git worktree 隔离 + 合并后自动清理（#20/#22）
- dry-run 纯只读（`set_labels` 加保护）（#22）

**CI 门禁演进**
- 凭证扫描词表扩充 + 回归自检 + 布尔值排除（#1/#14）
- check.yml 补 push 触发 + aiohttp 测试依赖（#4/#26）

**开源就绪（框架可复用化）**
- 品牌名脱敏：persona 中性「本项目」+ 项目层 `project.sh` 声明（PROJECT_NAME 优先级：环境变量 > 项目层 > 框架默认）（#27）
- 功能性值参数化：email 域/仓库名保持默认值 + 环境变量覆盖（`EMAIL_DOMAIN`/`GITEA_REPO`），不硬替换占位符（#27）
- check.yml 拆层：框架通用门禁 + 项目层 `ci_project_tests.sh` 收纳业务测试（#27）
- 账号名脱敏（原真实姓名/账号 → 人类用户/owner）（#27）
- README 中英双语 + 开源定位（框架层开源 / 项目层私有）（#27）
- CONTRIBUTING.md 外部贡献者指南 + 参数化文档中性化（#30）

**方法论文档**
- `docs/EXPERIENCE-BOUNDARY.md`：经验三路边界（CI / pitfalls / 知识库）
- `docs/FRAMEWORK-PARAMETERIZATION.md`：参数化与开源准备设计

## [v0.1.1] - 2026-09-02

### 角色体系与凭证机制完善

**新增 yl-apcc 综合角色**
- APCC 机制维护者，一肩挑开发/测试/维护/安装（`presets/yl-apcc.agent.cordis.yml`）
- 签名密钥 + Gitea 账号（yl-apcc）已建，录公钥 verified

**token 注入机制（角色级，不绑 cwd）**
- `tools/get_token.sh`：受控读取角色 Gitea token，fail-closed（缺失即报错，禁止现场自造）
- `/var/lib/yingloong/gitea-tokens/<role>`：6 角色最小权限 token（平台侧注入，600 权限）
- scope 按角色职责：planner=read:repo+write:issue、dev/tester/apcc=write:repo+write:issue、ops=read、releaser=write:repo

**yl-apcc 仓库 merge 白名单最终形态**
- `['yl-apcc', 'yl-tester']`：综合角色（日常小改）+ 测试角色（正式验收合并）都能 merge 机制变更

**修复与沉淀**
- trigger_role.sh 反向同步回源（#125 并发安全 + 确定性恢复，避免 install 用旧版覆盖）
- pitfalls 补两条：Gitea 账号 must_change_password 需清标志、team-repo 权限 API 不生效靠分支保护兜底
- 方法论强化为五支柱（新增「事实源唯一/外化记忆」「框架/项目分层」）

## [v0.1.0] - 2026-09-02

### 初始机制包

从 yingloong 系统打磨中抽取出的首版可安装机制包。

**框架层（可开源）**
- `tools/`：trigger_role.sh（触发角色）、scheduler_status.py（进度面板）、auto_dev_scheduler.py（状态机调度）、yl-commit（SSH 签名提交）
- `instructions/`：AGENTS.md（git 身份/提交规范）、CONTRACTS.md（契约/职责边界）、TEST-ACCEPTANCE.md（验收硬阈值）、OPS.md（盯执行流程）
- `presets/`：yl-planner / yl-dev / yl-tester / yl-ops / yl-releaser 五个角色 persona 模板
- `gitea/labels.yaml`：11 个状态机 label 声明
- `install.sh`：幂等部署（框架打底 + 项目覆盖 + labels 配置）

**核心机制**
- 数字员工角色化（五角色对抗式分工，merge/关 issue/部署权唯一）
- 两阶段工作流（讨论人主导 + 定案后自动化 + 冒烟手动）
- 验收硬阈值 6 项（任一不过即打回）
- SSH 签名提交（杜绝未签名 git 作者身份冒充）
- 框架/项目分层（复用 + 经验保留 + 开源三合一）
- 经验分三路（CI / pitfalls / 知识库）

**踩坑沉淀（见 projects/<项目>/pitfalls.md）**
- Gitea 部分版本 PATCH /issues 无 labels 字段，须用 POST /labels
- 凭证 base64 会漏过关键词扫描
- headless settings.default 残留

