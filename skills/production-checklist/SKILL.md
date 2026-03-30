---
name: production-checklist
description: |
  프로덕션 배포 전 종합 체크리스트 및 모니터링 설정 가이드.
  Use when: 배포, 프로덕션, 출시, 런칭, go-live, 모니터링, 알림 설정, 대시보드.
  NOT for: CI/CD 파이프라인 구성 (→ /cicd), Docker 빌드 (→ /docker).
files:
  - references/monitoring-setup.md
  - references/alerting-policy.md
---

# Production Checklist

## BE 체크리스트

### 환경 설정
- [ ] `pydantic-settings` BaseSettings로 환경변수 검증
- [ ] `.env.example` 최신 상태
- [ ] 시크릿: 환경변수 또는 Vault (하드코딩 없음)
- [ ] `APP_ENV=production`

### 데이터베이스
- [ ] `alembic upgrade head` + 롤백 테스트
- [ ] 인덱스 최적화
- [ ] 커넥션 풀 설정 (`pool_size`, `max_overflow`)

### Health Check
- [ ] `/health` (200 OK), `/ready` (DB/Redis 의존성 확인)

### 로깅
- [ ] structlog JSON 포맷, 요청 ID 포함, 민감 정보 마스킹, 레벨 INFO

### 에러 트래킹
- [ ] Sentry 연동 + DSN + 릴리스 태깅

### 보안
- [ ] Rate Limiting 활성화
- [ ] CORS 도메인 명시 (`*` 금지)

> 보안 상세 → `/security-audit`

### 성능
- [ ] GZipMiddleware, 캐시 전략 (Redis/HTTP), N+1 방지

### 백업
- [ ] DB 자동 백업 + 복구 테스트 완료

## FE 체크리스트

### Core Web Vitals
- [ ] LCP < 2.5초, FID < 100ms, CLS < 0.1, Lighthouse >= 90

### SEO
- [ ] `<title>`, `<meta description>`, OG 태그, robots.txt, sitemap.xml

### 에러 처리
- [ ] Error Boundary (전역 + 페이지별), 404/500 커스텀 페이지

### 빌드 최적화
- [ ] Bundle Analyzer, Dynamic Import, 불필요 의존성 제거

## 공통 체크리스트

### 인프라
- [ ] SSL/TLS + 자동 갱신, CDN, DNS 확인

### 알림
- [ ] 에러율 (5xx > 1%), 응답시간 (p95 > 1초), 리소스 (CPU > 80%, Mem > 85%)
- [ ] 채널: Slack/Discord/PagerDuty

### 롤백
- [ ] 롤백 절차 문서화 + 테스트, Blue-Green/Canary 전략 결정

### 부하 테스트
- [ ] 예상 트래픽 2배 처리 확인

## 모니터링

### 3 Pillars of Observability

| 축 | 도구 | 핵심 |
|----|------|------|
| Metrics | Prometheus/Datadog | RED (Rate, Errors, Duration) |
| Logging | structlog → CloudWatch/ELK | JSON, 레벨, 마스킹 |
| Tracing | OpenTelemetry → Jaeger/Datadog APM | FastAPI/SQLAlchemy/Redis 자동 계측 |

> 설정 코드 → references/monitoring-setup.md

### 알림 정책

| 단계 | 조건 | 채널 |
|------|------|------|
| P1 Critical | 서비스 다운, 데이터 손실 | PagerDuty + 전화 |
| P2 High | 에러율 > 5%, 지연 > 3초 | Slack + PagerDuty |
| P3 Medium | 에러율 > 1%, 지연 > 1초 | Slack |
| P4 Low | 경고성 지표 | Slack (업무 시간) |

> 알림 규칙 YAML → references/alerting-policy.md

## 최종 확인

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
```

모든 항목 통과 후 배포 진행.
