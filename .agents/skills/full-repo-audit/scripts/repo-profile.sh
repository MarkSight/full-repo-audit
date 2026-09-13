#!/usr/bin/env bash
# Read-only repository reconnaissance for the full-repo-audit skill.
# Writes nothing, installs nothing, runs no project commands. Output is markdown on stdout.
# Usage: repo-profile.sh [repo-root] > audit/00-profile-raw.md

set -u
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 1

have() { command -v "$1" >/dev/null 2>&1; }
# -z avoids git's path quoting, so paths with spaces/unicode stay intact
files() {
  git ls-files -z 2>/dev/null | tr '\0' '\n' | grep -v '^$' \
    || find . -type f -not -path './.git/*' | sed 's|^\./||'
}
exists() { for p in "$@"; do [ -e "$p" ] && printf '%s ' "$p"; done; }

echo "# Repo profile (raw)"
echo
echo "- root: \`$ROOT\`"
echo "- generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo
echo "## Git baseline"
if [ -d .git ]; then
  echo "- branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "- commit: $(git rev-parse --short HEAD 2>/dev/null)"
  echo "- commits: $(git rev-list --count HEAD 2>/dev/null)"
  echo "- first commit: $(git log --reverse --pretty='%ad' --date=short 2>/dev/null | head -1)"
  echo "- last commit: $(git log -1 --pretty='%ad' --date=short 2>/dev/null)"
  echo "- contributors: $(git shortlog -sn --all 2>/dev/null | wc -l | tr -d ' ')"
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "- uncommitted changes: $DIRTY"
  echo "- remotes:"; git remote -v 2>/dev/null | sed 's/^/  - /'
else
  echo "- not a git repository"
fi

echo
echo "## Size"
echo "- tracked files: $(files | wc -l | tr -d ' ')"
echo
echo "### Extension histogram (top 30)"
echo '```'
files | sed -n 's/.*\.\([A-Za-z0-9_]\{1,12\}\)$/\1/p' | sort | uniq -c | sort -rn | head -30
echo '```'
echo "### Largest tracked files (top 20, KB)"
echo '```'
files | tr '\n' '\0' | xargs -0 du -k 2>/dev/null | sort -rn | head -20
echo '```'

echo
echo "## Ecosystem markers"
for m in package.json pnpm-lock.yaml package-lock.json yarn.lock bun.lockb deno.json \
         pyproject.toml requirements.txt setup.py Pipfile uv.lock poetry.lock \
         go.mod go.work Cargo.toml Gemfile composer.json mix.exs Package.swift \
         pom.xml build.gradle build.gradle.kts build.sbt CMakeLists.txt Makefile justfile Taskfile.yml; do
  [ -e "$m" ] && echo "- root: \`$m\`"
done
echo "### Nested manifests (depth<=4, excluding vendored trees)"
echo '```'
files | grep -E '/(package\.json|pyproject\.toml|go\.mod|Cargo\.toml|composer\.json|pom\.xml|mix\.exs)$' \
      | grep -vE '(^|/)(node_modules|vendor|third_party|\.venv|dist|build)/' \
      | awk -F/ 'NF<=4' | head -40
echo '```'

echo
echo "## Workspace / monorepo layout"
W=$(exists pnpm-workspace.yaml turbo.json nx.json lerna.json rush.json go.work Cargo.toml .github/workflows)
echo "- markers: ${W:-none}"
if have jq && [ -f package.json ]; then
  echo "- package.json workspaces: $(jq -c '.workspaces // empty' package.json 2>/dev/null)"
fi
echo "### Top-level source dirs"
echo '```'
files | awk -F/ 'NF>1 {print $1}' | sort | uniq -c | sort -rn | head -25
echo '```'

echo
echo "## Declared scripts / task targets"
if [ -f package.json ]; then
  echo "### package.json scripts"
  echo '```'
  if have jq; then jq -r '.scripts // {} | to_entries[] | "\(.key): \(.value)"' package.json 2>/dev/null
  else sed -n '/"scripts"/,/}/p' package.json; fi
  echo '```'
fi
for f in Makefile justfile Taskfile.yml; do
  [ -f "$f" ] && { echo "### $f targets"; echo '```'; grep -nE '^[a-zA-Z0-9_.-]+:' "$f" | head -40; echo '```'; }
done
if [ -f pyproject.toml ]; then
  echo "### pyproject tool sections"; echo '```'; grep -nE '^\[tool\.[a-z0-9_.-]+\]' pyproject.toml | head -30; echo '```'
fi

echo
echo "## Tooling config present"
for c in .eslintrc .eslintrc.json .eslintrc.cjs eslint.config.js eslint.config.mjs biome.json biome.jsonc \
         .prettierrc .prettierrc.json prettier.config.js tsconfig.json jsconfig.json \
         ruff.toml .flake8 mypy.ini .pylintrc setup.cfg .golangci.yml .golangci.yaml \
         rustfmt.toml clippy.toml .rubocop.yml phpstan.neon psalm.xml .editorconfig \
         .pre-commit-config.yaml lefthook.yml .husky commitlint.config.js .gitattributes .gitignore; do
  [ -e "$c" ] && echo "- \`$c\`"
done

echo
echo "## CI / delivery"
for d in .github/workflows .gitlab-ci.yml .circleci azure-pipelines.yml Jenkinsfile .buildkite \
         .woodpecker.yml bitbucket-pipelines.yml .drone.yml; do
  [ -e "$d" ] && echo "- \`$d\`"
done
[ -d .github/workflows ] && { echo "### Workflows"; echo '```'; ls .github/workflows | head -30; echo '```'; }
echo "### Containers / IaC"
echo '```'
files | grep -iE '(^|/)(dockerfile[^/]*|compose[^/]*\.ya?ml|docker-compose[^/]*\.ya?ml)$|\.tf$|\.tfvars$|(^|/)(k8s|kubernetes|helm|charts|terraform|ansible|pulumi)/' \
      | head -30
echo '```'
echo "### Release / deploy signals"
echo '```'
exists CHANGELOG.md RELEASING.md .changeset .release-please-manifest.json release.config.js \
       vercel.json netlify.toml fly.toml render.yaml app.yaml Procfile serverless.yml
echo
echo '```'

echo
echo "## Data layer"
echo "### Migration / schema dirs"
echo '```'
files | grep -iE '(^|/)(migrations?|migrate|alembic|prisma|drizzle|schema|sql|db)/' \
      | grep -vE '(^|/)(node_modules|vendor|\.venv)/' | awk -F/ '{print $1"/"$2}' | sort -u | head -25
echo '```'
echo "### ORM / DB client signals"
echo '```'
if [ -f package.json ]; then grep -oE '"(prisma|@prisma/client|drizzle-orm|typeorm|sequelize|knex|mongoose|mongodb|pg|mysql2|better-sqlite3|redis|ioredis|kysely)"' package.json | sort -u; fi
files | grep -E '\.(toml|txt|cfg)$' | tr '\n' '\0' \
  | xargs -0 grep -lIE 'sqlalchemy|alembic|django|psycopg|asyncpg|pymongo|redis' 2>/dev/null | head -5
[ -f go.mod ] && grep -oE '(gorm\.io[^ ]*|github\.com/(jackc|lib|go-sql-driver|redis)[^ ]*)' go.mod | sort -u | head -10
[ -f Cargo.toml ] && grep -oE '^(sqlx|diesel|sea-orm|redis|tokio-postgres)' Cargo.toml | sort -u
echo '```'

echo
echo "## Runtime shape signals"
echo "### Entry points"
echo '```'
files | grep -iE '(^|/)(main|index|server|app|cli|bin|__main__|cmd)\.(ts|tsx|js|mjs|cjs|py|go|rs|rb|php|java|kt|ex|swift)$|(^|/)(cmd|bin)/' \
      | grep -vE '(^|/)(node_modules|vendor|dist|build|\.venv)/' | head -30
echo '```'
echo "### Frontend signals"
echo '```'
if [ -f package.json ]; then grep -oE '"(react|react-dom|next|vue|nuxt|svelte|@sveltejs/kit|solid-js|angular|@angular/core|astro|remix|vite|webpack|tailwindcss|electron|react-native|expo)"' package.json | sort -u; fi
files | grep -cE '\.(tsx|jsx|vue|svelte|astro)$' | sed 's/^/component-ish files: /'
files | grep -cE '\.(css|scss|sass|less|styl)$' | sed 's/^/style files: /'
echo '```'
echo "### i18n / a11y signals"
echo '```'
files | grep -iE '(^|/)(locales?|i18n|lang|translations?)/|\.(po|pot|xliff|ftl)$' | head -15
echo '```'
echo "### Queue / scheduler / AI signals"
echo '```'
if [ -f package.json ]; then grep -oE '"(bullmq|bull|agenda|kafkajs|amqplib|@temporalio/[a-z]+|node-cron|@anthropic-ai/sdk|openai|ai|langchain)"' package.json | sort -u; fi
files | grep -iE '(^|/)(workers?|jobs?|tasks?|queues?|cron|agents?|prompts?|skills?)/' | awk -F/ '{print $1"/"$2}' | sort -u | head -20
echo '```'

echo
echo "## Tests"
echo '```'
files | grep -iE '(^|/)(tests?|__tests__|spec|e2e|integration|cypress|playwright)/|\.(test|spec)\.[a-z]+$|_test\.(go|py|rb)$|test_.*\.py$' \
      | grep -vE '(^|/)(node_modules|vendor|\.venv)/' | wc -l | sed 's/^/test files: /'
files | grep -iE '(^|/)(e2e|cypress|playwright)/|\.e2e\.' | wc -l | sed 's/^/e2e-ish files: /'
exists vitest.config.ts jest.config.js jest.config.ts playwright.config.ts cypress.config.ts \
       pytest.ini tox.ini conftest.py .mocharc.yml karma.conf.js codecov.yml .nycrc
echo
echo '```'

echo
echo "## Documentation"
echo '```'
exists README.md README.rst CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md LICENSE LICENSE.md \
       CHANGELOG.md ARCHITECTURE.md CODEOWNERS .github/CODEOWNERS
echo
files | grep -iE '(^|/)(docs?|design|designs|adr|rfcs?|runbooks?|wiki)/' | awk -F/ '{print $1"/"$2}' | sort -u | head -20
files | grep -ciE '\.mdx?$' | sed 's/^/markdown files: /'
echo '```'

echo
echo "## Hotspots (last 90 days churn)"
echo '```'
git log --since='90 days ago' --name-only --pretty=format: 2>/dev/null \
  | grep -vE '^$' | sort | uniq -c | sort -rn | head -30
echo '```'
echo "- fix-ish commits (90d): $(git log --since='90 days ago' --pretty='%s' 2>/dev/null | grep -icE 'fix|bug|hotfix|revert')"
echo "- total commits (90d): $(git log --since='90 days ago' --oneline 2>/dev/null | wc -l | tr -d ' ')"

echo
echo "## Risk surface greps (counts only — verify before reporting)"
echo '```'
SRC_EXCL='(^|/)(node_modules|vendor|third_party|\.venv|dist|build|out|target|\.next|coverage)/|\.(lock|snap|min\.js|map|svg|png|jpe?g|gif|woff2?|ttf|pdf|zip)$'
SRC_LIST="$(files | grep -vE "$SRC_EXCL")"
# grep the tracked source list only: walking the tree would descend into ignored dirs
c() {
  printf '%-34s %s\n' "$1" \
    "$(printf '%s\n' "$SRC_LIST" | tr '\n' '\0' | xargs -0 grep -lIE "$2" 2>/dev/null | wc -l | tr -d ' ')"
}
c "files with TODO/FIXME/HACK/XXX" 'TODO|FIXME|HACK|XXX'
c "files with eslint/ts/type ignores" '(eslint-disable|@ts-ignore|@ts-expect-error|# type: ignore|#\[allow\()'
c "files with broad catch/except" '(catch *\([^)]*\) *\{ *\}|except Exception|except:|recover\(\)|unwrap\(\))'
c "files reading env directly" '(process\.env|os\.environ|std::env::var|ENV\[|getenv)'
c "files with raw SQL strings" '(SELECT .* FROM|INSERT INTO|UPDATE .* SET|DELETE FROM)'
c "files with shell/exec calls" '(child_process|exec\(|execSync|spawn\(|subprocess|os\.system|Command::new)'
c "files with dynamic eval" '(\beval\(|new Function\(|pickle\.loads|yaml\.load\()'
c "files with outbound http" '(fetch\(|axios|requests\.|http\.Client|urllib|HttpClient)'
c "files with skipped tests" '(\.skip\(|xit\(|xdescribe\(|@pytest\.mark\.skip|t\.Skip\()'
c "files with secret-ish literals" '(api[_-]?key|secret|token|password|passwd|private[_-]?key)[\"'\'' ]*[:=]'
echo '```'
echo
echo "_Counts are signals, not findings. Every number above must be confirmed by reading code before it enters the ledger._"
