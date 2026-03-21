---
name: docker
description: |
  Docker 컨테이너화 및 docker-compose 구성.
  Use when: Dockerfile 작성, docker-compose 구성, 컨테이너 최적화, nginx 설정, 이미지 빌드.
  NOT for: CI/CD 파이프라인 (→ /cicd), 프로덕션 배포 체크리스트 (→ /production-checklist).
---

# Docker

풀스택 프로젝트(BE + FE)의 컨테이너화 가이드.

> Stack Detection: CLAUDE.md 규칙에 따라 자동 결정됨.

## Dockerfile 템플릿

상세 코드는 `templates/` 참조:
- **`templates/Dockerfile.be`** — Python/FastAPI multi-stage 빌드 (builder → runtime)
- **`templates/Dockerfile.fe`** — Next.js 3-stage 빌드 (deps → build → runner)
- **`templates/docker-compose.yml`** — 멀티 서비스 구성 (app, frontend, db, redis, nginx)

### BE 핵심 원칙
- **Poetry 설치**: builder 스테이지에서만 (runtime에 불필요)
- **non-root 사용자**: `app` 사용자로 실행
- **HEALTHCHECK**: `/health` 엔드포인트 기반
- **slim 이미지**: alpine 대신 slim (glibc 호환성)
- **COPY 순서**: `pyproject.toml` → `poetry.lock` → 소스코드 (캐시 최적화)

### FE 핵심 원칙
- **standalone output**: `next.config.js`에 `output: 'standalone'` 필수
- **static assets**: `.next/static`과 `public/` 별도 복사
- **alpine 사용**: Node.js는 glibc 의존성 적음
- **pnpm**: `corepack enable`로 설치, `--frozen-lockfile` 필수
- **non-root 사용자**: `app` 사용자로 실행

## docker-compose 구성

### 네트워크 분리 원칙
- **frontend**: nginx ↔ frontend (외부 접근)
- **backend**: app ↔ db ↔ redis (내부 통신)
- nginx는 양쪽 네트워크 연결 (리버스 프록시)

### 환경별 Override
개발/프로덕션 override 패턴 → `references/compose-patterns.md` 참조

### nginx 설정
리버스 프록시 + SSL + WebSocket 설정 → `references/nginx-config.md` 참조

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

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
