---
name: full-repo-audit
description: > 
  全仓全面审查与修复。当用户要求全面审查代码、全仓扫描、代码质量审计、安全审查、
  多轮深度审查时触发。自动分批次安排6-8个并行agent，每批覆盖一个合理的审查维度，
  批次间根据前一批发现横向展开追加审查。全过程无需人工干预，最终汇总所有发现
  实施修复并推送。覆盖: 功能/UI、安全、事务、a11y、错误处理、性能、TypeScript类型、
  构建部署、数据迁移、状态机、技能系统、文档、测试、配置、依赖、死代码、解耦、
  跨切面治理、开发者体验。全仓库零盲区覆盖。
---

# 全仓全面审查与自动修复

本skill实现完整的多轮、多维度、全仓库代码审查流程。每次调用自动分批次安排agent，
每批6-8个并行审查agent，前一批完成后根据发现横向展开下一批，最终汇总修复并推送。

## 激活方式

- 手动：`/full-repo-audit`
- 触发词：`全面审查`、`全仓扫描`、`full review`、`audit everything`、`代码质量审计`、`多轮审查`

## 工作流总览

```
Phase 0: 环境准备 ──→ 确定仓库根目录、git状态、当前分支
Phase 1-4: 分批审查 ──→ 每批6-8个agent，覆盖不同维度
Phase 5: 横向展开 ──→ 根据发现追加针对性agent
Phase 6: 修复实施 ──→ 并行修复agent处理所有发现
Phase 7: 验证闭环 ──→ lint → typecheck → test → build → commit → push
```

## Phase 0: 环境准备

在开始任何审查前执行：

1. 确认仓库根目录和git状态
2. 检查是否有未提交的变更（需要stash）
3. 确认pnpm/lint/typecheck/test/build命令可用
4. 记录审查开始时间戳和当前commit

```
cd <repo-root>
git status
pnpm --version
```

## Phase 1: 功能与UI层审查 (6-8 agents)

第一批覆盖最表面的代码质量维度，使用general-purpose agent并行执行。

### Agent分配模板

```yaml
batch_size: 6-8
agent_type: general-purpose
parallel: true
```

### R1 审查维度

| # | 方向 | 审查重点 | 目标文件 |
|---|------|---------|---------|
| 1 | UI组件易用性 | 配置控件是否喧宾夺主、操作流是否顺畅 | `components/`, `app/p/` |
| 2 | 无限画布操作流 | 拖拽/批量/节点操作/状态持久化 | `components/canvas/` |
| 3 | 设置面板布局 | Modal vs inline、配置密度 | `components/settings/` |
| 4 | 生产/剧本页面 | tab顺序、骨架屏匹配、空状态 | `app/p/[projectId]/production/`, `script/` |
| 5 | Agent聊天面板 | 流式渲染、错误状态、滚动行为 | `components/agent/` |
| 6 | 资产/媒体组件 | 预览/候选/加载/错误状态 | `components/Asset*`, `Media*` |
| 7 | 核心包(shared/agent) | 设计一致性、schema漂移 | `packages/shared/`, `packages/agent/` |
| 8 | 客户端库/i18n | api函数、locale、主题 | `lib/client/`, `lib/i18n/` |

### 每批次输出要求

每个agent输出 markdown 格式审查报告：

```markdown
## [严重性] 问题标题

**文件:** `path/to/file.ts:line`

**问题描述:**
具体描述问题和影响

**复现路径:**
如何到达这个漏洞路径或UX问题

**修复建议:**
具体代码修改建议
```

批次完成后收集所有报告，提取共性问题进入Phase 5横向展开。

## Phase 2: 深度交叉审查 (6-8 agents)

第二批覆盖跨功能的质量维度。**重要**：读取Phase 1生成的所有审查报告，
将Phase 1中发现的高频问题类型加入到Phase 2的agent提示词中作为重点。

### R2 审查维度

| # | 方向 | 审查重点 | 技术栈 |
|---|------|---------|--------|
| 1 | 安全加固 | IDOR、SSRF、CSRF、XSS、路径遍历、认证会话、密钥管理、敏感数据暴露 | `lib/server/`, `middleware.ts`, `api/auth/` |
| 2 | 事务与数据完整性 | delete+insert原子性、事务边界、TOCTOU、竞态 | `lib/server/`, `packages/db/` |
| 3 | 可访问性与i18n | WCAG 2.1 AA、键盘导航、aria-label、焦点管理、硬编码文本、locale检测 | `components/`, `i18n/` |
| 4 | 错误处理与恢复 | ErrorBoundary、未catch Promise、静默失败、乐观回退、超时 | `components/`, `lib/server/` |
| 5 | 性能与资源 | 内存泄漏、缓存淘汰、串行请求、索引缺失、DOM体积、session管理 | 全仓库 |

### 横向展开规则

对于Phase 1-2中发现的问题类型，如果某个模式在多个位置出现（例如"多处缺失onError"），
发起专门的横向agent来扫描全仓库的该模式。横向agent的prompt应包含：
- Phase 1/2发现的典型示例（文件+行号）
- 搜索模式（regex或关键词）
- 预期数量
- 修复模板

## Phase 3: 底层穿透审查 (6-8 agents)

第三批深入代码基础设施层。

### R3 审查维度

| # | 方向 | 审查重点 |
|---|------|---------|
| 1 | TypeScript类型安全 | unsafe `as`断言、Zod→DB schema漂移、跨包类型重复 |
| 2 | 构建与部署管道 | turbo.json、Biome配置、tsconfig、Next.js配置、CI/CD |
| 3 | 数据迁移与向后兼容 | Drizzle迁移、旧数据兼容、WASM SQLite |
| 4 | 状态机与并发模型 | agent回合状态机、任务生命周期、认证状态、审批状态 |
| 5 | 技能系统与工具契约 | SKILL.md完整性、工具注册表、路由矩阵、品牌隔离 |

## Phase 4: 盲区扫荡 (6-8 agents)

第四批覆盖尚未触及的表层领域。

### R4 审查维度

| # | 方向 | 审查重点 |
|---|------|---------|
| 1 | 根配置与dotfiles | biome、turbo、tsconfig、editorconfig、gitattributes、gitignore、env |
| 2 | 文档完备性 | designs、fixlog、backlogs、reviews、README结构 |
| 3 | 全量测试健康 | 测试模式(行为vs文本扫描)、覆盖缺口、fixture健康 |
| 4 | 公共目录与残留 | public/、outputs/、tmp/、build产物、大小审计 |
| 5 | CHANGELOG与交叉引用 | 版本号一致性、fixlog→CHANGELOG映射、链接健康 |
| 6 | 静态资源 | fonts/、favicon、图片大小、未使用资源、robots.txt |

## Phase 5: QA查漏补缺 (6-8 agents)

第五批从QA视角检查遗漏，验证前面修复没有引入回归。

### R5 审查维度

| # | 方向 | 审查重点 |
|---|------|---------|
| 1 | 回归风险与契约断裂 | 事务内异步IO、ssrf连接泄漏、error.tsx连锁影响、审批修复连锁 |
| 2 | 用户旅程端到端 | 创建项目→小说→剧本、画布拖拽→生成、Agent对话→审批、生产→候选→选中 |
| 3 | 边界条件与错误注入 | 空值/超长/并发请求、SQL注入/SSRF/RateLimit测试覆盖 |
| 4 | 命名/模式/风格一致性 | API响应格式、文件名、Hook命名、导入风格、暗色主题 |
| 5 | 数据流与依赖完整性 | 未使用导入、循环依赖、workspace协议、TODO/FIXME、props传递 |
| 6 | 日志/监控/可观测性 | catch块日志、审计事件、用户反馈、启动日志、健康检查 |

## Phase 6: 测试类型深挖 (5-6 agents)

第六批专注测试体系本身。

### R6 审查维度

| # | 方向 | 审查重点 |
|---|------|---------|
| 1 | E2E/集成测试健康度 | 集成测试质量、关键API路径覆盖、setup/teardown、mock策略 |
| 2 | 测试质量与断言深度 | 弱断言(toBeDefined)、没有断言的测试、硬编码脆弱性、跳过测试 |
| 3 | Mock/桩/夹具完整性 | mock泄漏风险、fixture→schema同步、全局状态污染、时间模拟 |
| 4 | 安全/边界压力测试 | 认证/授权测试、SSRF测试、限流测试、错误注入测试 |
| 5 | 缺失测试类型盘点 | 视觉回归、API契约、性能基准、模糊测试、a11y测试、组件交互测试 |

## Phase 7: 测试清理优化 (4 agents)

第七批清理测试代码中的技术债务。

### R7 清理方向

| # | 方向 | 操作 |
|---|------|------|
| 1 | 文本扫描测试迁移 | 识别readFileSync+toContain模式，删除纯CSS类名断言，合并tripwire |
| 2 | 过期回归测试识别 | 检查硬编码计数(skillCount/迁移数)、已删除API引用、跳过/待办测试 |
| 3 | 冗余重复测试合并 | 相同describe/it描述、跨app重复、过小/过大测试文件、重复fixture |
| 4 | 脆弱断言强化 | toBeDefined→toEqual、toBeTruthy→具体匹配、toContain→精确匹配、浮点数toBeCloseTo |

## Phase 8: 规范化统一 (7 agents)

第八批统一代码风格和规范。

### R8 规范维度

| # | 方向 | 检查项 |
|---|------|--------|
| 1 | 路径结构 | 目录命名kebab-case、扩展名.ts vs .tsx、API路由路径风格、导入@别名 |
| 2 | 命名 | 函数verb+noun、组件名匹配文件名、类型PascalCase、枚举、常量、布尔前缀、事件handle前缀 |
| 3 | 导入/导出 | 排序、type import统一、named export优先、桶文件策略、循环依赖 |
| 4 | 代码风格 | Result vs throw、Error类code字段、API响应格式统一、useCallback/useMemo、?? vs || |
| 5 | 注释 | JSDoc覆盖率、biome-ignore注释规范、文件头注释 |
| 6 | 测试/配置 | 测试描述格式、测试文件命名位置、数据工厂共享、tsconfig/package.json/env变量 |
| 7 | 跨包接口 | db访问签名一致、CRUD参数顺序、共享vs重复类型定义、废弃API、内部函数导出 |

## Phase 9: 完整性验证 (4 agents)

第九批验证所有修复的编译和运行时正确性。

### R9 验证项

| # | 验证内容 | 命令/检查 |
|---|---------|----------|
| 1 | 全量编译 | `pnpm typecheck` |
| 2 | 全量lint | `pnpm lint` → 应零错误 |
| 3 | 全量测试 | `pnpm test` → 应全部通过 |
| 4 | 跨轮次冲突检测 | 验证ownership注册、契约测试、hash更新 |

## Phase 10: 死代码/重复/解耦 (3 agents)

第十批扫描未被使用的代码和技术债务。

### R10 方向

| # | 方向 | 方法 |
|---|------|------|
| 1 | 死代码 | 未使用的export、废弃兼容代码、仅测试引用的代码、注释掉的代码、一次性脚本 |
| 2 | 重复代码 | 相同函数实现(跨文件)、数据库查询模式、条件逻辑、测试beforeEach/createDb、CSS类名 |
| 3 | 解耦需求 | 包间耦合(shared含业务逻辑)、大文件拆分(>500行)、职责混合、工具函数分散、硬编码依赖 |

## Phase 11: 剩余盲区 (5 agents)

第十一批覆盖之前未触及的全面领域。

### R11 盲区

| # | 方向 | 覆盖内容 |
|---|------|---------|
| 1 | 依赖安全审计 | pnpm-lock已知漏洞扫描、版本过时检查、peer dependencies、许可证合规、引擎要求 |
| 2 | public/静态资源 | 字体引用、favicon压缩、缺失标准文件(robots.txt/manifest)、图片优化 |
| 3 | 优雅关闭与进程管理 | 信号处理(SIGTERM/SIGINT)、SQLite checkpoint、进行中操作处理、临时文件清理 |
| 4 | Next.js配置深度 | CSP/Headers、rewrites、images、webpack、compiler、实验性功能 |
| 5 | 跨标签页/多窗口竞态 | BroadcastChannel、SSE共享、SQLite写入冲突、Canvas拖拽冲突、会话状态、任务去重 |

## Phase 12: 跨切面治理 (3 agents)

第十二批检查纵向一致性。

### R12 方向

| # | 方向 | 内容 |
|---|------|------|
| 1 | 错误码分类学 | 所有Error类的code字段格式、message-as-code模式清理、缺失code字段补充 |
| 2 | 日志格式统一 | console调用[topic]前缀覆盖率、无前缀日志清理 |
| 3 | 时间格式/分页 | API响应日期格式统一、now()共享函数使用、分页模式评估 |

## Phase 13: 开发者体验 (3 agents)

第十三批检查开发者工具链。

### R13 方向

| # | 方向 | 内容 |
|---|------|------|
| 1 | CLI工具完整性 | subcommand清单、--help完整性、错误处理 |
| 2 | 开发模式/调试 | NODE_ENV条件、调试环境变量、HMR配置 |
| 3 | 贡献文档 | CONTRIBUTING.md、测试配置(vitest watch/coverage)、postinstall脚本 |

## Phase 14: 终验闭环 (2 agents)

第十四批最终验证。

### R14 验证

| # | 验证内容 |
|---|---------|
| 1 | `pnpm validate` 全链回归 |
| 2 | 修复可审计性（CHANGELOG/fixlog记录验证) |
| 3 | 所有已实施修复的回归确认 |
| 4 | 文档目录完整性验证 |

## 修复实施策略

每一批审查完成后，根据发现的问题严重性决定修复时机：

### 即时修复（Critical/High）
审查批次内发现的CRITICAL和HIGH问题，立即创建修复agent处理：
```yaml
fix_agent_count: 3-5 并行
fix_priority: critical-first
```

### 批次积累修复（Medium/Low）
MEDIUM和LOW问题积累到该批次结束时统一处理。

### 横向展开修复
Phase 5中发现的跨文件模式，创建专门的批量修复agent。

### 最终汇总
所有批次完成后，汇总全部修复：
1. 运行 `pnpm lint:fix` 自动修复格式
2. 验证 `pnpm typecheck` 通过
3. 验证 `pnpm test` 通过
4. 提交所有变更
5. 推送到远程

## Agent提示词模板

每个审查agent的prompt应包含：

```markdown
# MarkArtLand [方向] 审查

审查重点：[具体维度描述]

## 方法
1. 读取以下指定的文件：[文件列表]
2. 检查：[具体检查项]
3. 对每个发现输出：[格式]

## 输出格式
每条发现：
```
## [严重性] 问题标题
**文件:** `path/to/file.ts:line`
**问题描述:**
**修复建议:**
```

## 注意事项
- 每个发现必须有文件:行号引用
- 严重性分级：Critical > High > Medium > Low
- 不要修改文件——本agent只负责审查
```

## 完整执行命令

```bash
# 各阶段验证命令
pnpm typecheck          # Phase 9
pnpm lint               # Phase 9
pnpm lint:fix           # Phase 14 汇总
pnpm test               # Phase 14
pnpm validate           # Phase 14 终验
```

## 设计原则

1. **分批递进**：每批6-8个agent，覆盖合理维度，前一批的输出是后一批的输入
2. **横向展开**：对Phase 1-2中发现的高频问题类型，追加专门的横向扫描agent
3. **零人工干预**：全部阶段自动编排，从审查到修复到推送无人工步骤
4. **全量验证**：每批修复后执行lint/typecheck/test验证
5. **完全覆盖**：14个Phase确保代码、配置、文档、依赖、构建、部署零盲区
6. **基于实践**：本skill基于14轮、68+agent的真实审查战役提炼方法论