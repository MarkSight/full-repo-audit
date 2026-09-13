# 🔍 Full-Repo Audit

**A stack-agnostic, multi-wave repository audit orchestrator — recon first, severity-ordered waves, findings that drive the next wave, and new CI gates as the final output.**

**通用全仓审查编排器 —— 先侦察画像，按严重度排波，发现驱动下一波，最终产出新的质量门禁。**

---

## What it is / 这是什么

A skill that orchestrates read-only review agents across an entire repository, in **14 waves**
ordered by *how much damage a finding can do* — not by which layer the code sits in.

Every wave's scope, target paths and verification commands come from a **repository profile**
generated in Phase 0. The skill itself contains **no project-specific paths, frameworks or
commands**, so the same skill works on a TypeScript monorepo, a Go service, a Python library,
or a Terraform repo.

一个编排只读审查 agent 的 skill，按**严重度**而非代码分层组织 **14 个波次**。
所有路径与命令都来自 Phase 0 生成的**仓库画像**，skill 本体不含任何项目专属内容 ——
同一个 skill 适用于 TS monorepo、Go 服务、Python 库或 Terraform 仓库。

---

## Wave order / 波次顺序

```
Phase 0  Recon ──→ profile + applicability matrix + verification commands
   ↓
W1  Secrets & supply chain        最便宜、最致命，且结论会改变后续范围
W2  Security & trust boundaries   每个外部入口逐条过
W3  Data & state correctness      事务/迁移/并发/缓存/时间精度
W4  Runtime resilience & o11y     超时/重试/泄漏/关停/日志指标
W5  Interfaces & contracts        行为正确了，才谈契约是否如实
W6  Performance & resources       正确性之后才优化
W7  Experience layer (conditional) 表层最后改，避免被底层修复推翻
W8  Delivery & ops                构建/CI 安全/容器/IaC/回滚
W9  Tests                         修复前先把验证能力修好
W10 Code health & docs
W11 Cross-cutting governance & gates
   ↓
W12 Horizontal expansion  一处发现 → 全仓同类 → 能写成规则的写成规则
W13 Tiered fixes          文件所有权分片并行，Critical 先行
W14 Final gate & report   门禁全绿 → 报告 → 确认 → commit/push/PR
```

Each wave dispatches 3-8 parallel **read-only** agents (count set by repo size tier).
Review and fix are strictly separate roles.

### Why this order / 排序理由

Leaked credentials need action *today*, so they are found first. Security findings usually
expose data-integrity problems, which in turn reveal resilience gaps. Contracts are judged
only after actual behaviour is known. UI work goes late because it is the most likely to be
invalidated by deeper fixes — the common "UI first" ordering causes rework. Tests come before
the fix wave so the fixes have trustworthy gates.

机密泄露需要当天处置，所以最先查；安全发现常直接暴露数据完整性问题，后者又牵出韧性缺口；
契约必须在知道真实行为之后才能判断；UI 最容易被底层修复推翻，所以后置（常见的 "UI first"
排法会造成返工）；测试放在修复波之前，修复才有可信门禁。

---

## Install / 安装

```bash
git clone https://github.com/MarkSight/full-repo-audit.git
```

Then make the skill discoverable by your agent CLI:

| CLI | Location / 位置 |
|-----|----------------|
| Claude Code | `.claude/skills/full-repo-audit/` (project) or `~/.claude/skills/full-repo-audit/` (global) |
| ZCode / agent CLIs using `.agents` | `.agents/skills/full-repo-audit/` |

```bash
# example: install globally for Claude Code
cp -r full-repo-audit/.agents/skills/full-repo-audit ~/.claude/skills/
```

Requirements: `git`, `bash`, plus whatever the audited repo needs to run its own
lint/typecheck/test/build commands. The skill installs nothing and the recon script is read-only.

---

## Usage / 使用

```
/full-repo-audit
/full-repo-audit --scope=services/api --depth=deep
/full-repo-audit --waves=W1,W2,W9 --fix=none
```

Natural language / 自然语言：`全面审查这个仓库`、`上线前体检`、`安全审查`、
`技术债盘点`、`run a complete code audit`、`pre-release audit`

| Parameter | Default | Effect |
|-----------|---------|--------|
| `--scope=<path…>` | whole repo | limit to a subtree |
| `--waves=<ids>` | `all` | run only selected waves |
| `--depth=quick\|standard\|deep` | `standard` | agents per wave + severity floor |
| `--fix=none\|critical\|all` | `critical` | what gets fixed vs only reported |
| `--autonomous` | off | skip the confirmation before commit/push/PR |

### Human-in-the-loop boundary / 人工把关边界

Review and local fixes run unattended. These never happen automatically:

- **`commit` / `push` / PR** — confirmed with you first (unless `--autonomous`)
- **Leaked credentials** — reported with rotation steps; the skill does not rotate or rewrite history for you
- **Destructive migrations, production config, permission policy changes** — proposed, not applied
- **Dependency major upgrades** — listed with risk notes, not auto-bumped

---

## Dimension coverage / 维度覆盖

66 dimensions across 11 audit waves. Each has a detailed checklist in `references/`;
Phase 0 marks each one **applicable / not applicable (with reason) / sampled**, so
"zero blind spots" is a claim you can actually verify.

| Wave | Dimensions |
|------|-----------|
| W1 | secrets & credential exposure · dependency vulnerabilities · supply-chain integrity · license compliance |
| W2 | authn & sessions · authz & multi-tenant isolation · injection & input validation · crypto & key handling · web/platform hardening · abuse & quotas · privacy/PII & retention · webhooks & integrations |
| W3 | transactions & atomicity · migrations & compatibility · schema/indexes/queries · concurrency & races · state machines · cache coherence · backup/restore & data-loss paths · time/precision/units/encoding |
| W4 | error handling · failure modes & recovery · resource lifecycle & shutdown · observability · config & feature flags |
| W5 | type safety · API contracts & versioning · module boundaries · single-source-of-truth drift · plugin/skill/tool contracts |
| W6 | algorithmic hot paths · I/O & network efficiency · client performance budgets · build & startup · benchmarks & regression guards |
| W7 | flows & IA · accessibility (WCAG AA) · i18n/l10n · responsive & cross-platform · empty/loading/error/offline states · CLI & library DX · copy consistency |
| W8 | build reproducibility · CI/CD correctness & security · containers & IaC · deploy/rollback · release & versioning discipline |
| W9 | risk-based coverage gaps · assertion strength · isolation/fixtures/determinism · suite structure & cost · missing test types · test-debt cleanup |
| W10 | dead code · duplication · coupling & decomposition · naming & style · comments & TODO debt · repo hygiene · docs completeness · docs accuracy · DevEx & local setup |
| W11 | error-code taxonomy · logging uniformity · cross-cutting pattern consistency · gate hardening & ownership |

---

## What makes it different / 与普通审查的差别

### Profile-driven, not path-hardcoded / 画像驱动
Dimensions describe *roles* (entry layer, trust boundary, persistence layer…). Phase 0 maps
roles to real paths, so no `components/canvas/`-style hardcoding.

### Findings drive the next wave / 发现驱动
After each wave the orchestrator merges findings, extracts patterns, and **rewrites later
waves' prompts**. Skip that step and 14 waves degrade into 14 unrelated scans.

### Horizontal expansion / 横向展开
Same root cause in ≥3 places becomes one pattern finding, swept repo-wide with a
machine-searchable signature — and turned into a lint rule where possible.

### Gate hardening as a deliverable / 门禁固化是交付物
W11 must produce at least one new automated gate. It also hunts for **gates that look alive
but aren't** — `continue-on-error`, excluded directories, thresholds below the current value.

### Verifiable coverage / 可验证覆盖
Every agent reports what it checked **and found clean**, and every skipped dimension records
why. Severity is graded by consequence, with explicit rules against style-preference findings.

---

## Repository layout / 仓库结构

```
.agents/skills/full-repo-audit/
├── SKILL.md                          # orchestration: waves, batching, fix strategy, gates
├── scripts/
│   └── repo-profile.sh               # read-only recon (language, commands, hotspots, risk greps)
└── references/
    ├── recon-playbook.md             # Phase 0 manual + per-ecosystem command map + profile template
    ├── dim-A-supply-chain.md         # W1
    ├── dim-B-security.md             # W2
    ├── dim-C-data-state.md           # W3
    ├── dim-D-runtime.md              # W4
    ├── dim-E-contracts.md            # W5
    ├── dim-F-performance.md          # W6
    ├── dim-G-experience.md           # W7
    ├── dim-H-delivery.md             # W8
    ├── dim-I-tests.md                # W9
    ├── dim-J-health-docs.md          # W10 (J code health + K docs/DevEx)
    ├── dim-L-governance.md           # W11
    ├── severity-and-reporting.md     # severity rubric, finding format, ledger, report template
    └── agent-playbook.md             # agent prompts, parallelism rules, expansion, fix waves
```

Audit output lands in the audited repo under `audit/`:
`00-profile.md`, `00-plan.md`, `findings.md`, `expansion-queue.md`, `deferred.md`,
`W<n>/<agent>.md`, `REPORT.md`.

---

## Track record / 实战记录

The method was extracted from a real audit campaign: **14 rounds, 68+ agents, ~900 files,
200+ findings fixed end-to-end** — SSRF bypass, 10+ transaction-safety bugs, 11 missing error
boundaries, 13 fragile text-scanner tests removed, dependency vulnerabilities patched.

v2 generalized it: the project-specific paths and the pnpm/Next.js/Drizzle assumptions were
replaced by the Phase 0 profile, the wave order was re-derived from severity, 66 checklisted
dimensions replaced the original ~50 ad-hoc review angles, and the human-in-the-loop boundary
was made explicit. See [CHANGELOG.md](CHANGELOG.md) for the rationale.

---

## License / 许可证

MIT — use freely, modify, share. No attribution required.
