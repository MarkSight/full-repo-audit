# 🔍 Full-Repo Audit

**Automated multi-round, multi-dimension code review — from surface UI to deep infrastructure, zero blind spots.**

**全自动多轮多维度代码审查 — 从表层UI到底层基础设施，零盲区覆盖。**

---

## Overview / 概述

Full-Repo Audit is a ZCode skill that orchestrates **autonomous code review agents** across your entire repository. It runs **14 phases** in sequence, each dispatching **6-8 parallel agents** to cover a specific dimension of code quality. Findings from earlier phases trigger **horizontal expansion agents** that chase the same pattern across every file. The entire pipeline — review → fix → verify → push — runs without human intervention.

全仓审查是一个 ZCode skill，自动编排审查agent覆盖整个仓库。按**14个阶段**顺序执行，每阶段派遣**6-8个并行agent**覆盖一个特定的代码质量维度。前一阶段的发现会自动触发**横向展开agent**，将同一个问题模式扫遍全仓库。整个流程——审查→修复→验证→推送——全自动运行。

---

## How It Works / 工作方式

```
Batch 6-8 agents → Collect findings → Fix critical issues → Next batch → Horizontal expansion
     ↑                                                                              │
     └──────────────────────── Repeat 14 phases ────────────────────────────────────┘
                                                                                   │
                                                                            Verify + Push
```

### Agent Pipeline / Agent流水线

| Phase | Focus / 审查方向 | Agents |
|-------|-----------------|--------|
| 1-4 | UI/UX, Security, Transactions, a11y, Error Handling, Performance, Types, Build, Migration, State Machines, Skills | 32 |
| 5-6 | QA Gap Analysis, Test Quality Deep-Dive | 11-14 |
| 7-8 | Test Cleanup, Normalization (paths, naming, imports, style, comments, config, interfaces) | 11 |
| 9-10 | Integrity Verification, Dead Code, Duplication, Decoupling | 7 |
| 11-12 | Dependency Security, Static Assets, Graceful Shutdown, Config Audit, Cross-tab Races, Cross-cutting Concerns | 8 |
| 13-14 | Developer Experience, Final Validation (lint → typecheck → test → build → commit → push) | 5 |

**Total: ~70+ agents across 14 phases, full repository coverage.**

---

## Key Features / 核心特性

### 🧠 Autonomous Orchestration / 自动编排
No prompts needed mid-pipeline. Each phase reads previous findings and adapts.

### 🔬 Horizontal Expansion / 横向展开
When an agent finds a pattern (e.g., "missing onError handlers"), dedicated expansion agents sweep the entire codebase for the same pattern.

### ⚡ Tiered Fix Strategy / 分级修复
- **Critical / High**: Fixed immediately within the same phase
- **Medium / Low**: Accumulated and fixed at phase boundaries

### 🛡️ Full Validation Gate / 完整验证门禁
Every fix batch runs through `lint → typecheck → test` before moving on. Final gate runs the full `validate` chain.

### 🌐 Tech Stack Agnostic / 技术栈无关
Audits TypeScript, Python, Go, Rust, or any language — agents adapt based on file extensions and project patterns.

---

## Installation / 安装

```bash
# Clone to any project that uses ZCode
git clone https://github.com/MarkSight/full-repo-audit.git

# The skill is auto-discovered at:
# .agents/skills/full-repo-audit/SKILL.md
```

### Requirements / 依赖

- [ZCode](https://github.com/stackblitz/ai) CLI
- `git`, `node` (for running project-level validation commands)

---

## Usage / 使用

### Trigger / 触发

```
/full-repo-audit
```

Or via natural language / 自然语言触发:

```
全面审查这个仓库
full review please
run a complete code audit
多轮深度审查
```

### What Happens / 执行流程

1. **Phase 0**: Checks repo state, records starting commit
2. **Phases 1-4**: Surface → deep layers (UI → security → infrastructure)
3. **Phases 5-6**: QA gap analysis, test quality deep-dive
4. **Phases 7-8**: Test cleanup, normalization sweep
5. **Phases 9-10**: Integrity check, dead code, decoupling
6. **Phases 11-12**: Remaining blind spots, cross-cutting governance
7. **Phases 13-14**: DevEx improvements, final validation gate
8. **Auto-fix + push**: All fixes committed and pushed to origin

---

## Architecture / 架构

```
full-repo-audit/
└── .agents/skills/
    └── full-repo-audit/
        └── SKILL.md          # Main orchestration logic (352 lines)
```

The skill is self-contained in a single `SKILL.md` file. Each phase defines:
- Agent count and batch size
- Review scope and target files
- Output format requirements
- Horizontal expansion triggers
- Fix priority assignment

---

## Design Principles / 设计原则

| Principle / 原则 | Description / 说明 |
|------------------|-------------------|
| **Zero blind spots** / 零盲区 | 14 phases ensure every code dimension is covered |
| **Progressive depth** / 递进深度 | Surface first, infrastructure later — each phase builds on previous findings |
| **Pattern expansion** / 模式展开 | One finding → sweep entire codebase for the same pattern |
| **Hands-free** / 零人工 | From trigger to push, no human decisions needed mid-pipeline |
| **Self-validating** / 自验证 | Every fix batch is linted, typechecked, and tested before proceeding |

---

## Real-World Track Record / 实战记录

This skill was extracted and generalized from a real-world audit campaign that ran **14 rounds with 68+ agents** across a ~900-file monorepo, finding **200+ issues** and fixing them end-to-end:

- 🔒 SSRF bypass fixed
- 🗄️ 10+ transaction-safety bugs fixed
- 🎨 11 error boundary pages created
- 🧪 13 fragile text-scanner tests removed
- 📏 Full normalization sweep (paths, names, imports, types, comments, configs)
- 📦 Dependency security vulnerabilities patched

---

## License / 许可证

MIT — use freely, modify, share. No attribution required.

---

*Built from real battle scars. Not theoretical — every phase was refined through actual production use.*

*来自实战的积累。不是理论 —— 每个阶段都在真实的生产代码中打磨过。*
