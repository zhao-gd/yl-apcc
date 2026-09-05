# 框架参数化与开源准备 —— #27 落地设计草案

> 状态：**草案**（待用户拍板，未落地）
> 关联：`gitea issue #27`「开源贡献准备 + 跨项目应用准备」的落地设计
>
> 一句话：把框架层里的「品牌名」和「功能性值」分开处理——品牌名脱敏成中性词、功能性值保持默认值 + 环境变量覆盖，让 yl-apcc 既能开源、又能平移到其他项目，且**默认部署到某系统零变化**。

---

## 0. 核心矛盾

yl-apcc 框架层目前绑定「某系统」的命名，无法开源、无法平移。矛盾在于：**框架里的值分两类，性质完全不同，却混在一起处理。**

| 值类型 | 例子 | 性质 | 出错的后果 |
|---|---|---|---|
| **软值（品牌/称谓）** | 某系统、某用户 | 不影响功能 | 换掉无影响 |
| **功能性值（身份/地址）** | `@yingloong.local`、`yingloong/yingloong`、`/opt/yingloong` | SSH 签名、API 访问依赖它 | 换错 → 签名 `sig=U` 被拒、API 404 |

**之前的教训**（2026-09-03 部署事故）：有人把功能性值也硬替换成了占位符（`<org>/<repo>`、`<项目域名>`），导致调度器 `REPO="<org>/<repo>"` 会 API 404、AGENTS.md email 口径错乱。这就是 #27 Constraints 里「功能性值只能参数化，不能硬替换占位符」警告的具体复现。

**本草案的第一原则：软值脱敏、功能性值参数化，二者用不同的机制，绝不混用。**

---

## 1. 软值脱敏：品牌名 →「本项目」+ PROJECT_NAME 覆盖

### 现状

品牌名「某系统」出现在 5 个 persona 的开头各 1 处：

```
你是某系统的规划工程师（yl-planner）。职责：...
你是某系统的开发工程师（yl-dev）。职责：...
你是某系统的测试工程师（yl-tester）...
你是某系统的运维工程师（yl-ops）...
你是某系统的发布工程师（yl-releaser）...
```

### 方案

1. 框架层 persona 改为中性词：`你是本项目的规划工程师（yl-planner）。职责：...`
2. `install.sh` 新增 `PROJECT_NAME`（默认 `本项目`），部署时 `sed "s|本项目|$PROJECT_NAME|g"`。
3. 该项目部署时传 `PROJECT_NAME=某系统`，persona 恢复为「某系统的规划工程师」。

### 理由

- 品牌名是软值，替换成什么都不影响功能，可以安全用占位符。
- 框架层（开源）不暴露「某系统」私有品牌；该项目部署通过环境变量回填，现状零变化。
- `本项目` 在 persona 里唯一出现（仅品牌名位置），sed 替换无误伤。

---

## 2. 功能性值参数化：默认值 + 环境变量覆盖

### 2.1 email 域 `@yingloong.local`

**三处必须联动**（否则 SSH 签名验证失败）：

| 位置 | 当前 | 参数化后 |
|---|---|---|
| `tools/yl-commit` | `user.email="$ACCOUNT@yingloong.local"`（2 处） | `user.email="$ACCOUNT@$EMAIL_DOMAIN"` |
| `ci/allowed_signers` | `yl-dev@yingloong.local ssh-ed25519 ...` | principal 同步替换 |
| `instructions/AGENTS.md` | email 格式 `<账号>@yingloong.local` | 口径同步 |

机制：`install.sh` 新增 `EMAIL_DOMAIN`（默认 `yingloong.local`），部署时 `sed "s|@yingloong.local|@$EMAIL_DOMAIN|g"` 覆盖以上三处。

**默认不传 = 该项目现状不变**（yl-commit 提交 email 仍是 `@yingloong.local`，allowed_signers 匹配，签名验证正常）。

⚠️ 铁律：yl-commit 提交的 email、allowed_signers 的 principal、AGENTS.md 口径三者**必须一致**，缺一即提交审计 `sig=U` 拒收。

### 2.2 仓库名 `yingloong/yingloong`

| 位置 | 当前 | 参数化后 |
|---|---|---|
| `tools/auto_dev_scheduler.py` | `REPO = "yingloong/yingloong"` | 默认值保留 + 部署时覆盖 |
| `tools/scheduler_status.py` | `API = ".../yingloong/yingloong"` | 同上 |
| `install.sh` | 已有 `GITEA_REPO` 环境变量 | 复用 |

机制：`install.sh` 部署 tools/ 时，`sed "s|yingloong/yingloong|$GITEA_REPO|g"`（`GITEA_REPO` 默认从 `$WORK` 的 git remote 推断，已有逻辑）。

### 2.3 路径 `/opt/yingloong`

**已参数化**（install.sh 现有 `sed "s|/opt/yingloong|$WORK|g"`），无需改动。

### 2.4 功能性值参数化的统一原则

**默认值 = 该项目真实值（yingloong.local / yingloong/yingloong / /opt/yingloong），不是占位符。** 部署到该项目不传任何参数 = 现状不变；部署到其他项目才传环境变量覆盖。这与 #27 约束「保持默认值 + 环境变量覆盖」完全一致。

---

## 3. 业务测试路径下沉：check.yml 拆「通用门禁 + 项目层脚本」

### 现状

`ci/check.yml` 里混着两类内容：

- **通用门禁**（任何项目都要）：分支 discipline、凭证扫描、提交审计、Python 语法、依赖安装、证据汇总。
- **yingloong 业务特定**（只有该项目有）：`scripts/lint_layers.py`、`tests/`、`qa/dsh-bridge/`、`qa/dsh-plugins/`、覆盖率 `--include=yingloong/channel/weixin.py` 等。

### 方案

按 EXPERIENCE-BOUNDARY.md 的框架/项目分层切一刀：

1. **框架 check.yml 只留通用门禁**，业务测试段（全量单测 / qa 回归 / 分层 lint / 覆盖率）整体移除。
2. 框架 check.yml 末尾加一个「项目测试」step：

```yaml
      - name: 项目测试（项目层 ci_project_tests.sh，无则跳过）
        shell: bash
        run: |
          if [ -f scripts/ci_project_tests.sh ]; then
            bash scripts/ci_project_tests.sh
            echo "::notice::项目测试通过"
          else
            echo "::notice::无项目层测试脚本，跳过"
          fi
```

3. 项目层 `projects/yingloong/ci_project_tests.sh` 收纳全部该项目业务测试（lint_layers、tests/、qa/dsh-bridge、qa/dsh-plugins、覆盖率），install.sh 项目覆盖步骤部署到 `$WORK/scripts/`。

### 理由

- 框架 check.yml 跨项目干净，开源不泄漏该项目业务测试路径。
- 该项目业务测试留在项目层私有，随项目走。
- 新项目只需提供自己的 `ci_project_tests.sh`，框架 check.yml 无需改。

---

## 4. install.sh 参数化设计（统一 sed 映射）

### 新增环境变量

| 变量 | 默认值 | 用途 |
|---|---|---|
| `PROJECT_NAME` | `本项目` | 品牌名回填（软值） |
| `EMAIL_DOMAIN` | `yingloong.local` | email 域覆盖（功能性值） |
| `GITEA_REPO` | （已有，从 git remote 推断） | 仓库名覆盖（功能性值） |

### 部署 sed 映射（按序执行）

| 替换 | 目标文件 |
|---|---|
| `s\|/opt/yingloong\|$WORK\|g` | 全部（已有） |
| `s\|本项目\|$PROJECT_NAME\|g` | presets/（品牌名） |
| `s\|@yingloong.local\|@$EMAIL_DOMAIN\|g` | tools/yl-commit、ci/allowed_signers、instructions/ |
| `s\|yingloong/yingloong\|$GITEA_REPO\|g` | tools/（调度器） |

### 该项目部署（不传参数）效果

全部默认值 = 该项目真实值，部署后与现状**逐字节一致**，SSH 签名、API 访问、persona 全部不变。

---

## 5. 完整改动清单

### 框架层（yl-apcc 仓库，开源）

| 文件 | 改动 |
|---|---|
| `presets/yl-{planner,dev,tester,ops,releaser}.agent.cordis.yml` | 「某系统」→「本项目」（各 1 处） |
| `tools/yl-commit` | `user.email` 用 `@yingloong.local`（默认值，install 时替换） |
| `tools/auto_dev_scheduler.py`、`scheduler_status.py` | REPO/API 保持 `yingloong/yingloong` 默认值 |
| `ci/check.yml` | 移除业务测试段 + 加「项目测试」step |
| `ci/allowed_signers` | principal 保持 `@yingloong.local`（默认值） |
| `instructions/AGENTS.md` | 用户行「某用户」→ 视品牌脱敏决定（见 §6 风险） |

### 项目层（projects/yingloong/，私有，不进公开仓库）

| 文件 | 改动 |
|---|---|
| `projects/yingloong/ci_project_tests.sh` | 收纳 lint_layers、tests/、qa/、覆盖率 |

### install.sh

| 改动 |
|---|
| 新增 `PROJECT_NAME`、`EMAIL_DOMAIN` 环境变量 |
| 部署时按 §4 的 sed 映射做四类替换 |
| 项目覆盖步骤增加部署 `ci_project_tests.sh` |

---

## 6. 风险与开放问题

1. **AGENTS.md「某用户」用户行**：这是品牌名（人）还是功能性值？建议按品牌名处理——框架层改「人类用户（owner）」，但**不得**把功能性值（仓库、email）也占位符化（上次事故根因）。此项单独确认。
2. **allowed_signers 的替换**：allowed_signers 是公钥文件，principal 替换后公钥不变；但若 EMAIL_DOMAIN 改变，git 提交 email 与 allowed_signers principal 都要同步，否则签名验证 `sig=U`。验证用例必须覆盖「改 EMAIL_DOMAIN 后签名仍 G」。
3. **`本项目` sed 误伤**：确认 persona 里「本项目」仅品牌名位置出现（当前是），避免未来新增文案时踩。
4. **`ci_project_tests.sh` 的覆盖率路径**：`--include=yingloong/channel/weixin.py` 等业务路径随项目层脚本走，不留在框架 check.yml。

---

## 7. 验证方案

### 验证 A：该项目默认部署零变化（关键）

```bash
# 不传任何新参数
./install.sh
# 断言：
#   - persona 含「某系统的」          （PROJECT_NAME 默认本项目？不对——见下）
```

> 注：§1 方案里默认 `PROJECT_NAME=本项目`，该项目部署需显式传 `PROJECT_NAME=某系统`。若希望「不传参数 = 该项目现状」，则默认值应改为 `某系统`，开源时显式传 `本项目`。**这是需要用户拍板的关键点**（见 §7 开放问题）。

### 验证 B：跨项目参数化部署

```bash
WORK=/srv/foo PROJECT=foo GITEA_REPO=foo/foo \
PROJECT_NAME=福系统 EMAIL_DOMAIN=foo.local ./install.sh
# 断言：persona 含「福系统」、yl-commit email 用 @foo.local、调度器 REPO=foo/foo
```

### 验证 C：签名链路（EMAIL_DOMAIN 改变后仍 G）

```bash
EMAIL_DOMAIN=foo.local ./install.sh
cd $WORK && git commit（用 yl-commit）
git verify-commit HEAD   # 必须 sig=G，不能 U
```

---

## 8. 参考

- `gitea issue #27`（开源贡献 + 跨项目准备）
- `docs/EXPERIENCE-BOUNDARY.md`（框架/项目分层支柱）
- 本草案 §0 的事故复盘（功能性值硬替换占位符的教训）

---

*本文档是 #27 的落地设计草案，未落地。拍板后按「开 issue → 改 → 测试 → 部署」推进。*
