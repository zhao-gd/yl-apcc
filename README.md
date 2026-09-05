# yl-apcc — Agentic PR/CI/CD Framework

[English](#english) · [简体中文](#chinese)

<a name="chinese"></a>
## 简体中文

让「规划 / 开发 / 测试 / 运维 / 发布」五个 AI 数字员工，围绕 Git 单一事实源，把一条 issue 从「定案」自动流转到「合并」，并靠「验收硬阈值 + SSH 签名 + 分支保护」兜底质量。

### 定位

- **框架层（开源）**：`tools/` `instructions/` `presets/` `gitea/` `docs/` `install.sh` —— 跨项目通用，可复用于任意 Git 平台与项目。
- **项目层（私有）**：`projects/<项目>/` —— 品牌名、业务测试、踩坑记录等私有资产，**开源发布时排除**。

### 边界（框架 vs 项目）

框架给「模板」，项目方拿走后自管；可执行脚本由框架层官方维护：

| 资产 | 归属 | 维护方式 |
|---|---|---|
| 可执行脚本（`tools/`） | **APCC 官方** | 跨项目通用，框架层直接改、发版 |
| instructions 文档（AGENTS.md / OPS.md / TEST-ACCEPTANCE.md 等） | **项目方** | APCC 给中性化模板，项目方 copy 成自己真实版（`projects/<项目>/`）后自管 |
| dsh preset（角色 persona） | **项目方** | APCC 给标准模板，项目方基于模板自定义角色 |
| CI 门禁（check.yml） | **项目方**（落地后） | 框架给底线模板，项目方自管自优，APCC 升级不覆盖 |

### 快速开始

```bash
./install.sh                                          # 默认部署
WORK=/path/repo PROJECT=foo ./install.sh              # 跨项目部署
```

### 参数化（跨项目复用）

框架层中性化 + 功能性值保持默认值，部署时按「环境变量 > 项目层声明 > 框架默认」回填：

| 变量 | 默认 | 说明 |
|---|---|---|
| `PROJECT_NAME` | 本项目 | 品牌名（软值，项目层 `project.sh` 声明覆盖） |
| `EMAIL_DOMAIN` | yingloong.local | email 域（功能性值，SSH 签名依赖） |
| `WORK` / `GITEA_REPO` | /opt/yingloong / 自动推断 | 路径 / 仓库名 |

详见 [docs/FRAMEWORK-PARAMETERIZATION.md](docs/FRAMEWORK-PARAMETERIZATION.md)。

### 文档

- [docs/APCC-GUIDE.md](docs/APCC-GUIDE.md) —— 完整方法论
- [docs/EXPERIENCE-BOUNDARY.md](docs/EXPERIENCE-BOUNDARY.md) —— 经验三路边界
- [docs/FRAMEWORK-PARAMETERIZATION.md](docs/FRAMEWORK-PARAMETERIZATION.md) —— 参数化与开源准备

### 目录结构

```
tools/          # 通用工具（框架层，跨项目）
instructions/   # 通用约定（框架层）
presets/        # 角色 persona 模板（框架层）
gitea/          # Git 平台配置声明（labels 等）
docs/           # 方法论文档
projects/       # 项目层（私有，开源发布时排除）
install.sh      # 幂等部署
```

### License

Apache 2.0（见 LICENSE）。

<a name="english"></a>
## English

Five AI digital employees — planner / developer / tester / ops / releaser — work around Git as the single source of truth, moving an issue from "settled" to "merged", with quality backed by hard acceptance thresholds, SSH-signed commits, and branch protection.

### Positioning

- **Framework layer (open source)**: `tools/` `instructions/` `presets/` `gitea/` `docs/` `install.sh` — project-agnostic and reusable.
- **Project layer (private)**: `projects/<project>/` — brand names, project-specific tests, and pitfalls are private assets, **excluded from open-source releases**.

### Boundary (framework vs project)

The framework ships **templates**; project owners take them and self-manage. Executable scripts are officially maintained by the framework layer:

| Asset | Owner | Maintenance |
|---|---|---|
| Executable scripts (`tools/`) | **APCC (official)** | project-agnostic; edited and released at the framework layer |
| Instruction docs (AGENTS.md / OPS.md / TEST-ACCEPTANCE.md / …) | **Project owner** | APCC ships neutralized templates; project copies them into its own real versions (`projects/<project>/`) and self-manages |
| dsh presets (role personas) | **Project owner** | APCC ships standard templates; project customizes roles on top of them |
| CI gate (check.yml) | **Project owner** (after install) | framework ships a baseline template; project self-manages and tunes; APCC upgrades do not overwrite |

### Quick start

```bash
./install.sh                                          # default deployment
WORK=/path/repo PROJECT=foo ./install.sh              # cross-project deployment
```

### Parameterization

The framework layer is neutralized; functional values keep defaults and are backfilled at deploy time by priority: env var > project-layer declaration > framework default.

| Variable | Default | Meaning |
|---|---|---|
| `PROJECT_NAME` | 本项目 | brand name (soft value, overridden by project-layer `project.sh`) |
| `EMAIL_DOMAIN` | yingloong.local | email domain (functional value; SSH signature depends on it) |
| `WORK` / `GITEA_REPO` | /opt/yingloong / inferred | path / repository |

See [docs/FRAMEWORK-PARAMETERIZATION.md](docs/FRAMEWORK-PARAMETERIZATION.md).

### Docs

- [docs/APCC-GUIDE.md](docs/APCC-GUIDE.md) — full methodology
- [docs/EXPERIENCE-BOUNDARY.md](docs/EXPERIENCE-BOUNDARY.md) — CI / pitfalls / knowledge-base boundaries
- [docs/FRAMEWORK-PARAMETERIZATION.md](docs/FRAMEWORK-PARAMETERIZATION.md) — parameterization & open-source readiness

### License

Apache 2.0 (see LICENSE).

---

> Built on [DeepSeek Harness](https://github.com/deepseek-ai). dsh provides "how an agent runs"; APCC provides "how multiple agents collaborate to push code to merge".
