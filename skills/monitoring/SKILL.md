---
name: monitoring
description: |
  Datadog 기반 모니터링, APM, 로깅, 캐싱, 스케줄링 패턴 레퍼런스.
  Use when: Datadog 설정, APM 트레이싱, ddtrace 설정, 트레이스 연결,
  로그 설정, structlog 설정, JSON 로그, 로그 포맷, Datadog 로그 수집,
  헬스체크 엔드포인트, /health 만들기, 상태 확인 API,
  커스텀 메트릭, DogStatsD, 요청 추적, request ID, X-Request-ID,
  요청 로깅 미들웨어, 응답 시간 측정, RequestLoggingMiddleware,
  캐시 설정, 캐시 전략, cashews 캐시, redis 캐시, 캐시 무효화, TTL 설정,
  스케줄링, 정기 작업, 크론잡, APScheduler, BackgroundTasks, Celery 워커.
  NOT for: Prometheus 설정, Grafana 대시보드, 일반 Redis 사용법.
---

# 모니터링 스킬 (Datadog)

## Datadog APM (ddtrace)

### 설치 및 기본 설정
```bash
poetry add ddtrace
```

```python
# app/main.py
from ddtrace import patch_all, tracer

patch_all()
tracer.configure(
    hostname="localhost",      # DD Agent 호스트 (컨테이너: datadog-agent)
    port=8126,                 # DD Agent APM 포트
)

app = FastAPI()
```

### 자동 계측
`ddtrace-run`으로 실행하면 FastAPI, SQLAlchemy, httpx, redis 등 자동 계측:
```bash
ddtrace-run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Docker Compose에 Datadog Agent 추가
```yaml
services:
  datadog-agent:
    image: gcr.io/datadoghq/agent:7
    environment:
      DD_API_KEY: ${DD_API_KEY}
      DD_SITE: "datadoghq.com"        # 또는 ap1.datadoghq.com (Asia)
      DD_APM_ENABLED: "true"
      DD_APM_NON_LOCAL_TRAFFIC: "true"
      DD_LOGS_ENABLED: "true"
      DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL: "true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    ports:
      - "8126:8126"   # APM
      - "8125:8125"   # DogStatsD

  app:
    build: .
    command: ddtrace-run uvicorn app.main:app --host 0.0.0.0 --port 8000
    environment:
      DD_SERVICE: "my-api"
      DD_ENV: ${DD_ENV:-local}
      DD_VERSION: ${APP_VERSION:-0.1.0}
      DD_TRACE_AGENT_HOSTNAME: "datadog-agent"
      DD_LOGS_INJECTION: "true"       # 로그에 trace_id 자동 주입
    labels:
      com.datadoghq.ad.logs: '[{"source": "python", "service": "my-api"}]'
    depends_on:
      - datadog-agent
```

### 커스텀 스팬
```python
from ddtrace import tracer

@tracer.wrap(service="my-api", resource="process_order")
async def process_order(order_id: int) -> OrderEntity:
    ...

async def complex_operation():
    with tracer.trace("custom.operation", service="my-api") as span:
        span.set_tag("order_id", order_id)
        span.set_tag("user_id", user_id)
        result = await do_work()
        span.set_metric("items_count", len(result.items))
        return result
```

## 구조화 로깅 (structlog + Datadog)

### Datadog 연동 설정
```python
import structlog
from ddtrace import tracer

def add_datadog_trace_context(logger, method_name, event_dict):
    """structlog에 Datadog trace/span ID 자동 주입"""
    span = tracer.current_span()
    if span:
        event_dict["dd.trace_id"] = str(span.trace_id)
        event_dict["dd.span_id"] = str(span.span_id)
        event_dict["dd.service"] = span.service
        event_dict["dd.env"] = tracer.config.env or ""
        event_dict["dd.version"] = tracer.config.version or ""
    return event_dict

def setup_logging(debug: bool = False):
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.UnicodeDecoder(),
        add_datadog_trace_context,
    ]

    if debug:
        renderer = structlog.dev.ConsoleRenderer(colors=True)
    else:
        renderer = structlog.processors.JSONRenderer()

    structlog.configure(
        processors=[*shared_processors, renderer],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
    )
```

### 사용 예시
```python
logger = structlog.get_logger()

logger.info("user_created", user_id=42, email="user@example.com")
# JSON 출력 (Datadog에서 자동 파싱):
# {"event": "user_created", "user_id": 42, "dd.trace_id": "123...", "dd.span_id": "456...", ...}
```

## 커스텀 메트릭 (DogStatsD)

```python
from datadog import DogStatsd

statsd = DogStatsd(host="datadog-agent", port=8125)

statsd.increment("api.request.count", tags=["endpoint:/users", "method:GET"])
statsd.histogram("api.response_time", elapsed_ms, tags=["endpoint:/users"])
statsd.gauge("db.connection_pool.active", pool.checkedin(), tags=["db:primary"])
statsd.set("api.unique_users", user_id, tags=["env:production"])
```

## 요청 로깅 미들웨어

```python
class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
        start = time.perf_counter()
        structlog.contextvars.bind_contextvars(
            request_id=request_id, method=request.method, path=request.url.path)

        span = tracer.current_span()
        if span:
            span.set_tag("http.request_id", request_id)

        response = await call_next(request)
        elapsed = time.perf_counter() - start

        logger.info("request_completed", status_code=response.status_code,
                     elapsed_ms=round(elapsed * 1000, 2))

        statsd.histogram("http.request.duration", elapsed * 1000,
                         tags=[f"path:{request.url.path}", f"status:{response.status_code}"])

        response.headers["X-Request-ID"] = request_id
        response.headers["X-Process-Time"] = f"{elapsed:.4f}"
        return response
```

## 헬스 체크

```python
@router.get("/health")
async def health_check(db: AsyncSession = Depends(get_db)):
    components = {}
    try:
        await db.execute(text("SELECT 1"))
        components["database"] = {"status": "up"}
    except Exception as e:
        components["database"] = {"status": "down", "error": str(e)}
    try:
        r = aioredis.from_url(settings.redis.url)
        await r.ping()
        components["redis"] = {"status": "up"}
    except Exception as e:
        components["redis"] = {"status": "down", "error": str(e)}

    overall = "up" if all(c["status"] == "up" for c in components.values()) else "degraded"

    statsd.service_check("api.health", 0 if overall == "up" else 2,
                         tags=[f"component:{k}" for k in components])

    return {"status": overall, "version": settings.app_version, "components": components}
```

## 스케줄링

상세 패턴은 `/background-tasks` 참조. Celery task는 ddtrace가 자동 계측.

| 도구 | 용도 | 선택 기준 |
|------|------|----------|
| BackgroundTasks | 일회성 경량 작업 | 이메일, 로깅 |
| APScheduler | 주기적 작업 | 크론잡 |
| Celery | 무거운 분산 작업 | 리포트, ETL |

## 캐싱

```python
# Declarative (cashews)
@cache(ttl="10m", key="user:{user_id}")
async def get_by_id(self, user_id: int) -> dict: ...

@cache.invalidate("user:{user_id}")
@cache.invalidate("users:list:*")
async def update(self, user_id: int, data) -> UserEntity: ...

# Manual (redis.asyncio)
class CacheService:
    async def get(self, key: str) -> dict | None: ...
    async def set(self, key: str, value: dict, ttl: int = 300) -> None: ...
    async def delete_pattern(self, pattern: str) -> None: ...
```
