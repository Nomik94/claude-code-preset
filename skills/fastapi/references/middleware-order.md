# 미들웨어 LIFO 순서 상세

## 실행 순서 원리

`app.add_middleware()`는 REVERSE order(LIFO)로 실행. 마지막 등록이 가장 먼저 실행.

## MUST 등록 순서 (위에서 아래로 등록)

| 등록 순서 | 미들웨어 | 실행 순서 | 역할 |
|-----------|---------|-----------|------|
| 1 (첫 등록) | RequestLoggingMiddleware | 3 (innermost) | 정확한 타이밍 측정 |
| 2 | RateLimitMiddleware | 2 | CORS 통과 후 제한 |
| 3 (마지막 등록) | CORSMiddleware | 1 (outermost) | preflight 가장 먼저 처리 |

**요청 흐름:** Client -> CORS -> RateLimit -> RequestLogging -> Route -> (역순 응답)

## setup_middleware 전체 코드

```python
def setup_middleware(app: FastAPI, settings: Settings) -> None:
    # 등록: 안쪽 -> 바깥쪽 (실행은 역순)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(RateLimitMiddleware, max_requests=100, window_seconds=60)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )
```

## RequestLoggingMiddleware

MUST 포함 항목:
- X-Request-ID: 헤더에 있으면 재사용, 없으면 uuid4 생성
- structlog contextvars binding (request_id, method, path)
- 로그 필드: method, path, status_code, duration_ms, client_ip
- 응답 헤더에 X-Request-ID 포함
- `structlog.contextvars.clear_contextvars()` 호출로 이전 요청 컨텍스트 제거
- `time.perf_counter()`로 정밀 측정

```python
import time
import uuid
from collections.abc import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = structlog.get_logger()


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        structlog.contextvars.clear_contextvars()

        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            method=request.method,
            path=request.url.path,
        )

        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000

        await logger.ainfo(
            "request_completed",
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2),
            client_ip=request.client.host if request.client else "unknown",
        )

        response.headers["X-Request-ID"] = request_id
        return response
```

## Rate Limiting

| 환경 | 구현 | 비고 |
|------|------|------|
| dev/local | In-memory (dict + sliding window) | 단일 프로세스용 |
| production | Redis (INCR + EXPIRE) | 멀티 인스턴스 대응 |

- MUST: IP 기반 제한 (`request.client.host`)
- MUST: 429 응답 시 `Retry-After` 헤더 포함

```python
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_requests: int = 100, window_seconds: int = 60) -> None:
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._store: dict[str, list[float]] = {}

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()

        # Sliding window
        timestamps = self._store.get(client_ip, [])
        timestamps = [t for t in timestamps if now - t < self.window_seconds]

        if len(timestamps) >= self.max_requests:
            retry_after = int(self.window_seconds - (now - timestamps[0]))
            return JSONResponse(
                status_code=429,
                content={"code": "RATE_LIMITED", "message": "Too many requests"},
                headers={"Retry-After": str(retry_after)},
            )

        timestamps.append(now)
        self._store[client_ip] = timestamps
        return await call_next(request)
```

## CORS 설정

- MUST: `allow_origins=["*"]` + `allow_credentials=True` 조합은 prod에서 **절대 금지**

| 환경 | allow_origins | allow_credentials |
|------|--------------|-------------------|
| local/dev | localhost 명시 목록 | True |
| staging | 스테이징 도메인 목록 | True |
| prod | 프로덕션 도메인 목록 | True |

## Sub-Application 미들웨어

- 공통 미들웨어(CORS, Logging)는 root app에 등록
- 인증 미들웨어는 sub-app 레벨에서 등록 (admin/app 각각 다른 인증)

## Cross-Cutting Decorators

비즈니스 로직의 횡단 관심사를 decorator로 분리.

```python
@log_execution      # 1. 최외곽: 전체 실행 로깅 (진입/종료/에러)
@retry              # 2. 중간: 재시도 (에러 시 반복)
@transactional      # 3. 최내곽: 트랜잭션 (commit/rollback)
async def create_order(self, command: CreateOrderCommand) -> Order:
    ...
```

| Decorator | 역할 | 위치 |
|-----------|------|------|
| `@log_execution` | 함수 진입/종료/에러 로깅, 실행 시간 측정 | 최외곽 |
| `@retry` | 일시적 에러 시 재시도 (max_attempts, backoff) | 중간 |
| `@transactional` | AsyncSession commit/rollback 관리 | 최내곽 |

- MUST: `@transactional`은 항상 가장 안쪽 (함수 바로 위)
- MUST: `functools.wraps` 사용 필수
