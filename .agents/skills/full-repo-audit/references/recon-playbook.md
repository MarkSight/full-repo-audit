# Phase 0 侦察手册

目标：在不修改任何文件的前提下，产出 `audit/00-profile.md`（仓库画像）与
`audit/00-plan.md`（审查计划）。画像是后续 14 个波次唯一的路径与命令来源。

优先跑 `scripts/repo-profile.sh`；它只做只读探测。本手册用于补齐脚本没覆盖的部分，
以及在脚本不可用时手工完成。

## 1. 语言与规模

```bash
git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -30   # 扩展名分布
git ls-files | wc -l                                                   # 纳管文件数
git ls-files -z | xargs -0 wc -l 2>/dev/null | tail -1                 # 总行数
git ls-files | xargs -I{} du -k {} 2>/dev/null | sort -rn | head -20   # 最大文件
```

判断档位（S/M/L/XL）时只数**源码文件**，排除 lock 文件、快照、生成产物、
`vendor/`、`node_modules/`、二进制资源。

## 2. 构建与验证命令（按生态映射）

画像里必须写出**本仓实际可用**的命令，而不是生态的默认命令。先看脚本定义，再看 CI 配置
（CI 里跑什么就是真门禁），最后才猜默认值。

| 生态 | 识别文件 | 依赖安装 | 格式/Lint | 类型 | 测试 | 构建 | 依赖审计 |
|------|---------|---------|-----------|------|------|------|---------|
| Node/TS | `package.json` + lock | `npm ci` / `pnpm i --frozen-lockfile` / `yarn --immutable` / `bun i` | `eslint` / `biome check` / `prettier` | `tsc --noEmit` | `vitest` / `jest` / `node --test` / `playwright` | `tsc` / `vite build` / 框架 build | `npm audit` / `pnpm audit` / `osv-scanner` |
| Python | `pyproject.toml` / `requirements*.txt` | `uv sync` / `poetry install` / `pip install -r` | `ruff` / `black` / `flake8` | `mypy` / `pyright` | `pytest` / `unittest` | `python -m build` | `pip-audit` / `uv pip audit` |
| Go | `go.mod` | `go mod download` | `gofmt -l` / `golangci-lint` | `go vet` / `go build ./...` | `go test ./...` | `go build ./...` | `govulncheck` |
| Rust | `Cargo.toml` | `cargo fetch` | `cargo fmt --check` / `cargo clippy` | `cargo check` | `cargo test` | `cargo build --release` | `cargo audit` / `cargo deny` |
| Java/Kotlin | `pom.xml` / `build.gradle*` | `mvn -q dependency:go-offline` / `gradle deps` | `spotless` / `ktlint` / `checkstyle` | 编译即类型 | `mvn test` / `gradle test` | `mvn package` / `gradle build` | `dependency-check` / `gradle dependencyCheck` |
| Ruby | `Gemfile` | `bundle install` | `rubocop` | `sorbet`（若有） | `rspec` / `rake test` | — | `bundle audit` |
| PHP | `composer.json` | `composer install` | `php-cs-fixer` / `phpcs` | `phpstan` / `psalm` | `phpunit` / `pest` | — | `composer audit` |
| .NET | `*.csproj` / `*.sln` | `dotnet restore` | `dotnet format` | 编译即类型 | `dotnet test` | `dotnet build` | `dotnet list package --vulnerable` |
| Elixir | `mix.exs` | `mix deps.get` | `mix format --check-formatted` | `mix dialyzer` | `mix test` | `mix compile` | `mix deps.audit` |
| Swift | `Package.swift` / `*.xcodeproj` | `swift package resolve` | `swiftformat` / `swiftlint` | 编译即类型 | `swift test` / `xcodebuild test` | `swift build` | — |
| Shell | `*.sh` | — | `shellcheck` / `shfmt` | — | `bats` | — | — |
| Terraform | `*.tf` | `terraform init` | `terraform fmt -check` / `tflint` | `terraform validate` | `terratest` | `terraform plan` | `tfsec` / `checkov` |
| K8s/Helm | `*.yaml` / `Chart.yaml` | — | `kubeconform` / `helm lint` | — | — | `helm template` | `kubesec` / `trivy` |

**单仓多生态是常态**：画像要按生态分别记录，并记录各自的子树范围。
别把 monorepo 根命令当作每个子包都适用。

## 3. 工作区与模块图

```bash
cat package.json 2>/dev/null | grep -A5 workspaces
ls pnpm-workspace.yaml turbo.json nx.json lerna.json Cargo.toml go.work 2>/dev/null
git ls-files | awk -F/ 'NF>1{print $1"/"$2}' | sort -u | head -60       # 顶层模块
```

产出「模块 → 角色」映射（角色定义见 SKILL.md）。每个模块记录：
路径、语言、对外暴露什么、依赖谁、是否含信任边界、测试在哪。

## 4. 框架与运行形态信号

| 判断 | 信号 |
|------|------|
| 有 HTTP 服务 | 路由/controller 目录、`app.listen`、server 框架依赖、OpenAPI 文件 |
| 有前端 | 组件/模板目录、前端框架依赖、`index.html`、样式文件、构建 bundler |
| 有 CLI | `bin` 字段、`argparse`/`clap`/`cobra`、`#!/usr/bin/env` 入口 |
| 是库 | 有 publish 配置、`exports`/`public` API 定义、无应用入口 |
| 有数据库 | ORM 依赖、迁移目录、连接字符串读取、SQL 文件 |
| 有后台任务 | 队列依赖、worker 入口、cron 定义、定时任务清单 |
| 有 AI/Agent 组件 | 模型 SDK 依赖、prompt/skill 目录、工具注册表 |
| 有多租户 | 租户/组织 ID 贯穿 schema 与查询 |
| 有容器/IaC | `Dockerfile`、`compose*.y*ml`、`*.tf`、`k8s/`、`helm/` |

形态决定维度适用性：纯库不查 B5 Web 加固，无前端不查 G2/G3/F3，无 DB 不查 C1-C3/C7。

## 5. 热点与风险排序（XL 仓必做）

```bash
git log --since='90 days ago' --name-only --pretty=format: | sort | uniq -c | sort -rn | head -40
git log --since='90 days ago' --pretty='%s' | grep -icE 'fix|bug|hotfix|revert'
```

风险分 = 变更频率 × 文件规模 × 是否信任边界 × 是否缺测试。
XL 仓只深挖风险分 top 30%，其余做索引级扫描。

## 6. 已有治理现状（决定 W11 要补什么）

清点并记录是否存在、是否在 CI 中强制：
lint/format 配置、类型检查、测试与覆盖率门槛、pre-commit hook、CODEOWNERS、
分支保护、依赖更新机器人、安全扫描、`SECURITY.md`、ADR/设计文档目录、CHANGELOG 纪律。

## 7. 画像模板

```markdown
# 仓库画像

- 审查时间 / 基线 commit / 分支 / 工作区是否干净
- 规模档位：M（源码文件 742，行数 ~96k）
- 生态：TypeScript(主) + Python(scripts/) + Terraform(infra/)
- 运行形态：HTTP 服务 + 前端 SPA + CLI；有 DB（迁移目录 db/migrations）；有队列；多租户

## 验证命令（实测可用）
| 门禁 | 命令 | CI 中强制 |
| lint | … | 是 |
| typecheck | … | 是 |
| test | … | 是（无覆盖率门槛） |
| build | … | 是 |
| e2e | 无 | — |
| 依赖审计 | 无 | — |

## 模块 → 角色
| 模块 | 角色 | 语言 | 信任边界 | 测试位置 |

## 热点文件 top N（变更频率 × 规模）

## 治理现状
（有什么、缺什么 → 交 W11）

## 维度适用矩阵
| 维度 | 适用 | 原因 / 抽样策略 |
| A1 机密 | 适用 | 全量 + git 历史 |
| G2 a11y | 适用 | 仅 web/ 子树 |
| C7 备份恢复 | 不适用 | 无自管数据库，托管服务负责 |
| … |
```

## 8. 纪律

- **只读**：Phase 0 不改任何文件，不装依赖，不跑迁移。需要安装才能验证的命令，
  记录为「未实测」并说明原因。
- **不猜**：命令写不出来就标「未知」，由 W8/W11 作为发现处理，别编一条跑不通的命令。
- **画像要可复核**：每个结论附探测依据（哪个文件、哪条命令输出）。
