# 모니터링 설정 상세

## 3 Pillars of Observability

프로덕션 시스템의 관측가능성은 3가지 축으로 구성.

---

## 1. Metrics (지표)

수집 도구: **Prometheus** (self-hosted) 또는 **Datadog** (SaaS)

### 핵심 지표 (RED Method)

| 지표 | 설명 | 임계값 |
|------|------|--------|
| Rate | 초당 요청 수 (RPS) | 기준선 대비 +-50% |
| Errors | 에러율 (5xx / total) | < 1% |
| Duration | 응답 시간 (p50, p95, p99) | p95 < 500ms |

### 시스템 지표

| 지표 | 임계값 | 알림 |
|------|--------|------|
| CPU 사용률 | > 80% (5분 지속) | Warning |
| Memory 사용률 | > 85% | Warning |
| Disk 사용률 | > 85% | Critical |
| DB 커넥션 풀 | > 80% 사용 | Warning |

### FastAPI 메트릭 미들웨어

```python
import time
from collections.abc import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class MetricsMiddleware(BaseHTTPMiddleware):
    """요청 메트릭 수집 미들웨어."""

    async def dispatch(
        self, request: Request, call_next: Callable,
    ) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - start

        # Prometheus 또는 Datadog에 메트릭 전송
        labels = {
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
        }
        # metrics_client.histogram("http.request.duration", duration, tags=labels)
        # metrics_client.increment("http.request.count", tags=labels)

        response.headers["X-Response-Time"] = f"{duration:.4f}"
        return response
```

---

## 2. Logging (로깅)

수집 도구: **structlog** (앱) -> **CloudWatch/Datadog Logs/ELK** (집계)

### structlog 프로덕션 설정

```python
import logging

import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),  # 프로덕션: JSON
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)
```

### 로그 레벨 가이드

| 레벨 | 용도 | 예시 |
|------|------|------|
| ERROR | 즉시 조치 필요 | DB 연결 실패, 결제 실패 |
| WARNING | 잠재적 문제 | 재시도 성공, 캐시 미스 |
| INFO | 비즈니스 이벤트 | 사용자 로그인, 주문 생성 |
| DEBUG | 개발용 (프로덕션 비활성화) | 쿼리 파라미터, 중간 상태 |

---

## 3. Tracing (분산 추적)

수집 도구: **OpenTelemetry** -> **Jaeger/Datadog APM**

### OpenTelemetry 설정

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# 트레이서 설정
provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter())
)
trace.set_tracer_provider(provider)

# 자동 계측
FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)
RedisInstrumentor().instrument()
```

---

## 대시보드 구성

### Overview 대시보드

| 패널 | 내용 |
|------|------|
| RPS | 초당 요청 수 (시계열) |
| 에러율 | 5xx 비율 (시계열) |
| p95 레이턴시 | 95번째 백분위 응답시간 |
| 활성 사용자 | 현재 동시 접속 수 |

### Infrastructure 대시보드

| 패널 | 내용 |
|------|------|
| CPU/Memory | 서버별 리소스 사용률 |
| DB 커넥션 | 활성/유휴 커넥션 수 |
| Redis 메모리 | 메모리 사용량, hit/miss 비율 |
| 디스크 I/O | 읽기/쓰기 처리량 |

### Business 대시보드

| 패널 | 내용 |
|------|------|
| 회원가입 수 | 일간/주간 추이 |
| API 사용량 | 엔드포인트별 호출 수 |
| 에러 Top 10 | 빈도순 에러 목록 |
