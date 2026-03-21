---
name: cicd
description: |
  CI/CD 파이프라인 구성 및 배포 자동화.
  Use when: GitHub Actions, CI 파이프라인, 자동 배포, 품질 게이트, preview deploy.
  NOT for: Docker 이미지 빌드 (→ /docker), 프로덕션 런타임 모니터링 (→ /production-checklist).
---

# CI/CD

풀스택 프로젝트(BE + FE)의 GitHub Actions 기반 CI/CD 파이프라인.

## Stack Detection

프로젝트 파일로 파이프라인 자동 결정:
- `pyproject.toml` → BE 파이프라인
- `package.json` → FE 파이프라인
- 둘 다 → 양쪽 모두 실행

## GitHub Actions 구조

### 디렉토리 레이아웃
```
.github/
  workflows/
    ci.yml              # 메인 CI (PR, push)
    deploy-staging.yml   # 스테이징 배포
    deploy-prod.yml      # 프로덕션 배포
  actions/
    setup-be/action.yml  # BE 환경 셋업 (재사용)
    setup-fe/action.yml  # FE 환경 셋업 (재사용)
```

### Reusable Setup Actions

**BE 셋업** (`.github/actions/setup-be/action.yml`):
```yaml
name: Setup Backend
description: Python + Poetry 환경 구성
runs:
  using: composite
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: "3.13"

    - name: Cache Poetry
      uses: actions/cache@v4
      with:
        path: |
          ~/.cache/pypoetry
          ~/.local
          .venv
        key: poetry-${{ runner.os }}-${{ hashFiles('**/poetry.lock') }}
        restore-keys: poetry-${{ runner.os }}-

    - name: Install Poetry & Dependencies
      shell: bash
      run: |
        pipx install poetry
        poetry install --no-interaction
```

**FE 셋업** (`.github/actions/setup-fe/action.yml`):
```yaml
name: Setup Frontend
description: Node.js + pnpm 환경 구성
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

    - name: Install Dependencies
      shell: bash
      working-directory: frontend
      run: pnpm install --frozen-lockfile
```

## BE 파이프라인

### 전체 흐름
```
lint → type-check → test → security-scan → build
```

### CI 워크플로우 (BE 부분)
```yaml
jobs:
  be-lint:
    name: "BE: Lint"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run ruff check .
      - run: poetry run ruff format --check .

  be-typecheck:
    name: "BE: Type Check"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run mypy --strict app/

  be-test:
    name: "BE: Test"
    runs-on: ubuntu-latest
    needs: [be-lint, be-typecheck]
    defaults:
      run:
        working-directory: backend
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run pytest --cov=app --cov-report=xml --cov-fail-under=80
      - uses: codecov/codecov-action@v4
        with:
          file: backend/coverage.xml

  be-security:
    name: "BE: Security Scan"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-be
      - run: poetry run pip-audit
      - run: poetry run bandit -r app/ -c pyproject.toml

  be-build:
    name: "BE: Build Image"
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

### 전체 흐름
```
lint → type-check → test → build → lighthouse
```

### CI 워크플로우 (FE 부분)
```yaml
jobs:
  fe-lint:
    name: "FE: Lint"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm eslint .
      - run: pnpm prettier --check .

  fe-typecheck:
    name: "FE: Type Check"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm tsc --noEmit

  fe-test:
    name: "FE: Test"
    runs-on: ubuntu-latest
    needs: [fe-lint, fe-typecheck]
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm test --coverage
      - uses: codecov/codecov-action@v4
        with:
          file: frontend/coverage/lcov.info

  fe-build:
    name: "FE: Build"
    runs-on: ubuntu-latest
    needs: [fe-test]
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe

      - name: Cache Next.js
        uses: actions/cache@v4
        with:
          path: frontend/.next/cache
          key: nextjs-${{ runner.os }}-${{ hashFiles('frontend/pnpm-lock.yaml') }}-${{ hashFiles('frontend/src/**') }}
          restore-keys: nextjs-${{ runner.os }}-${{ hashFiles('frontend/pnpm-lock.yaml') }}-

      - run: pnpm build

  fe-lighthouse:
    name: "FE: Lighthouse CI"
    runs-on: ubuntu-latest
    needs: [fe-build]
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/setup-fe
      - run: pnpm build
        working-directory: frontend
      - uses: treosh/lighthouse-ci-action@v12
        with:
          configPath: frontend/lighthouserc.json
          uploadArtifacts: true
```

## Quality Gates

모든 PR에 필수 통과 조건:

| 항목 | 기준 | 실패 시 |
|------|------|---------|
| 테스트 커버리지 | >= 80% | PR 머지 차단 |
| 타입 에러 | 0개 | PR 머지 차단 |
| Lint 에러 | 0개 | PR 머지 차단 |
| 보안 취약점 | 0개 (high/critical) | PR 머지 차단 |
| Lighthouse Performance | >= 90 | 경고 (차단 안 함) |

### Branch Protection 설정
```
Settings → Branches → main:
  ✅ Require status checks to pass
    - be-lint
    - be-typecheck
    - be-test
    - be-security
    - fe-lint
    - fe-typecheck
    - fe-test
    - fe-build
  ✅ Require pull request reviews (1+)
  ✅ Require conversation resolution
```

## 배포 트리거

### 전략
| 이벤트 | 대상 | 방식 |
|--------|------|------|
| PR 생성/업데이트 | Preview | 자동 (Vercel/Cloudflare) |
| `main` 브랜치 push | Staging | 자동 배포 |
| `v*` 태그 push | Production | 수동 승인 후 배포 |

### 스테이징 배포 (자동)
```yaml
name: Deploy Staging
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Build & Push BE Image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          tags: registry.example.com/app-backend:staging
          cache-from: type=gha

      - name: Deploy to Staging
        run: |
          # SSH 또는 클라우드 CLI로 배포
          echo "Deploying to staging..."
```

### 프로덕션 배포 (수동 승인)
```yaml
name: Deploy Production
on:
  push:
    tags: ["v*"]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4

      - name: Build & Push BE Image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          tags: |
            registry.example.com/app-backend:${{ github.ref_name }}
            registry.example.com/app-backend:latest

      - name: Deploy to Production
        run: |
          echo "Deploying ${{ github.ref_name }} to production..."
```

## Vercel/Cloudflare 배포 (FE)

### Preview Deploy (PR)
```yaml
# Vercel이 자동 처리 (GitHub 앱 연동)
# 또는 수동 설정:
jobs:
  preview:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
```

### Production Deploy (main)
```yaml
jobs:
  deploy-fe:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: "--prod"
```

## 캐시 전략

### 캐시 대상 및 키

| 대상 | 경로 | 키 |
|------|------|----|
| Poetry | `~/.cache/pypoetry`, `.venv` | `poetry-{os}-{hash(poetry.lock)}` |
| pnpm store | pnpm store path | 자동 (`setup-node` cache 옵션) |
| Next.js | `.next/cache` | `nextjs-{os}-{hash(pnpm-lock)}-{hash(src)}` |
| Docker layers | GHA cache | `type=gha` (BuildKit) |

### 캐시 크기 관리
- GitHub Actions 캐시 제한: 10GB/리포지토리
- 오래된 캐시 자동 정리: 7일 미사용 시 삭제
- 캐시 키에 lock 파일 해시 포함 → 의존성 변경 시 자동 갱신

## Matrix Strategy (멀티 버전 테스트)

```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: ["3.13"]
        node-version: ["20", "22"]
        os: [ubuntu-latest]
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
```

## Lighthouse CI 설정

**`frontend/lighthouserc.json`**:
```json
{
  "ci": {
    "collect": {
      "startServerCommand": "pnpm start",
      "url": ["http://localhost:3000"],
      "numberOfRuns": 3
    },
    "assert": {
      "assertions": {
        "categories:performance": ["warn", { "minScore": 0.9 }],
        "categories:accessibility": ["error", { "minScore": 0.9 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }],
        "categories:seo": ["warn", { "minScore": 0.9 }]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```
