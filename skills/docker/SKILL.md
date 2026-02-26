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

## Dockerfile (FastAPI + Poetry)

```dockerfile
# ── Build ──
FROM python:3.12-slim AS builder
RUN pip install poetry
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-interaction --no-ansi

# ── Runtime ──
FROM python:3.12-slim AS runtime
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
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

## 베스트 프랙티스
1. 빌드/런타임 분리 — 이미지 크기 절감
2. Non-root 유저 — 보안
3. Health check — 오케스트레이션 준비 상태 확인
4. 레이어 캐싱 — 소스보다 pyproject.toml 먼저 복사
5. `.dockerignore` — .git, tests, docs, .env, __pycache__, *.md 제외
