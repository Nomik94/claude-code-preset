---
name: middleware
description: |
  FastAPI 미들웨어 패턴 레퍼런스.
  Use when: 미들웨어 추가, CORS 설정, 인증 미들웨어, 요청 로깅,
  rate limiting, 요청/응답 가공, middleware 순서, 미들웨어 만들기,
  BaseHTTPMiddleware, 요청 시간 측정, request_id 주입.
  NOT for: 라우터 레벨 의존성 (Depends 사용).
---

# FastAPI 미들웨어 패턴

## 1. CORS 설정

```python
from fastapi.middleware.cors import CORSMiddleware

ALLOWED_ORIGINS_DEV = ["http://localhost:3000", "http://localhost:5173"]
ALLOWED_ORIGINS_PROD = ["https://app.example.com"]

def add_cors(app: FastAPI, *, env: str = "local") -> None:
    origins = ALLOWED_ORIGINS_PROD if env == "prod" else ALLOWED_ORIGINS_DEV
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )
```

## 2. Request ID 미들웨어

```python
import uuid
import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
```

## 3. 인증 미들웨어 (서브 애플리케이션 레벨)

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

SKIP_PATHS = {"/health", "/docs", "/openapi.json"}

class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in SKIP_PATHS:
            return await call_next(request)
        token = request.headers.get("Authorization", "").removeprefix("Bearer ")
        if not token:
            return JSONResponse({"detail": "Missing token"}, status_code=401)
        try:
            payload = decode_access_token(token)  # project-specific
            request.state.user_id = payload["sub"]
        except Exception:
            return JSONResponse({"detail": "Invalid token"}, status_code=401)
        return await call_next(request)
```

## 4. 타이밍 미들웨어

```python
import time
import structlog

logger = structlog.get_logger()

class TimingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000
        response.headers["X-Process-Time-Ms"] = f"{duration_ms:.1f}"
        if duration_ms > 500:
            logger.warning("slow_request", path=request.url.path, duration_ms=duration_ms)
        return response
```

## 5. Rate Limiting (인메모리 / Redis)

```python
import time
from collections import defaultdict
from starlette.responses import JSONResponse

class InMemoryRateLimitMiddleware(BaseHTTPMiddleware):
    """Simple per-IP rate limiter. Use Redis version for multi-instance."""

    def __init__(self, app, *, max_requests: int = 60, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        window_start = now - self.window
        self._hits[client_ip] = [t for t in self._hits[client_ip] if t > window_start]
        if len(self._hits[client_ip]) >= self.max_requests:
            return JSONResponse({"detail": "Too many requests"}, status_code=429)
        self._hits[client_ip].append(now)
        return await call_next(request)
```

## 6. 미들웨어 등록 순서

등록 순서가 중요합니다: **마지막에 등록된 것이 가장 먼저 실행됩니다**.

```python
def setup_middleware(app: FastAPI, settings: Settings) -> None:
    # Register in REVERSE execution order.
    # Execution order: RequestID -> Timing -> RateLimit -> CORS -> Auth -> route
    app.add_middleware(AuthMiddleware)
    app.add_middleware(CORSMiddleware, allow_origins=["*"])
    app.add_middleware(InMemoryRateLimitMiddleware, max_requests=100)
    app.add_middleware(TimingMiddleware)
    app.add_middleware(RequestIDMiddleware)  # registered last = runs first
```

## 7. BaseHTTPMiddleware 커스텀 템플릿

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class MyCustomMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, some_option: str = "default"):
        super().__init__(app)
        self.some_option = some_option

    async def dispatch(self, request: Request, call_next) -> Response:
        # --- pre-processing ---
        response: Response = await call_next(request)
        # --- post-processing ---
        return response
```
