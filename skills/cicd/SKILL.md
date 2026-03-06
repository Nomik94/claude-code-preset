---
name: cicd
description: |
  프로젝트 CI/CD 파이프라인 레퍼런스.
  Use when: GitHub Actions 작성, 워크플로우 만들기, CI 파이프라인 구성,
  자동 배포 설정, PR 검증 자동화, 린트 자동화, 테스트 자동화,
  quality gate 설정, 커버리지 임계값, 품질 기준,
  Alembic CI 마이그레이션 검증, 마이그레이션 체크,
  pip-audit, 보안 스캔 CI, ruff CI, mypy CI, import-linter CI,
  vulture CI, deptry CI, Conventional Commits CI,
  Docker 빌드 CI, 이미지 푸시 자동화.
  NOT for: GitHub Actions 일반 문법 (그건 Claude가 이미 앎).
---

# CI/CD Skill

## GitHub Actions 워크플로우 구조

MUST: 모든 워크플로우는 아래 4개 job 구조를 따른다.

### Job 의존성

```
lint → test → build
         ↑
security ─┘
```

### lint job

MUST include:
- [ ] `actions/setup-python@v5` with `python-version: "3.13"`
- [ ] `poetry install --no-interaction`
- [ ] `poetry run ruff check .`
- [ ] `poetry run ruff format --check .`
- [ ] `poetry run mypy app/`
- [ ] `poetry run vulture app/ .vulture_whitelist.py` -- dead code detection
- [ ] `poetry run deptry .` -- unused/missing dependency detection
- [ ] `poetry run lint-imports` -- architecture boundary enforcement
- [ ] Conventional Commits check step (PR title validation)
- [ ] `poetry run python scripts/check_versioning.py`

Conventional Commits check 예시:

```yaml
- name: Check Conventional Commits
  if: github.event_name == 'pull_request'
  run: |
    TITLE="${{ github.event.pull_request.title }}"
    echo "$TITLE" | grep -qE '^(feat|fix|refactor|docs|test|chore|ci|perf|build|style|revert)(\(.+\))?(!)?: .+' \
      || (echo "PR title MUST follow Conventional Commits" && exit 1)
```

### test job

MUST include:
- [ ] `needs: lint`
- [ ] PostgreSQL 16+ service container
- [ ] Redis 7+ service container
- [ ] `poetry run pytest --cov=app --cov-report=xml -v`
- [ ] codecov/codecov-action upload

### security job

MUST include:
- [ ] `poetry run ruff check --select S .` -- bandit rules
- [ ] `poetry run pip-audit`

### build job

MUST include:
- [ ] `needs: [test, security]`
- [ ] `if: github.ref == 'refs/heads/main'`
- [ ] `docker build -t myapp:${{ github.sha }} .`

## 품질 게이트

| 게이트 | 도구 | 임계값 |
|--------|------|--------|
| 린트 | Ruff | 에러 0건 |
| 포맷 | Ruff format | diff 0건 |
| 타입 검사 | mypy --strict | 에러 0건 |
| Dead code | vulture | 미사용 코드 0건 |
| 의존성 정합성 | deptry | 미사용/누락 의존성 0건 |
| 아키텍처 | import-linter | 모든 계약 통과 |
| 커밋 규약 | Conventional Commits | PR 타이틀 규약 준수 |
| 단위 테스트 | pytest | 100% 통과 |
| 커버리지 | pytest-cov | >=80% |
| 보안 | ruff (bandit) | high/critical 0건 |
| 의존성 취약점 | pip-audit | 알려진 취약점 0건 |
| 버저닝 | check_versioning.py | 하드코딩 경로 없음 |

## CI에서의 Alembic

MUST: test job에서 마이그레이션 정합성을 검증한다.

```yaml
- run: poetry run alembic upgrade head
- run: poetry run alembic check 2>&1 | grep -q "No new upgrade" || (echo "Pending migrations!" && exit 1)
```

## 도구별 설정 파일 체크리스트

MUST: CI에 도구를 추가하면 프로젝트 루트에 설정이 존재해야 한다.

- [ ] `vulture` -- `.vulture_whitelist.py` (false positive 화이트리스트)
- [ ] `deptry` -- `pyproject.toml`의 `[tool.deptry]` 섹션
- [ ] `import-linter` -- `pyproject.toml`의 `[tool.importlinter]` 또는 `.importlinter` 파일
- [ ] `ruff` -- `pyproject.toml`의 `[tool.ruff]` 섹션
- [ ] `mypy` -- `pyproject.toml`의 `[tool.mypy]` 섹션

## Poetry dev 의존성

MUST: CI에서 사용하는 모든 도구는 Poetry dev group에 포함되어야 한다.

```
poetry add --group dev ruff mypy vulture deptry import-linter pip-audit pytest pytest-cov pytest-asyncio httpx
```
