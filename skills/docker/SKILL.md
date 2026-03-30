---
name: docker
description: |
  Docker 컨테이너화 및 docker-compose 구성.
  Use when: Dockerfile 작성, docker-compose 구성, 컨테이너 최적화, nginx 설정, 이미지 빌드.
  NOT for: CI/CD 파이프라인 (→ /cicd), 프로덕션 배포 체크리스트 (→ /production-checklist).
---

# Docker

## Dockerfile 템플릿

상세 코드 → `templates/` 참조:
- **`templates/Dockerfile.be`** — Python/FastAPI multi-stage (builder→runtime)
- **`templates/Dockerfile.fe`** — Next.js 3-stage (deps→build→runner)
- **`templates/docker-compose.yml`** — 멀티 서비스 (app, frontend, db, redis, nginx)

### BE 핵심
- Poetry: builder 스테이지에서만
- non-root `app` 사용자 실행
- HEALTHCHECK: `/health` 기반
- slim 이미지 (alpine 대신, glibc 호환)
- COPY 순서: `pyproject.toml`→`poetry.lock`→소스 (캐시 최적화)

### FE 핵심
- `output: 'standalone'` 필수
- `.next/static`과 `public/` 별도 복사
- alpine 사용, `corepack enable` + `--frozen-lockfile`
- non-root `app` 사용자 실행

## docker-compose

### 네트워크 분리
- **frontend**: nginx ↔ frontend (외부)
- **backend**: app ↔ db ↔ redis (내부)
- nginx: 양쪽 연결 (리버스 프록시)

### 환경별 Override → `references/compose-patterns.md`
### nginx 설정 → `references/nginx-config.md`

## .dockerignore

### BE
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

### FE
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

### 이미지 선택
- BE: `python:3.13-slim`, FE: `node:20-alpine`, DB: `postgres:16-alpine`

### 시크릿
- Build-time: `ARG` (최종 이미지 미포함 확인)
- Runtime: `.env` 또는 Docker secrets
- `.env` 이미지 포함 금지 (`.dockerignore`)

### 취약점 스캔
```bash
trivy image myapp:latest --severity HIGH,CRITICAL
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

## 최적화

### 레이어 캐시
1. 시스템 의존성 (변경 빈도 낮음)
2. 패키지 매니저 파일 복사
3. 의존성 설치
4. 소스코드 복사 (변경 빈도 높음)

### BuildKit
```bash
DOCKER_BUILDKIT=1 docker build .
RUN --mount=type=cache,target=/root/.cache/pip poetry install
RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm install
```

### 크기 확인
```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
docker history myapp:latest
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
