---
name: cicd
description: |
  CI/CD 파이프라인 구성 및 배포 자동화.
  Use when: GitHub Actions, CI 파이프라인, 자동 배포, 품질 게이트, preview deploy.
  NOT for: Docker 이미지 빌드 (→ /docker), 프로덕션 런타임 모니터링 (→ /production-checklist).
---

# CI/CD

GitHub Actions 기반 풀스택 CI/CD 파이프라인.

## GitHub Actions 구조

```
.github/
  workflows/
    ci.yml              # 메인 CI (PR, push)
    deploy-staging.yml   # 스테이징 배포
    deploy-prod.yml      # 프로덕션 배포
  actions/
    setup-be/action.yml  # BE 환경 (재사용)
    setup-fe/action.yml  # FE 환경 (재사용)
```

### BE 셋업 (`.github/actions/setup-be/action.yml`)
```yaml
name: Setup Backend
runs:
  using: composite
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: "3.13"
    - uses: actions/cache@v4
      with:
        path: |
          ~/.cache/pypoetry
          ~/.local
          .venv
        key: poetry-${{ runner.os }}-${{ hashFiles('**/poetry.lock') }}
    - shell: bash
      run: |
        pipx install poetry
        poetry install --no-interaction
```

### FE 셋업 (`.github/actions/setup-fe/action.yml`)
```yaml
name: Setup Frontend
runs:
  using: composite
  steps:
    - uses: pnpm/action-setup@v4
      with:
        version: latest
    - uses: actions/setup-node@v4
      with:
        node-version: "20"
        cache: "pnpm"
        cache-dependency-path: frontend/pnpm-lock.yaml
    - shell: bash
      working-directory: frontend
      run: pnpm install --frozen-lockfile
```

## BE 파이프라인

흐름: `lint → type-check → test → security-scan → build`

```yaml
jobs:
  be-lint:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: backend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run ruff check . && poetry run ruff format --check .

  be-typecheck:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: backend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run mypy --strict app/

  be-test:
    runs-on: ubuntu-latest
    needs: [be-lint, be-typecheck]
    defaults: { run: { working-directory: backend } }
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_DB: test_db, POSTGRES_USER: test, POSTGRES_PASSWORD: test }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
        options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run pytest --cov=app --cov-report=xml --cov-fail-under=80
      - uses: codecov/codecov-action@v4
        with: { file: backend/coverage.xml }

  be-security:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: backend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run pip-audit && poetry run bandit -r app/ -c pyproject.toml

  be-build:
    runs-on: ubuntu-latest
    needs: [be-test, be-security]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: false
          tags: app-backend:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## FE 파이프라인

흐름: `lint → type-check → test → build → lighthouse`

```yaml
jobs:
  fe-lint:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: frontend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm eslint . && pnpm prettier --check .

  fe-typecheck:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: frontend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm tsc --noEmit

  fe-test:
    runs-on: ubuntu-latest
    needs: [fe-lint, fe-typecheck]
    defaults: { run: { working-directory: frontend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm test --coverage
      - uses: codecov/codecov-action@v4
        with: { file: frontend/coverage/lcov.info }

  fe-build:
    runs-on: ubuntu-latest
    needs: [fe-test]
    defaults: { run: { working-directory: frontend } }
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - uses: actions/cache@v4
        with:
          path: frontend/.next/cache
          key: nextjs-${{ runner.os }}-${{ hashFiles('frontend/pnpm-lock.yaml') }}-${{ hashFiles('frontend/src/**') }}
      - run: pnpm build
```

Lighthouse CI / Matrix Strategy → `references/advanced-pipelines.md`

## Quality Gates

| 항목 | 기준 | 실패 시 |
|------|------|---------|
| 커버리지 | >= 80% | PR 차단 |
| 타입 에러 | 0개 | PR 차단 |
| Lint 에러 | 0개 | PR 차단 |
| 보안 취약점 | 0 (high/critical) | PR 차단 |
| Lighthouse | >= 90 | 경고만 |

### Branch Protection
```
main: ✅ Require status checks (be-lint/typecheck/test/security, fe-lint/typecheck/test/build)
      ✅ Require PR reviews (1+) ✅ Require conversation resolution
```

## 배포 트리거

| 이벤트 | 대상 | 방식 |
|--------|------|------|
| PR 생성/업데이트 | Preview | 자동 (Vercel/Cloudflare) |
| `main` push | Staging | 자동 |
| `v*` 태그 | Production | 수동 승인 후 |

배포 YAML 상세 → `references/deployment-strategies.md`

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
