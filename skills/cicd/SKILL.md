---
name: cicd
description: |
  프로젝트 CI/CD 파이프라인 레퍼런스.
  Use when: GitHub Actions 작성, 워크플로우 만들기, CI 파이프라인 구성,
  자동 배포 설정, PR 검증 자동화, 린트 자동화, 테스트 자동화,
  quality gate 설정, 커버리지 임계값, 품질 기준,
  Alembic CI 마이그레이션 검증, 마이그레이션 체크,
  pip-audit, 보안 스캔 CI, ruff CI, mypy CI, import-linter CI,
  Docker 빌드 CI, 이미지 푸시 자동화.
  NOT for: GitHub Actions 일반 문법 (그건 Claude가 이미 앎).
---

# CI/CD Skill

## GitHub Actions

```yaml
name: CI
on:
  push: {branches: [main, develop]}
  pull_request: {branches: [main]}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install poetry
      - run: poetry install --no-interaction
      - run: poetry run ruff check .
      - run: poetry run ruff format --check .
      - run: poetry run mypy app/
      - run: poetry run lint-imports
      - run: poetry run python scripts/check_versioning.py

  test:
    runs-on: ubuntu-latest
    needs: lint
    services:
      postgres:
        image: postgres:16-alpine
        env: {POSTGRES_DB: test_db, POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres}
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
        ports: ["5432:5432"]
      redis:
        image: redis:7-alpine
        options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
        ports: ["6379:6379"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install poetry
      - run: poetry install --no-interaction
      - run: poetry run pytest --cov=app --cov-report=xml -v
        env: {APP_ENV: test, DATABASE__HOST: localhost, DATABASE__NAME: test_db}
      - uses: codecov/codecov-action@v4

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install poetry && poetry install --no-interaction
      - run: poetry run ruff check --select S .
      - run: poetry run pip-audit

  build:
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:${{ github.sha }} .
```

## 품질 게이트

| 게이트 | 도구 | 임계값 |
|--------|------|--------|
| 린트 | Ruff | 에러 0건 |
| 타입 검사 | mypy --strict | 에러 0건 |
| 아키텍처 | import-linter | 모든 계약 통과 |
| 단위 테스트 | pytest | 100% 통과 |
| 커버리지 | pytest-cov | ≥80% |
| 보안 | ruff (bandit) | high/critical 0건 |
| 의존성 | pip-audit | 알려진 취약점 0건 |
| 버저닝 | check_versioning.py | 하드코딩 경로 없음 |

## CI에서의 Alembic

```yaml
- run: poetry run alembic upgrade head
- run: poetry run alembic check 2>&1 | grep -q "No new upgrade" || (echo "Pending migrations!" && exit 1)
```
