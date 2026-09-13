---
name: full-repo-audit
description: >
  全仓多轮审查与修复。当用户要求全面审查代码、全仓扫描、代码质量审计、安全审查、
  多轮深度审查时触发。维度充分摊开（14 个阶段、200+ 个细分维度），但每一轮只审一个维度：
  轮数随适用维度增长到几十、上百轮，每个 agent 只带一个维度的检查点，注意力集中。
  轮次严格串行，每轮完成 审查 → 修复 → 验证 → 记录 后才进入下一轮，进度可跨会话续跑。
  任何技术栈可用。
---

# 全仓审查：维度摊开，每轮摊薄

## 核心思路

覆盖面和审查深度并不矛盾。真正矛盾的是**每一轮的宽度**：

- **覆盖面** → 维度目录充分摊开：14 个阶段，200+ 个细分维度
- **深度** → 每一轮只审一个维度，agent 只拿到这一个维度的 3-6 个检查点
- **轮数不设上限** → 适用的维度有多少，就跑多少轮。几十轮、上百轮都是正常的

一个 agent 同时背十个领域，每个领域只能扫一眼；一个 agent 只盯一个维度，才会沿着调用链追到底。

## 铁律

1. **一轮 = 一个维度。** 不在一轮里合并多个维度，哪怕它们看起来相关。
2. **轮次严格串行。** 本轮的修复、验证、记录完成后，才开下一轮。
3. **agent 只带当前维度。** 同一轮派出多个 agent 时，只是按文件范围分片，查的仍是同一个维度。
4. **修复不积压。** 本轮发现的问题在本轮修，不推到后面。
5. **要快就少选，不要变宽。** 可以只跑某些阶段或维度；不可以为了减少轮数把维度合并。

## 结构

```
阶段（14 个，顺序固定）→ 维度（每阶段若干）→ 轮（一个维度就是一轮）
```

阶段顺序来自 14 轮、68+ agent 的真实审查战役：前一阶段的产出是后一阶段的输入
（S05 复查 S01-S04 的修复，S07 清理 S06 诊断的测试，S09 在 S10 删代码前全量验证，S12 固化前面的高频问题）。

| 阶段 | 主题 | 维度数 | 目录文件 |
|------|------|-------|---------|
| S01 | 功能与交互层 | 20（无 UI 替代 8） | `references/stages/S01-feature-ui.md` |
| S02 | 深度交叉审查 | 39 | `references/stages/S02-deep-cross.md` |
| S03 | 底层穿透 | 28 | `references/stages/S03-infrastructure.md` |
| S04 | 盲区扫荡 | 19 | `references/stages/S04-blind-spots.md` |
| S05 | QA 查漏补缺 | 14 | `references/stages/S05-qa-gaps.md` |
| S06 | 测试类型深挖 | 13 | `references/stages/S06-test-types.md` |
| S07 | 测试清理优化 | 8 | `references/stages/S07-test-cleanup.md` |
| S08 | 规范化统一 | 16 | `references/stages/S08-normalization.md` |
| S09 | 完整性验证 | 5 | `references/stages/S09-integrity.md` |
| S10 | 死代码 / 重复 / 解耦 | 12 | `references/stages/S10-dead-code-decoupling.md` |
| S11 | 剩余盲区 | 24 | `references/stages/S11-remaining-blind-spots.md` |
| S12 | 跨切面治理 | 11 | `references/stages/S12-cross-cutting.md` |
| S13 | 开发者体验 | 9 | `references/stages/S13-developer-experience.md` |
| S14 | 终验闭环 | 5 | `references/stages/S14-final-validation.md` |

## 激活方式

- 全量：`/full-repo-audit`
- 指定阶段：`/full-repo-audit S02 S11`
- 指定维度：`/full-repo-audit S02.12 S11.15`
- 触发词：`全面审查`、`全仓扫描`、`full review`、`audit everything`、`代码质量审计`、`多轮审查`

## Phase 0：准备（只做一次）

1. `git status`：有未提交变更先 stash 或提交；记录起始 commit。
2. 确定验证命令。顺序：CI 配置里实际跑的命令 → `package.json` scripts / `Makefile` / `justfile` → 生态默认值。找不到的门禁记为「无」，不编造。

   | 生态 | lint | typecheck | test | build |
   |------|------|-----------|------|-------|
   | Node/TS | `eslint` / `biome check` | `tsc --noEmit` | `vitest` / `jest` | 框架 build |
   | Python | `ruff` / `flake8` | `mypy` / `pyright` | `pytest` | `python -m build` |
   | Go | `golangci-lint` | `go vet ./...` | `go test ./...` | `go build ./...` |
   | Rust | `cargo clippy` | `cargo check` | `cargo test` | `cargo build` |
   | Java/Kotlin | `spotless` / `ktlint` | 编译 | `gradle test` / `mvn test` | `gradle build` / `mvn package` |

3. 在被审查仓库的根目录运行 `mkdir -p audit && bash <本 skill 目录>/scripts/repo-profile.sh . > audit/profile.md`（只读）：目录结构、入口、数据层、测试位置、热点文件。
4. 生成 `audit/progress.md`：逐个阶段文件、逐个维度列一行，用画像先判定适用性。明显不适用的（无 UI、无数据库、无容器……）直接标 `[-]` 并写原因。

```markdown
# 审查进度（起始 commit: abc1234）

## S02 深度交叉审查
- [x] S02.05 IDOR 与资源归属校验 — High 2 / Medium 1，已修 3
- [-] S02.23 键盘可达与焦点管理 — 无 UI
- [ ] S02.12 SSRF 与外部请求
```

`progress.md` 是全程唯一的进度表，也是跨会话续跑的依据。

## 单轮流程

```
① 取维度   progress.md 中下一个 [ ]；只读它在阶段文件里的那一个小节
② 定位     按「定位」在当前仓库找目标文件
           找不到任何目标 → 标 [-] 写原因，本轮结束
③ 分片     目标量超过一个 agent 能完整读完的范围（约 20 个文件或 3000 行）
           → 按目录 / 模块切片，每片一个 agent；否则只派 1 个
④ 派发     每片一个只读 agent，prompt 里只有：本维度检查点 + 本片文件 + 相关高频问题
⑤ 收集     汇总去重；同一问题 ≥3 处 → 追加一个横向 agent 扫全仓
⑥ 修复     本轮发现在本轮修完，Critical / High 先修；修复 agent 按文件分工
⑦ 验证     受影响范围的测试 + 改动文件的 lint / typecheck；本轮没有改动则跳过
⑧ 记录     progress.md 该行改为 [x]，写一行结果
```

**⑧ 完成之前，不开下一轮。**

## 阶段收尾

每个阶段最后一个维度完成后：

1. **全量门禁**：lint → typecheck → test（有 build 则 build），全部通过。
2. **阶段摘要** `audit/Sxx-summary.md`（≤30 行）：
   - 各维度发现数与修复数
   - 未修项及原因
   - 高频问题类型（带 1-2 个 `文件:行号` 例子）→ 写进后续阶段相关维度 agent 的 prompt

## 续跑

几十上百轮必然跨越上下文压缩或多个会话。继续时只做两件事：
读 `audit/progress.md` 和最近一份阶段摘要，然后从第一个 `[ ]` 开始。已经 `[x]` 的维度不重跑。

## 审查 agent 提示词模板

````markdown
# S{xx}.{nn} {维度名}（分片 {k}/{n}）

你只审查「{维度名}」这一个维度。其他维度会在其他轮次单独审查，不要分心。

## 目标文件
{本片文件清单}

## 检查点
{只复制阶段文件中本维度小节的检查点}

## 已知高频问题（与本维度相关）
{来自阶段摘要；没有则删掉本节}

## 方法
1. 逐个完整阅读目标文件，不抽样，不只看片段。
2. 每个检查点都落到具体代码上判断。
3. 发现疑点后，继续读调用方和被调用方，确认真的会出错、影响多大。
4. 宁可少报，每条都要确认过。无法确认的标「待确认」。

## 输出格式
## [Critical|High|Medium|Low] 问题标题
**文件:** `path/to/file:line`
**问题描述:** 具体问题和影响
**复现路径:** 怎样触发
**修复建议:** 具体改法

没有发现就写「本片未发现问题」，并列出检查过的文件。
与本维度无关的问题，在末尾「顺带发现」各写一句，不展开。

## 约束
- 不修改任何文件
- 每条发现必须有 文件:行号
````

「顺带发现」不在本轮处理：

- 对应维度还没跑 → 记入 `progress.md` 那一行的备注，轮到它时写进 agent prompt
- 对应维度已经 `[x]` → 记入当前阶段的待修清单，在阶段收尾的全量门禁之前修复

## 横向 agent

同一问题在 ≥3 处出现时派出。prompt 包含：典型示例（文件 + 行号）、搜索模式（regex 或关键词）、
预期数量、修复模板。要求输出**全量命中清单**，每处标注「是问题 / 不是问题及原因」。

## 修复 agent

- 只修分配给你的发现，只改分配给你的文件
- 不顺手重构，不改无关代码，不引入新依赖
- 修复建议不可行时停下说明，不自行换方案
- 改完运行受影响部分的测试

## 严重性

| 级别 | 含义 |
|------|------|
| Critical | 数据泄露、越权、数据丢失或损坏、服务不可用 |
| High | 常见条件下功能出错、数据不一致、关键路径无保护 |
| Medium | 特定条件下出错、明显的维护代价、体验缺陷 |
| Low | 一致性、可读性 |

## 不自动修复

- **真实凭据泄露**：只报告位置和轮换步骤，报告里不写凭据值；轮换由人完成
- **会删除或改写生产数据的迁移**：给出方案，不执行
- **依赖大版本升级**：列出清单和风险，不自动升级

任何门禁都不允许靠跳过测试、放宽配置或 `--no-verify` 变绿。

## 全部完成后

1. 合并 14 份阶段摘要为 `audit/REPORT.md`：各阶段统计、未修清单及原因、新增门禁、需要人工处理的事项。
2. 按仓库协作规范 commit、push、创建 PR。
