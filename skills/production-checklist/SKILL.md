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

풀스택 프로젝트(BE + FE)의 프로덕션 배포 전 종합 체크리스트.

> Stack Detection: CLAUDE.md 규칙에 따라 자동 결정됨.

---

## BE 체크리스트

### 환경 설정
- [ ] 환경 변수 설정 완료 (`pydantic-settings` BaseSettings로 검증)
- [ ] `.env.example` 최신 상태
- [ ] 시크릿 관리: 환경변수 또는 Vault (하드코딩 없음)
- [ ] `APP_ENV=production` 설정

### 데이터베이스
- [ ] DB 마이그레이션 적용 (`alembic upgrade head`)
- [ ] 마이그레이션 롤백 테스트
- [ ] 인덱스 최적화 확인
- [ ] 커넥션 풀 설정 (`pool_size`, `max_overflow`)

### Health Check
- [ ] `/health` 엔드포인트 (200 OK)
- [ ] `/ready` 엔드포인트 (DB, Redis 의존성 확인)

### 로깅
- [ ] structlog JSON 포맷 (프로덕션)
- [ ] 요청 ID (correlation ID) 포함
- [ ] 민감 정보 마스킹
- [ ] 로그 레벨: INFO

### 에러 트래킹
- [ ] Sentry 연동 + DSN 설정 + 릴리스 태깅

### 보안

> 보안 상세는 `/security-audit` 참조.

- [ ] Rate Limiting 활성화
- [ ] CORS 허용 도메인 명시 (`*` 금지)

### 성능
- [ ] 응답 압축 (GZipMiddleware)
- [ ] 캐시 전략 (Redis, HTTP Cache-Control)
- [ ] DB 쿼리 N+1 방지

### 백업/복구
- [ ] DB 자동 백업 + 복구 테스트 완료

---

## FE 체크리스트

### Core Web Vitals
- [ ] LCP < 2.5초, FID < 100ms, CLS < 0.1
- [ ] Lighthouse Performance >= 90

### SEO
- [ ] `<title>`, `<meta description>`, OG 태그, robots.txt, sitemap.xml

### 에러 처리
- [ ] Error Boundary (전역 + 페이지별)
- [ ] 404/500 커스텀 페이지

### 빌드 최적화
- [ ] Bundle Analyzer로 번들 크기 확인
- [ ] Dynamic Import 활용
- [ ] 불필요한 의존성 제거

---

## 공통 체크리스트

### 인프라
- [ ] SSL/TLS 인증서 + 자동 갱신
- [ ] CDN 설정
- [ ] DNS 설정 확인

### 알림 설정
- [ ] 에러율 알림 (5xx > 1%)
- [ ] 응답시간 알림 (p95 > 1초)
- [ ] 서버 리소스 알림 (CPU > 80%, Memory > 85%)
- [ ] 알림 채널: Slack/Discord/PagerDuty

### 롤백
- [ ] 롤백 절차 문서화 + 테스트 완료
- [ ] Blue-Green 또는 Canary 배포 전략 결정

### 부하 테스트
- [ ] 예상 트래픽의 2배 처리 확인

---

## 모니터링

### 3 Pillars of Observability

| 축 | 도구 | 핵심 |
|----|------|------|
| Metrics | Prometheus / Datadog | RED Method (Rate, Errors, Duration) |
| Logging | structlog → CloudWatch/ELK | JSON 포맷, 로그 레벨, 마스킹 |
| Tracing | OpenTelemetry → Jaeger/Datadog APM | 자동 계측 (FastAPI, SQLAlchemy, Redis) |

> 상세 설정 코드 (structlog, OpenTelemetry, 메트릭 미들웨어)는 references/monitoring-setup.md 참조

### 알림 정책

| 단계 | 조건 | 채널 |
|------|------|------|
| P1 Critical | 서비스 다운, 데이터 손실 | PagerDuty + 전화 |
| P2 High | 에러율 > 5%, 지연 > 3초 | Slack + PagerDuty |
| P3 Medium | 에러율 > 1%, 지연 > 1초 | Slack |
| P4 Low | 경고성 지표 이상 | Slack (업무 시간) |

> 알림 규칙 YAML 예시, Best Practices는 references/alerting-policy.md 참조

---

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

모든 항목 통과 확인 후 배포를 진행한다.
