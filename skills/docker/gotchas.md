# Docker Gotchas

## 자주 발생하는 실수

### 1. root 사용자로 컨테이너 실행
❌ Dockerfile에 `USER` 지시어 없음 → 기본 root로 실행
→ ✅ `RUN adduser --system --no-create-home appuser` + `USER appuser` 명시

root로 실행되는 컨테이너가 탈취되면 호스트 시스템까지 위협받는다.

### 2. .dockerignore 없음
❌ `.dockerignore` 파일 없이 `COPY . .` → .git, node_modules, .env 등 전부 복사
→ ✅ `.dockerignore`에 `.git`, `node_modules`, `__pycache__`, `.env`, `*.pyc` 등록

불필요한 파일이 이미지에 포함되면 빌드 시간 증가 + 이미지 크기 증가 + 시크릿 노출 위험.

### 3. node_modules/가상환경을 COPY
❌ 로컬의 `node_modules` 또는 `.venv`를 그대로 컨테이너에 복사
→ ✅ `.dockerignore`에 추가하고 컨테이너 내에서 `npm install` / `poetry install` 실행

로컬 빌드 아티팩트는 OS/아키텍처가 다르면 동작하지 않는다.

### 4. 시크릿을 build arg로 전달
❌ `docker build --build-arg DB_PASSWORD=secret .` → 이미지 레이어에 시크릿 저장
→ ✅ `--secret` 플래그 사용 또는 런타임 환경 변수로 전달

build arg는 `docker history`로 누구나 볼 수 있다. 이미지에 시크릿이 영구 저장된다.

### 5. 멀티스테이지 빌드 미사용
❌ 빌드 도구(gcc, npm, poetry)가 최종 이미지에 포함 → 이미지 크기 1GB+
→ ✅ 멀티스테이지: builder에서 빌드, runner에서 결과물만 복사

```dockerfile
# ✅ 멀티스테이지
FROM python:3.13-slim AS builder
RUN poetry install --only=main
FROM python:3.13-slim AS runner
COPY --from=builder /app/.venv /app/.venv
```

### 6. 레이어 캐시 최적화 안 함
❌ `COPY . .` 후에 `RUN pip install` → 코드 한 줄 바꿔도 의존성 재설치
→ ✅ 의존성 파일 먼저 복사 → 설치 → 소스 코드 복사

```dockerfile
# ✅ 캐시 최적화
COPY pyproject.toml poetry.lock ./
RUN poetry install --only=main --no-root
COPY . .
```

### 7. HEALTHCHECK 미설정
❌ 컨테이너가 시작되었지만 애플리케이션이 정상 동작하는지 확인 불가
→ ✅ `HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1`

orchestrator(Docker Compose, K8s)가 unhealthy 컨테이너를 감지하고 재시작할 수 있어야 한다.
