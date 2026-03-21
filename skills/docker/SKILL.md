---
name: docker
description: |
  Docker 컨테이너화 및 docker-compose 구성.
  Use when: Dockerfile 작성, docker-compose 구성, 컨테이너 최적화, nginx 설정, 이미지 빌드.
  NOT for: CI/CD 파이프라인 (→ /cicd), 프로덕션 배포 체크리스트 (→ /production-checklist).
---

# Docker

풀스택 프로젝트(BE + FE)의 컨테이너화 가이드.

## Stack Detection

프로젝트 파일로 Dockerfile 템플릿 자동 결정:
- `pyproject.toml` → BE Dockerfile 생성
- `package.json` → FE Dockerfile 생성
- 둘 다 → 멀티 서비스 docker-compose 구성

## BE Dockerfile (Python/FastAPI)

Multi-stage 빌드로 이미지 최소화.

```dockerfile
# ---- builder ----
FROM python:3.13-slim AS builder

RUN pip install poetry==1.8.* && \
    poetry config virtualenvs.in-project true

WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main --no-root --no-interaction

COPY . .
RUN poetry install --only main --no-interaction

# ---- runtime ----
FROM python:3.13-slim AS runtime

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app

WORKDIR /app
COPY --from=builder /app/.venv .venv
COPY --from=builder /app .

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### BE 핵심 원칙
- **Poetry 설치**: builder 스테이지에서만 (runtime에 불필요)
- **non-root 사용자**: `app` 사용자로 실행
- **HEALTHCHECK**: `/health` 엔드포인트 기반
- **slim 이미지**: alpine 대신 slim (glibc 호환성)
- **COPY 순서**: `pyproject.toml` → `poetry.lock` → 소스코드 (캐시 최적화)

## FE Dockerfile (Next.js)

3-stage 빌드로 standalone output 활용.

```dockerfile
# ---- deps ----
FROM node:20-alpine AS deps
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# ---- build ----
FROM node:20-alpine AS build

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

# ---- runner ----
FROM node:20-alpine AS runner

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=build /app/public ./public
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static

USER app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/api/health"]

EXPOSE 3000
CMD ["node", "server.js"]
```

### FE 핵심 원칙
- **standalone output**: `next.config.js`에 `output: 'standalone'` 필수
- **static assets**: `.next/static`과 `public/` 별도 복사
- **alpine 사용**: Node.js는 glibc 의존성 적음
- **pnpm**: `corepack enable`로 설치, `--frozen-lockfile` 필수
- **non-root 사용자**: `app` 사용자로 실행

## docker-compose.yml

### 멀티 서비스 구성

```yaml
services:
  app:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "${APP_PORT:-8000}:8000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - backend
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "${FE_PORT:-3000}:3000"
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8000}
    depends_on:
      - app
    networks:
      - frontend
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/var/lib/redis/data
    command: redis-server --requirepass ${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend
    restart: unless-stopped

  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/conf:/etc/letsencrypt:ro
    depends_on:
      - app
      - frontend
    networks:
      - frontend
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

### 네트워크 분리
- **frontend**: nginx ↔ frontend (외부 접근)
- **backend**: app ↔ db ↔ redis (내부 통신)
- nginx는 양쪽 네트워크 연결 (리버스 프록시)

### 환경별 Override

**docker-compose.dev.yml** (개발):
```yaml
services:
  app:
    build:
      target: builder
    volumes:
      - ./backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    environment:
      - APP_ENV=development

  frontend:
    volumes:
      - ./frontend:/app
      - /app/node_modules
    command: pnpm dev
    environment:
      - NODE_ENV=development

  db:
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"
```

**docker-compose.prod.yml** (프로덕션):
```yaml
services:
  app:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  frontend:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
```

실행 방법:
```bash
# 개발
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# 프로덕션
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## nginx 설정

### 리버스 프록시 + FE→BE 라우팅

```nginx
upstream backend {
    server app:8000;
}

upstream frontend {
    server frontend:3000;
}

server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1000;

    # API → Backend
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 나머지 → Frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 정적 파일 캐시
    location /_next/static/ {
        proxy_pass http://frontend;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }
}
```

## .dockerignore

### BE (.dockerignore)
```
__pycache__
*.pyc
.venv
.env
.git
.mypy_cache
.ruff_cache
.pytest_cache
tests/
docs/
*.md
.github/
```

### FE (.dockerignore)
```
node_modules
.next
.env*.local
.git
coverage/
tests/
*.md
.github/
```

## 보안

### 최소 이미지
- BE: `python:3.13-slim` (alpine은 glibc 호환 이슈)
- FE: `node:20-alpine` (가벼움 우선)
- DB: `postgres:16-alpine`

### 시크릿 관리
- **Build-time**: `ARG`로 전달, 최종 이미지에 포함 안 됨 확인
- **Runtime**: `.env` 또는 Docker secrets 사용
- `.env` 파일 절대 이미지에 포함 금지 (`.dockerignore`에 명시)

### 취약점 스캔
```bash
# Trivy로 이미지 스캔
trivy image myapp:latest --severity HIGH,CRITICAL

# CI에서 자동 실행
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

## 최적화

### 레이어 캐시 전략
1. 시스템 의존성 설치 (변경 빈도 낮음)
2. 패키지 매니저 파일 복사 (`pyproject.toml`, `package.json`)
3. 의존성 설치
4. 소스코드 복사 (변경 빈도 높음)

### BuildKit 활용
```bash
# BuildKit 활성화
DOCKER_BUILDKIT=1 docker build .

# 캐시 마운트 (의존성 설치 가속)
RUN --mount=type=cache,target=/root/.cache/pip poetry install
RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm install
```

### 이미지 크기 확인
```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
docker history myapp:latest
```
