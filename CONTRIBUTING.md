# 贡献指南（CONTRIBUTING）

> 面向**外部贡献者（真人）**。数字员工（yl-planner / yl-dev / yl-tester / yl-ops / yl-releaser）的内部协作规则见 `AGENTS.md`，不在本文范围。

## 定位：外部贡献者 ≠ 数字员工

yl-apcc 由「数字员工」自动维护，但它们和你是两种不同角色：

| | 数字员工 | 外部贡献者（你） |
|---|---|---|
| 工作方式 | 按 AGENTS.md 自动协作 | 直接提 issue / PR |
| 提交身份 | 强制 SSH 签名 + 职能账号 | 无需 SSH 签名（合并时由数字员工 squash 重签） |
| 合并权 | yl-tester 独有 | 无，由 yl-tester 验收后合并 |

一句话：**你提 issue 和 PR，数字员工验收、合并、发布。**

## 提 issue

任何 bug、改进想法、文档问题，都欢迎提 issue。请按模板写：

```markdown
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

## 提 PR

1. Fork 本仓库，从 `main` 拉分支，命名 `type/issueN-slug`（如 `fix/12-typo`，issue 号必填，无对应 issue 则先提 issue）。
2. 改动后向 `main` 发起 PR，正文写清「关联 issue / 本次 done 的定义」。
3. 等待数字员工（yl-tester）按 6 项硬阈值验收。

## 验收标准（6 项硬阈值）

外部 PR 与内部 PR 同一标准，见 `TEST-ACCEPTANCE.md`，任一不过即打回：

1. 功能满足（对照 PR「done 定义」逐条）
2. CI 门禁绿（确定性检查，非人肉声称）
3. 回归不破
4. 测试覆盖（全绿无跳过）
5. 凭证安全（无泄漏）
6. 提交规范（合并后 squash commit 由数字员工签名，符合身份纪律）

## 提交规范

- commit 格式：`type(scope): #issue 描述`，关联 issue 用 `Refs: gitea issue #xx`（不自动关 issue）。
- **外部贡献者的原始 commit 无需 SSH 签名**——合并时数字员工会 squash 成一个签名 commit，最终进 main 的只有数字员工的签名身份。

## 行为准则

- 尊重他人，就事论事。
- 不提交凭证、密钥、个人隐私数据。
- 不确定的问题先开 issue 讨论，再动代码。

## 支持范围

- 当前支持 **Gitea**（本地/自托管）。`gitea/labels.yaml` 与 `ci/check.yml` 为 Gitea 语法。
- 跨平台（GitHub / GitLab）适配在 roadmap 中。

## License

Apache 2.0，见 `LICENSE`。
