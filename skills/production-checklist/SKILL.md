---
name: production-checklist
description: |
  프로덕션 배포 전 종합 체크리스트 및 모니터링 설정 가이드.
  Use when: 배포, 프로덕션, 출시, 런칭, go-live, 모니터링, 알림 설정, 대시보드.
  NOT for: CI/CD 파이프라인 구성 (→ /cicd), Docker 빌드 (→ /docker).
---

# Production Checklist

풀스택 프로젝트(BE + FE)의 프로덕션 배포 전 종합 체크리스트.

## Stack Detection

프로젝트 파일로 체크리스트 자동 결정:
- `pyproject.toml` → BE 체크리스트 활성
- `package.json` → FE 체크리스트 활성
- 둘 다 → 전체 활성

## 사용법

배포 전 아래 체크리스트를 순서대로 검증. 모든 항목 통과 후에만 배포 진행.

---

## BE 체크리스트

### 환경 설정
- [ ] 환경 변수 설정 완료 (`pydantic-settings` BaseSettings로 검증)
- [ ] `.env.example` 최신 상태 (모든 필수 변수 포함)
- [ ] 시크릿 관리: 환경변수 또는 Vault 사용 (하드코딩 없음)
- [ ] `APP_ENV=production` 설정

### 데이터베이스
- [ ] DB 마이그레이션 적용 (`alembic upgrade head`)
- [ ] 마이그레이션 롤백 테스트 (`alembic downgrade -1` → `upgrade head`)
- [ ] 인덱스 최적화 확인 (슬로우 쿼리 없음)
- [ ] 커넥션 풀 설정 (`pool_size`, `max_overflow`)

### Health Check
- [ ] `/health` 엔드포인트: 앱 기본 상태 확인 (200 OK)
- [ ] `/ready` 엔드포인트: DB, Redis 등 의존성 연결 확인

```python
@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}

@router.get("/ready")
async def readiness(
    db: AsyncSession = Depends(get_session),
    redis: Redis = Depends(get_redis),
) -> dict[str, str]:
    await db.execute(text("SELECT 1"))
    await redis.ping()
    return {"status": "ready"}
```

### 로깅
- [ ] structlog JSON 포맷 설정 (프로덕션)
- [ ] 요청 ID (correlation ID) 포함
- [ ] 민감 정보 마스킹 (비밀번호, 토큰)
- [ ] 로그 레벨: INFO (DEBUG 비활성화)

### 에러 트래킹
- [ ] Sentry 연동 (`sentry-sdk[fastapi]`)
- [ ] DSN 환경변수 설정 (`SENTRY_DSN`)
- [ ] 릴리스 버전 태깅 (`release=version`)
- [ ] 민감 정보 필터링 (`before_send` 훅)

### APM (Application Performance Monitoring)
- [ ] Datadog 또는 New Relic 에이전트 설치
- [ ] 트레이스 수집 활성화
- [ ] 커스텀 메트릭 정의 (비즈니스 KPI)

### 보안
- [ ] Rate Limiting 활성화 (slowapi 또는 미들웨어)
- [ ] CORS 설정 확인 (허용 도메인 명시, `*` 금지)
- [ ] HTTPS 강제 (HTTP → HTTPS 리다이렉트)
- [ ] 보안 헤더 설정 (HSTS, X-Content-Type-Options, X-Frame-Options)
- [ ] JWT 만료 시간 적정 (access: 15-30분, refresh: 7-30일)
- [ ] SQL Injection 방지 (ORM 사용, raw query 최소화)

### 성능
- [ ] 응답 압축 (GZipMiddleware)
- [ ] 캐시 전략 설정 (Redis, HTTP Cache-Control)
- [ ] 비동기 작업 분리 (BackgroundTasks, Celery/ARQ)
- [ ] DB 쿼리 N+1 방지 (`lazy="raise"`, `selectinload` 사용)

### 백업/복구
- [ ] DB 자동 백업 설정 (일간)
- [ ] 백업 복구 테스트 완료
- [ ] 재해 복구 절차 문서화 (RTO, RPO 정의)

---

## FE 체크리스트

### Core Web Vitals
- [ ] LCP (Largest Contentful Paint) < 2.5초
- [ ] FID (First Input Delay) < 100ms
- [ ] CLS (Cumulative Layout Shift) < 0.1
- [ ] Lighthouse Performance 점수 >= 90

측정 방법:
```bash
# Lighthouse CLI
npx lighthouse https://example.com --output=json --chrome-flags="--headless"

# Web Vitals 라이브러리
# src/lib/web-vitals.ts에서 reportWebVitals 설정
```

### SEO
- [ ] `<title>` 태그: 각 페이지 고유 제목
- [ ] `<meta name="description">`: 각 페이지 고유 설명
- [ ] Open Graph 태그 (`og:title`, `og:description`, `og:image`)
- [ ] Twitter Card 태그 (`twitter:card`, `twitter:title`)
- [ ] `robots.txt` 설정
- [ ] `sitemap.xml` 생성 (next-sitemap 등)
- [ ] Canonical URL 설정
- [ ] 구조화 데이터 (JSON-LD)

### 에러 처리
- [ ] Error Boundary 설정 (전역 + 페이지별)
- [ ] 404 페이지 커스텀
- [ ] 500 페이지 커스텀 (오프라인 대응)
- [ ] API 에러 공통 처리 (toast/notification)

### 에러 트래킹 (클라이언트)
- [ ] Sentry Browser SDK 연동
- [ ] Source Map 업로드 (빌드 시)
- [ ] 유저 컨텍스트 설정 (익명 ID)
- [ ] 에러 샘플링 설정 (`tracesSampleRate`)

### Analytics
- [ ] Google Analytics 4 또는 Plausible/Umami 연동
- [ ] 페이지뷰 추적
- [ ] 핵심 이벤트 추적 (회원가입, 결제 등)
- [ ] 쿠키 동의 배너 (필요 시)

### 이미지 최적화
- [ ] `next/image` 사용 (자동 최적화, lazy loading)
- [ ] WebP/AVIF 포맷 지원
- [ ] 이미지 크기 명시 (`width`, `height` → CLS 방지)
- [ ] 외부 이미지 도메인 설정 (`next.config.js` images.remotePatterns)

### 폰트 최적화
- [ ] `next/font` 사용 (자동 최적화, self-hosting)
- [ ] `font-display: swap` 설정
- [ ] 필요한 글리프만 subset

### 빌드 최적화
- [ ] Bundle Analyzer로 번들 크기 확인 (`@next/bundle-analyzer`)
- [ ] 불필요한 의존성 제거
- [ ] Dynamic Import 활용 (코드 스플리팅)
- [ ] Tree Shaking 확인

---

## 공통 체크리스트

### 인프라
- [ ] SSL/TLS 인증서 설정 (Let's Encrypt 또는 클라우드 매니지드)
- [ ] 인증서 자동 갱신 설정
- [ ] CDN 설정 (CloudFront, Cloudflare)
- [ ] DNS 설정 확인 (A/CNAME 레코드)
- [ ] 도메인 WHOIS 보호

### 로그 수집
- [ ] 중앙 집중식 로그 수집 (CloudWatch, Datadog Logs, ELK)
- [ ] 로그 보존 기간 설정 (30-90일)
- [ ] 로그 기반 알림 규칙

### 알림 설정
- [ ] 에러율 알림 (5xx > 1%)
- [ ] 응답시간 알림 (p95 > 1초)
- [ ] 서버 리소스 알림 (CPU > 80%, Memory > 85%)
- [ ] 디스크 사용량 알림 (> 85%)
- [ ] 알림 채널: Slack/Discord/PagerDuty

### 롤백
- [ ] 롤백 절차 문서화
- [ ] 롤백 테스트 완료
- [ ] Blue-Green 또는 Canary 배포 전략 결정
- [ ] 이전 버전 이미지/빌드 보관 (최소 3개)

### 부하 테스트
- [ ] 부하 테스트 완료 (k6, locust, Artillery)
- [ ] 예상 트래픽의 2배 처리 확인
- [ ] 병목 지점 파악 및 해결

---

## 모니터링

### 3 Pillars of Observability

프로덕션 시스템의 관측가능성은 3가지 축으로 구성.

#### 1. Metrics (지표)

수집 도구: **Prometheus** (self-hosted) 또는 **Datadog** (SaaS)

핵심 지표 (RED Method):
| 지표 | 설명 | 임계값 |
|------|------|--------|
| Rate | 초당 요청 수 (RPS) | 기준선 대비 +-50% |
| Errors | 에러율 (5xx / total) | < 1% |
| Duration | 응답 시간 (p50, p95, p99) | p95 < 500ms |

시스템 지표:
| 지표 | 임계값 | 알림 |
|------|--------|------|
| CPU 사용률 | > 80% (5분 지속) | Warning |
| Memory 사용률 | > 85% | Warning |
| Disk 사용률 | > 85% | Critical |
| DB 커넥션 풀 | > 80% 사용 | Warning |

FastAPI 메트릭 미들웨어 예시:
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
        # 경로, 메서드, 상태 코드별 분류
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

#### 2. Logging (로깅)

수집 도구: **structlog** (앱) → **CloudWatch/Datadog Logs/ELK** (집계)

structlog 프로덕션 설정:
```python
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

로그 레벨 가이드:
| 레벨 | 용도 | 예시 |
|------|------|------|
| ERROR | 즉시 조치 필요 | DB 연결 실패, 결제 실패 |
| WARNING | 잠재적 문제 | 재시도 성공, 캐시 미스 |
| INFO | 비즈니스 이벤트 | 사용자 로그인, 주문 생성 |
| DEBUG | 개발용 (프로덕션 비활성화) | 쿼리 파라미터, 중간 상태 |

#### 3. Tracing (분산 추적)

수집 도구: **OpenTelemetry** → **Jaeger/Datadog APM**

OpenTelemetry 설정:
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

### 대시보드 구성

#### 필수 대시보드 패널

**Overview 대시보드**:
| 패널 | 내용 |
|------|------|
| RPS | 초당 요청 수 (시계열) |
| 에러율 | 5xx 비율 (시계열) |
| p95 레이턴시 | 95번째 백분위 응답시간 |
| 활성 사용자 | 현재 동시 접속 수 |

**Infrastructure 대시보드**:
| 패널 | 내용 |
|------|------|
| CPU/Memory | 서버별 리소스 사용률 |
| DB 커넥션 | 활성/유휴 커넥션 수 |
| Redis 메모리 | 메모리 사용량, hit/miss 비율 |
| 디스크 I/O | 읽기/쓰기 처리량 |

**Business 대시보드**:
| 패널 | 내용 |
|------|------|
| 회원가입 수 | 일간/주간 추이 |
| API 사용량 | 엔드포인트별 호출 수 |
| 에러 Top 10 | 빈도순 에러 목록 |

### 알림 정책

#### 에스컬레이션 정책

| 단계 | 조건 | 대상 | 채널 |
|------|------|------|------|
| P1 (Critical) | 서비스 다운, 데이터 손실 | 온콜 엔지니어 | PagerDuty + 전화 |
| P2 (High) | 에러율 > 5%, 지연 > 3초 | 팀 리드 | Slack + PagerDuty |
| P3 (Medium) | 에러율 > 1%, 지연 > 1초 | 팀 채널 | Slack |
| P4 (Low) | 경고성 지표 이상 | 팀 채널 | Slack (업무 시간) |

#### 알림 규칙 예시 (Datadog)
```yaml
# 에러율 알림
- name: "High Error Rate"
  type: metric alert
  query: "sum(last_5m):sum:http.request.count{status:5xx} / sum:http.request.count{*} > 0.01"
  message: |
    에러율이 1%를 초과했습니다.
    현재 에러율: {{value}}
    @slack-alerts @pagerduty-oncall
  thresholds:
    critical: 0.05
    warning: 0.01

# 응답시간 알림
- name: "High Latency"
  type: metric alert
  query: "avg(last_5m):avg:http.request.duration.p95{*} > 1"
  message: |
    p95 응답시간이 1초를 초과했습니다.
    현재 p95: {{value}}s
    @slack-alerts
  thresholds:
    critical: 3
    warning: 1
```

---

## 최종 확인

배포 전 마지막 점검:

```bash
# 1. 전체 테스트 통과
poetry run pytest --cov=app --cov-fail-under=80
pnpm test

# 2. 타입 체크 통과
poetry run mypy --strict app/
pnpm tsc --noEmit

# 3. 보안 스캔 통과
poetry run pip-audit
poetry run bandit -r app/

# 4. Docker 빌드 성공
docker compose -f docker-compose.yml -f docker-compose.prod.yml build

# 5. Health check 응답 확인
curl -f http://localhost:8000/health
curl -f http://localhost:3000/api/health
```

모든 항목 통과 확인 후 배포를 진행한다.
