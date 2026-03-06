---
name: middleware
description: |
  FastAPI 미들웨어 및 cross-cutting decorator 패턴 레퍼런스.
  Use when: 미들웨어 추가/순서 설정, CORS 설정, 요청 로깅, rate limiting,
  X-Request-ID 주입, 요청 시간 측정, @transactional/@retry/@log_execution
  decorator 적용, sub-application별 미들웨어 분리.
  NOT for: 라우터 레벨 의존성 (Depends 사용), 예외 핸들러 등록.
---

# FastAPI 미들웨어 및 Cross-Cutting Decorators

## 1. 미들웨어 실행 순서 (LIFO)

`app.add_middleware()`는 REVERSE order(LIFO)로 실행된다.
마지막에 등록된 미들웨어가 가장 먼저 실행된다.

**MUST 등록 순서 (위에서 아래로 등록):**

| 등록 순서 | 미들웨어 | 실행 순서 | 역할 |
|-----------|---------|-----------|------|
| 1 (첫 등록) | RequestLoggingMiddleware | 3 (innermost) | 정확한 타이밍 측정 |
| 2 | RateLimitMiddleware | 2 | CORS 통과 후 제한 |
| 3 (마지막 등록) | CORSMiddleware | 1 (outermost) | preflight 가장 먼저 처리 |

```python
def setup_middleware(app: FastAPI, settings: Settings) -> None:
    # 등록: 안쪽 → 바깥쪽 (실행은 역순)
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

**요청 흐름:** Client -> CORS -> RateLimit -> RequestLogging -> Route -> (역순 응답)

## 2. RequestLoggingMiddleware

X-Request-ID 생성 + 요청 로깅 + 응답 시간 측정을 하나의 미들웨어로 통합한다.

**MUST 포함 항목:**
- X-Request-ID: 헤더에 있으면 재사용, 없으면 uuid4 생성
- structlog contextvars binding (request_id, method, path)
- 로그 필드: method, path, status_code, duration_ms, client_ip
- 응답 헤더에 X-Request-ID 포함

**MUST 구현 패턴:**
- `structlog.contextvars.clear_contextvars()` 호출로 이전 요청 컨텍스트 제거
- `time.perf_counter()`로 정밀 측정
- innermost 위치에서 실행하여 순수 처리 시간만 측정

## 3. Rate Limiting

| 환경 | 구현 | 비고 |
|------|------|------|
| dev/local | In-memory (dict + sliding window) | 단일 프로세스용 |
| production | Redis (INCR + EXPIRE) | 멀티 인스턴스 대응 |

**MUST 규칙:**
- IP 기반 제한 (`request.client.host`)
- 429 응답 시 `Retry-After` 헤더 포함
- `request.client`가 None인 경우 fallback 처리

## 4. CORS 설정

**MUST 규칙:**
- `allow_origins=["*"]` + `allow_credentials=True` 조합은 prod에서 **절대 금지**
- 환경별 origins 분리 (settings에서 관리)
- `expose_headers`에 커스텀 헤더(X-Request-ID 등) 명시

| 환경 | allow_origins | allow_credentials |
|------|--------------|-------------------|
| local/dev | localhost 명시 목록 | True |
| staging | 스테이징 도메인 목록 | True |
| prod | 프로덕션 도메인 목록 | True |

## 5. Cross-Cutting Decorators

비즈니스 로직의 횡단 관심사를 decorator로 분리한다.

### 5.1 Decorator 순서 (위에서 아래로 적용)

```python
@log_execution      # 1. 전체 실행 로깅 (진입/종료/에러)
@retry              # 2. 재시도 (에러 시 반복)
@transactional      # 3. 트랜잭션 (commit/rollback)
async def create_order(self, command: CreateOrderCommand) -> Order:
    ...
```

**실행 흐름:** log_execution -> retry -> transactional -> 함수 본체

### 5.2 각 Decorator 역할

| Decorator | 역할 | 위치 |
|-----------|------|------|
| `@log_execution` | 함수 진입/종료/에러 로깅, 실행 시간 측정 | 최외곽 (가장 먼저) |
| `@retry` | 일시적 에러 시 재시도 (max_attempts, backoff) | 중간 |
| `@transactional` | AsyncSession commit/rollback 관리 | 최내곽 (함수 직전) |

**MUST 규칙:**
- `@transactional`은 항상 가장 안쪽 (함수 바로 위)
- `@log_execution`은 항상 가장 바깥쪽 (전체 시간 포착)
- `@retry` 안에 `@transactional`이 있어야 재시도마다 새 트랜잭션
- Decorator는 `functools.wraps` 사용 필수

## 6. Sub-Application 미들웨어

각 sub-app(admin/app/web)은 독립적인 미들웨어 스택을 가질 수 있다.

**MUST 규칙:**
- 공통 미들웨어(CORS, Logging)는 root app에 등록
- 인증 미들웨어는 sub-app 레벨에서 등록 (admin/app 각각 다른 인증)
- sub-app 미들웨어도 LIFO 순서 동일하게 적용

```python
# root app: 공통 미들웨어
setup_middleware(root_app, settings)

# sub-app: 개별 미들웨어
admin_app.add_middleware(AdminAuthMiddleware)
client_app.add_middleware(JWTAuthMiddleware)
```

## 7. BaseHTTPMiddleware 작성 규칙

**MUST 규칙:**
- `__init__`에서 `super().__init__(app)` 호출
- `dispatch` 메서드는 `Request`와 `call_next`를 인자로 받음
- 설정값은 `__init__`의 keyword-only 파라미터로 주입
- 예외 발생 시에도 응답을 반환하도록 try/except 처리
- health check 등 skip 대상 경로는 상수로 관리

## Verification Checklist

- [ ] 미들웨어 등록 순서가 LIFO 규칙을 따르는가 (CORS 마지막 등록)
- [ ] RequestLoggingMiddleware가 innermost에 위치하는가
- [ ] X-Request-ID가 생성/전파되고 응답 헤더에 포함되는가
- [ ] structlog contextvars가 요청마다 clear 되는가
- [ ] CORS에서 `allow_origins=["*"]` + `allow_credentials=True` 조합이 없는가
- [ ] Rate limiter가 prod에서 Redis 기반인가
- [ ] Decorator 순서: @log_execution -> @retry -> @transactional 인가
- [ ] Sub-app 미들웨어가 root app과 분리되어 있는가
- [ ] `functools.wraps`가 모든 decorator에 적용되었는가
