# 经验三路边界：CI / pitfalls / 知识库

> 状态：**草案**（待用户拍板，未落地 persona/验收规则）
> 关联：本文档是 `APCC-GUIDE.md` §6「经验管理：分三路」的展开，回答「一条经验该进哪一路、边界在哪」。
>
> 一句话：项目经验按「**能否机器确定性判定 × 是否必须强制**」分流到 CI（门禁）、pitfalls（踩坑）、知识库（方法论）三路，并沿「文档 → 门禁 → 框架」持续下沉。

---

## 0. 为什么需要这份边界

现状诊断（2026-09-02）：三路已经**脱节**，后果是 yl-ops 一次报了 6 条 issue（`#1`~`#6`），根因高度一致——**软约束冒充了硬约束**：

1. **知识库写了「必须做」，CI 没拦**：
   - `AGENTS.md` 要求 SSH 签名 + 身份白名单 → check.yml 无签名校验、Gitea 未开 `require_signed_commits`（= `#6`）
   - 要求线性历史 → Gitea 实配 merge commit（= `#5`）
   - `CONTRACTS.md` 凭证红线 → check.yml 词表漏 `token`/`app_token`（= `#1`）
2. **pitfalls 记了坑，CI 没实现**：`pitfalls.md` 早写了「base64 / `user:pass` 漏检」，但 check.yml 压根没扫——坑记了等于白记。
3. **回归层缺失**：`projects/yingloong/README.md` 声明了三路 `pitfalls.md / regression.md / accept.yaml`，后两个文件实际不存在；regression.md 正是「pitfall → CI 回归用例」的桥，断了。

三路脱节的本质：**经验没有「外化」成正确强度的载体**——该进 CI 的躺在文档里，该留文档的没人维护，该做回归的没有样本。

---

## 1. 核心判据：两个问题定一路

每条经验/规则，依次问两个问题：

> **Q1：机器能确定性判定吗？**（无歧义、无主观判断、低误报、本地可复现）
> **Q2：违反必须阻断吗？**（fail-closed）

| Q1 机器可判定 | Q2 必须强制 | 去处 |
|---|---|---|
| ✅ | ✅ | **CI 硬门禁**（fail-closed，违反阻断） |
| ✅ | ❌（启发式 / 可能误报 / 仅提醒） | **CI 软告警**（warn 不阻断） |
| ❌ | — | **pitfalls**（暂不能机器判定，靠人读） |
| 是原则/动机，不是规则 | — | **知识库**（上下文与依据） |

判据一句话版：**「确定性可判定」是进不进 CI 的门槛，「必须强制」是硬门禁还是软告警的分界；两者都不满足才落文档。**

---

## 2. 三路定义与边界

### 2.1 CI 硬门禁（gate，fail-closed）

**契约**（社区共识，见 erigontech CI-GUIDELINES）：硬门禁里的检查只有一条标准——**「失败 = 代码错了，通过 = 代码对了」**。因此只放**确定性、零误报、可本地复现**的检查；任何 flaky、启发式、可能误报的检查不配进硬门禁。

**例子**：Python 语法、单测全绿、凭证扫描（确定词表）、SSH 签名校验、覆盖率底线、分支保护、目标分支校验。

### 2.2 CI 软告警（warn，非阻断）

**边界**：能机器判定，但**可能误报**或只是**反馈用途**（不阻断合并）。

**例子**：现有 check.yml 的「commit 关联 issue」用 `continue-on-error`——归类正确，因为关联词是启发式匹配，误报代价高。

### 2.3 pitfalls（踩坑，候选池）

**边界**：**真实踩过、但暂不能/不值得机器判定**的经验——需要上下文判断，或还没抽象成规则。靠人（或 agent）读、判断。

**例子**：`PATCH /issues` 无 labels 字段（API 行为坑，CI 判不了）、`must_change_password` 需清理。

**关键规则**：每条 pitfall 必须标注状态——`待进CI` 或 `已进CI规则X`。它是 CI 规则的**候选池**，不是终点。

### 2.4 知识库（方法论，上下文与依据）

**边界**：只讲「**为什么**」「**怎么判断**」——原则、动机、角色分工、流程约定。**不是机器可执行的规则**。

**例子**：APCC-GUIDE 的角色制衡原理、五段流、验收口径、事实源唯一。

**关键规则**：知识库里凡出现「必须做」的句子，都要**指向对应的 CI 门禁**，不留孤立的软要求。写「必须 SSH 签名」就必须有「CI 校验 SSH 签名」的门禁兜底。

---

## 3. 演进路径：文档不是终点，门禁才是

社区共识（shift-left + policy-as-code）：**好经验要持续从「文档」下沉到「代码/门禁」**，机器执行永远比人记可靠。

```
知识库写「必须做」 ──能机器判定?──▶ 升级成 CI 硬门禁（否则只是软约束）
pitfalls 踩坑     ──能确定性拦截?──▶ 升级成 CI 规则 / 回归用例
CI 规则           ──通用化了?─────▶ 收进框架共享层（install.sh 部署）
```

社区依据：

- **Pony 的 [pony-lint: Codifying the Style Guide](https://www.ponylang.io/blog/2026/05/pony-lint-codifying-the-style-guide/)**：风格指南（文档）最终被固化成 lint（机器门禁），从「靠人 review」变成「靠机器拦」。
- **CNCF 的 [Policy as Code](https://www.cncf.io/blog/2025/07/08/why-policy-as-code-is-a-game-changer-for-platform-engineers/)**：能机器执行的策略写成代码，不留文档等人记。
- **[Policy-as-Code for CI/CD: Security Gates That Work](https://safeguard.sh/resources/blog/policy-as-code-for-cicd-enforcing-security-gates-without-breaking-builds)**：门禁高误报 = 团队习惯性忽略 = 红线报废，所以启发式规则降级为告警。

---

## 4. 闭环互指：三路不脱节的关键

三路不是三个孤岛，要**互相指向、互相溯源**：

| 载体 | 必须做 | 防止 |
|---|---|---|
| CI 规则 | 注释里引用来源 issue / pitfall 条目 | 规则无出处，改不动 |
| pitfall 条目 | 标注「待进CI / 已进CI规则X」 | 坑记了没人升级 |
| 知识库「必须做」句 | 指向对应 CI 门禁 | 软约束冒充硬约束 |
| regression 样本 | 每个已知 bug 一条可拦的回归用例 | bug 修了再复发无人拦 |

---

## 5. 归属第二刀：框架通用 vs 项目特定

在「三路」之外还有第二个维度——这条经验是**所有项目通用**还是**本项特有**：

| 经验范围 | 归属 | 部署方式 |
|---|---|---|
| 通用（签名 / 凭证 / 身份白名单 / 分支保护） | **yl-apcc 框架源** | `install.sh` 部署到各项目 |
| 项目特定（业务 lint、业务测试、业务回归样本） | **projects/`<项目>`/ 项目层** | 项目层覆盖框架默认 |

这回答了「CI 该不该进 yl-apcc」：**通用门禁模板进框架源，项目特定规则留项目层**——否则 check.yml 散落业务现场、无法版本化演进（正是当前漂移的根因）。

---

## 6. 决策树：一条经验该进哪路

```
新经验/新规则
  │
  ├─ 是「原则/动机/分工」？ ──▶ 知识库（并保证其中的「必须做」句有门禁兜底）
  │
  ├─ 机器能确定性判定？
  │    ├─ 否 ──▶ pitfalls（标注 待进CI）
  │    └─ 是
  │         ├─ 违反必须阻断？
  │         │    ├─ 是（且低误报、本地可复现）──▶ CI 硬门禁
  │         │    └─ 否（启发式/仅提醒）────────▶ CI 软告警
  │
  └─ 是「已知 bug」的复发拦截？ ──▶ regression.md → CI 回归用例
```

---

## 7. 现状映射示例（yl-ops 的 6 条 issue 归类）

用本框架把 `#1`~`#6` 归位，作为判据的实测：

| Issue | 性质 | 按判据该进 | 当前错在哪 |
|---|---|---|---|
| #1 凭证扫描漏 `token`/`app_token` | 确定性可判定 + 必须强制 | **CI 硬门禁**（扩词表 + 回归样本） | 词表不全，软约束 |
| #6 SSH 签名无硬门禁 | 确定性可判定 + 必须强制 | **CI 硬门禁**（签名校验）+ Gitea 分支保护 | 全凭自觉 |
| #4 合并后 main 无 CI | 确定性（push 触发） | **CI 硬门禁**（补 push 触发） | 触发盲区 |
| #5 线性历史 vs merge commit | 平台配置 + 文档口径 | **Gitea 配置**（合并策略）+ 知识库口径对齐 | 契约/配置冲突 |
| #3 无持久 token 注入 | 平台能力，非仓库内 | **dsh 平台层**（凭证注入） | 超出 yl-apcc 仓库 |
| #2 docker exec 越权 | 平台能力，非仓库内 | **dsh 平台层**（沙箱 deny） | 超出 yl-apcc 仓库 |

> `#2`/`#3` 落 dsh 平台层，不在 yl-apcc 仓库能力内，需平台侧配合——这正是「归属第二刀」的体现。

---

## 8. 参考

- erigontech [CI-GUIDELINES.md](https://raw.githubusercontent.com/erigontech/erigon/refs/heads/main/CI-GUIDELINES.md) —— CI 门禁决策树 +「失败=错、通过=对」契约
- Pony [pony-lint: Codifying the Style Guide](https://www.ponylang.io/blog/2026/05/pony-lint-codifying-the-style-guide/) —— 文档 → 机器门禁的固化
- CNCF [Why Policy as Code is a Game Changer](https://www.cncf.io/blog/2025/07/08/why-policy-as-code-is-a-game-changer-for-platform-engineers/) —— 策略即代码
- Safeguard [Policy-as-Code for CI/CD: Security Gates That Work](https://safeguard.sh/resources/blog/policy-as-code-for-cicd-enforcing-security-gates-without-breaking-builds) —— 低误报才配做门禁

---

*本文档是方法论草案，未落地到 persona / 验收规则；拍板后按「先开 issue → 改 → 测试 → 版本」流程推进。*
