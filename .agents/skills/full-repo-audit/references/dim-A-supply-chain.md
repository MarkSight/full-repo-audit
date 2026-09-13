# W1 机密与供应链

放在第一波的理由：扫描成本最低、信噪比最高，且一旦命中需要**立刻人工止损**（轮换凭据），
不能等到第 14 波才发现。本波的结论还可能改变整体审查范围。

---

## A1 机密与凭据暴露

**适用**：所有仓库，无例外。

### 检查项

1. **工作区明文凭据**：API key、token、密码、私钥、连接串、云账号凭据、
   webhook secret、JWT 签名密钥、服务账号 JSON。
2. **git 历史**：当前文件干净不代表历史干净。扫 `git log -p` 或用专用工具
   （`gitleaks detect --no-git=false`、`trufflehog git file://.`）。
   **历史里的凭据等同于已泄露**，必须轮换。
3. **伪装位置**：`.env*`（含 `.env.example` 里填了真值）、测试夹具、快照文件、
   CI 配置、文档与 README 示例、注释掉的代码、日志样例、issue/PR 模板、
   Jupyter notebook 输出、lock 文件里的私有 registry 认证串。
4. **客户端泄露**：构建产物/前端 bundle 中是否出现服务端密钥；
   公开前缀（`NEXT_PUBLIC_`、`VITE_`、`PUBLIC_`、`REACT_APP_`）是否被误用于敏感值。
5. **凭据管理方式**：是否从环境/密钥管理服务注入；是否有启动期校验；
   是否存在「默认值兜底」（`process.env.SECRET || 'dev-secret'` 这类在生产会静默生效）。
6. **忽略规则有效性**：`.gitignore` 是否覆盖 `.env`、凭据目录、
   `*.pem`/`*.key`/`*.p12`；已被跟踪的文件加忽略规则无效（需 `git rm --cached`）。
7. **日志与错误输出**：是否打印完整请求头（Authorization）、cookie、请求体、
   连接串、堆栈中的凭据参数。
8. **第三方上报**：错误监控/分析 SDK 是否会把 token、PII 带出去；是否配置了脱敏。

### 严重度基线

| 情形 | 级别 |
|------|------|
| 生产凭据在工作区或历史中明文 | Critical（立即上报，人工轮换） |
| 默认密钥/弱默认值在生产路径可生效 | Critical |
| 测试/示例凭据指向真实服务 | High |
| 日志打印 Authorization / cookie 全文 | High |
| 纯本地 dev 假值、明确标注 fake | Info（不入台账，除格式问题） |

### 禁止自动修复

发现真实凭据时 skill **只报告**：泄露位置、暴露范围（是否推送到远端/公开仓库）、
影响系统、轮换步骤、历史清理方案（`git filter-repo` / BFG，并说明需要强推与协作者代价）。
不自动改、不自动推、不把凭据内容写进报告正文（用 `path:line` + 前 4 位指纹代替）。

---

## A2 依赖漏洞与陈旧度

**适用**：有依赖清单的仓库。

### 检查项

1. **已知漏洞**：跑画像里记录的审计命令（`npm/pnpm audit`、`pip-audit`、
   `govulncheck`、`cargo audit`、`composer audit`、`dotnet list package --vulnerable`）；
   无工具时用 lock 文件版本对照公告。区分**直接依赖**与**传递依赖**（后者修法不同：
   overrides/resolutions 或等上游）。
2. **可达性判断**：漏洞函数是否真的被调用。高危但不可达 → 降级为 Medium 并说明；
   中危但在认证路径上 → 提级。别把 audit 输出原样搬进台账。
3. **陈旧度**：落后主版本数、最后发布时间、是否已废弃/归档（unmaintained 是风险）。
4. **重复与版本分裂**：同一依赖多版本共存（体积与行为不一致），
   同类库重复引入（两个 HTTP 客户端、两个日期库、两个状态管理）。
5. **peer/engine 约束**：peer 冲突、`engines`/`python_requires`/`rust-version` 与
   CI 和生产运行时是否一致；Dockerfile 基础镜像版本与声明是否一致。
6. **依赖边界合理性**：`devDependencies` 被生产代码 import；
   本应是 peer 的被写成 dependency；体积巨大的包只为一个工具函数。
7. **更新机制**：是否有 Dependabot/Renovate；是否有人处理它的 PR（看历史）。

### 禁止自动修复

大版本升级、锁文件大面积重写不自动做。输出分级升级清单：
`安全补丁（可直接升）/ 小版本（需跑测试）/ 大版本（需人工评估 breaking change）`。

---

## A3 供应链完整性

**适用**：所有仓库。这是最常被整轮审查漏掉的维度。

### 检查项

1. **锁文件**：是否存在、是否提交、是否与清单同步（CI 用 frozen/ci 模式安装，
   而不是会改写锁文件的普通 install）。多包仓是否出现锁文件分裂。
2. **安装期脚本**：`postinstall`/`prepare`/`setup.py` 中的任意代码执行；
   是否从网络下载二进制（校验 checksum 了吗）；CI 是否可用 `--ignore-scripts`。
3. **来源可信**：依赖是否来自官方 registry；是否有 git URL / tarball URL / 本地路径依赖
   （不可复现、不可审计）；私有 registry 配置是否把认证写进仓库。
4. **版本钉死程度**：生产镜像与 CI action 是否用可变标签（`latest`、`@main`、
   `@v3` 浮动 tag）；关键 action 是否钉到 commit SHA。
5. **Typosquatting / 可疑新依赖**：近期新增依赖是否拼写近似知名包、下载量极低、
   维护者单一、刚发布。用 `git log` 看依赖新增记录。
6. **构建产物来源**：仓库中是否提交了来源不明的二进制/压缩包/wasm/字体；
   能否从源码复现。
7. **SBOM 与 provenance**：是否生成 SBOM；发布产物是否有签名/attestation
   （有发布行为的仓库才要求）。
8. **CI 凭据最小化**（与 H2 联动）：workflow 是否默认 `permissions: read-all`；
   是否对 fork PR 暴露 secrets（`pull_request_target` 误用是典型高危）。

---

## A4 许可证与合规

**适用**：有依赖或要对外分发的仓库。

### 检查项

1. **本仓许可证**：`LICENSE` 是否存在、与 manifest 中声明一致、
   年份/主体正确、README 声明一致。
2. **依赖许可证**：是否存在 copyleft（GPL/AGPL/SSPL）与本仓分发模式冲突；
   是否有 `UNLICENSED`/无许可证/自定义许可证依赖。
3. **归属义务**：需要保留版权声明的依赖（MIT/BSD/Apache）是否有归属文件；
   Apache-2.0 的 NOTICE 是否保留。
4. **资源素材**：字体、图标、图片、音频、示例数据、AI 生成素材的授权与使用范围；
   商标使用是否合规。
5. **代码片段来源**：从博客/SO/其他仓库复制的代码是否保留来源与许可证声明。
6. **数据合规**（与 B7 联动）：仓库内是否含真实用户数据做夹具。

### 严重度基线

| 情形 | 级别 |
|------|------|
| AGPL/SSPL 依赖进入闭源分发物 | Critical |
| 无许可证依赖 / 许可证不明 | High |
| 缺归属文件 | Medium |
| LICENSE 与 manifest 声明不一致 | Medium |
| 年份过期 | Low |
