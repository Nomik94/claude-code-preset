---
name: docker
description: |
  FastAPI + Poetry Docker 설정 레퍼런스.
  Use when: Dockerfile 작성, Dockerfile 수정, docker-compose 설정, compose 세팅,
  이미지 빌드, 멀티스테이지 빌드, 이미지 최적화, 이미지 크기 줄이기,
  로컬 개발환경 구성, 개발환경 Docker로, DB/Redis 컨테이너,
  배포 준비, 컨테이너화, healthcheck 설정, non-root 유저,
  .dockerignore, 레이어 캐싱, Poetry Docker 설치.
  NOT for: Kubernetes, 클라우드 배포 (그건 일반 지식).
---

# Docker 스킬

## .dockerignore

MUST: 프로젝트 루트에 `.dockerignore` 파일이 존재해야 한다.

```
.venv/
__pycache__/
.git/
*.pyc
.env
.env.*
node_modules/
tests/
.mypy_cache/
.pytest_cache/
.ruff_cache/
```

**MUST: `.env` 파일은 반드시 제외한다.** 이미지가 레지스트리에 push될 경우 시크릿이 유출되는 보안 사고로 이어진다. `.env`와 `.env.*` 패턴 모두 명시적으로 제외할 것.

## Dockerfile (FastAPI + Poetry)

```dockerfile
# -- Build --
FROM python:3.13-slim AS builder
RUN pip install poetry
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-interaction --no-ansi

# -- Runtime --
FROM python:3.13-slim AS runtime
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY app/ ./app/
COPY migrations/ ./migrations/
COPY alembic.ini ./

RUN adduser --disabled-password --gecos '' appuser
USER appuser
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

## docker-compose.yml (Development)

```yaml
services:
  app:
    build: .
    ports: ["8000:8000"]
    env_file: .env.local
    environment:
      - APP_ENV=local
      - DATABASE__HOST=db
      - REDIS__HOST=redis
    depends_on:
      db: {condition: service_healthy}
      redis: {condition: service_healthy}
    volumes: ["./app:/app/app"]
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: myapp_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  worker:
    build: .
    env_file: .env.local
    environment:
      - DATABASE__HOST=db
      - REDIS__HOST=redis
    depends_on: [db, redis]
    command: celery -A app.worker worker --loglevel=info

volumes:
  pgdata:
```

## 체크리스트

- [ ] `.dockerignore` 파일이 존재하고 `.env`, `.env.*`가 제외되어 있는가
- [ ] `FROM python:3.13-slim` 사용 (Python 3.13+ 필수)
- [ ] site-packages 경로가 `python3.13`인가
- [ ] 멀티스테이지 빌드로 빌드/런타임 분리되어 있는가
- [ ] non-root 유저(`appuser`)로 실행하는가
- [ ] healthcheck가 DB, Redis 등 의존 서비스에 설정되어 있는가
- [ ] 레이어 캐싱: `pyproject.toml` + `poetry.lock`을 소스 코드보다 먼저 COPY하는가
- [ ] 하드코딩된 시크릿이 Dockerfile/compose에 없는가

## 핵심 규칙

1. **MUST** `.dockerignore`에 `.env`와 `.env.*` 포함 -- 보안 필수
2. **MUST** 멀티스테이지 빌드 -- 빌드 도구가 런타임 이미지에 포함되면 안 된다
3. **MUST** non-root 유저 -- 컨테이너 탈출 시 피해 최소화
4. **MUST** healthcheck -- 오케스트레이션 준비 상태 확인
5. **MUST** `pyproject.toml` 먼저 COPY -- 레이어 캐싱 활용
6. **MUST** `python:3.13-slim` 기반 이미지 사용
