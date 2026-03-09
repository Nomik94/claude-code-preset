---
name: production-checklist
description: |
  프로덕션 배포 전 체크리스트.
  Use when: 배포, 프로덕션, production, deploy, 릴리즈, release,
  라이브, 런칭, go-live, 배포 전 확인, 운영 환경.
  NOT for: 로컬 개발 환경 설정.
---

# 프로덕션 배포 체크리스트

## 1. 코드 품질

- [ ] `ruff check .` 위반 사항 없이 통과
- [ ] `ruff format --check .` 일관된 포매팅 확인
- [ ] `mypy --strict .` 에러 없이 통과
- [ ] 모든 테스트 통과: `poetry run pytest --tb=short`
- [ ] 테스트 커버리지 >= 80%: `poetry run pytest --cov --cov-fail-under=80`
- [ ] 프로덕션 코드에 `TODO`, `FIXME`, `HACK` 주석 없음
- [ ] `print()` 문 없음 — 구조화 로깅만 사용
- [ ] `import pdb` 또는 디버그 브레이크포인트 없음

## 2. 보안

- [ ] 소스 코드에 하드코딩된 시크릿, API 키, 비밀번호 없음
- [ ] `.env` 파일이 `.gitignore`에 등록 (확인: `git ls-files .env`가 빈 결과 반환)
- [ ] CORS 오리진 명시적으로 나열 (프로덕션에서 절대 `allow_origins=["*"]` 금지)
- [ ] 인증 및 공개 엔드포인트에 Rate Limiting 적용
- [ ] JWT 시크릿 키를 환경변수에서 가져오며, 최소 256비트
- [ ] JWT 토큰 만료 설정 (access: 15-30분, refresh: 7-14일)
- [ ] Refresh Token Rotation 적용 (일회용 refresh token + Redis 블랙리스트)
- [ ] PyJWT 사용 (python-jose 아님)
- [ ] `pip-audit` 또는 `safety check`에서 알려진 취약점 없음
- [ ] 비밀번호 해싱에 bcrypt/argon2와 적절한 work factor 사용
- [ ] SQL 인젝션 방지 (파라미터화된 쿼리 / ORM만 사용)
- [ ] 모든 엔드포인트에 Pydantic 모델을 통한 입력 유효성 검증

## 3. 데이터베이스

- [ ] Alembic 마이그레이션 최신 상태: `alembic check`에서 드리프트 없음
- [ ] 다운그레이드 경로 테스트 완료: `alembic downgrade -1` 후 `alembic upgrade head`
- [ ] 커넥션 풀 설정 완료: `pool_size`, `max_overflow`, `pool_timeout`
- [ ] 모든 외래 키 및 자주 필터링되는 컬럼에 인덱스 존재
- [ ] 파라미터화된 쿼리 없이 raw SQL 사용 금지
- [ ] 데이터베이스 백업 전략 문서화 및 테스트 완료
- [ ] 마이그레이션 30초 이내 실행 (장시간 락 방지)

## 4. 성능

- [ ] N+1 쿼리 해결 (lazy="raise" 기본 + `selectinload` / `joinedload` 명시)
- [ ] 핫 경로에 Redis 캐싱 설정 완료
- [ ] 느린 쿼리 로깅 활성화 (임계값: 200ms)
- [ ] 모든 목록 엔드포인트에 페이지네이션 적용 (최대 페이지 크기 제한)
- [ ] 대용량 파일 업로드는 인메모리 버퍼링이 아닌 스트리밍 사용
- [ ] I/O 바운드 작업에 async 엔드포인트 사용

## 5. 인프라

- [ ] Docker 이미지 빌드 성공: `docker build -t app .`
- [ ] 멀티 스테이지 Dockerfile (빌드 vs 런타임 분리)
- [ ] 컨테이너에서 비루트 사용자: `USER appuser`
- [ ] 헬스 체크 엔드포인트 정상 동작: `GET /health`가 200 반환
- [ ] Readiness probe와 Liveness probe 구분
- [ ] 구조화된 JSON 로깅 설정 (일반 텍스트 로그 금지)
- [ ] 환경변수를 통한 로그 레벨 설정 가능
- [ ] 모니터링 및 알림 설정 완료 (에러율, 지연 시간 p95/p99)
- [ ] 그레이스풀 셧다운으로 진행 중인 요청 처리
- [ ] 백업 및 재해 복구 계획 문서화

## 6. API

- [ ] OpenAPI 문서 정확하고 접근 가능: `/docs`, `/redoc`
- [ ] 모든 에러 응답이 일관된 스키마 준수 (`code`, `message`, `errors`)
- [ ] 모든 목록 엔드포인트에 `limit`/`offset` 또는 커서 페이지네이션
- [ ] API 버저닝 적용: `/{client}/v{version}/{domain}/{action}` (EndpointPath)
- [ ] OpenAPI 스키마에 요청/응답 예시 포함
- [ ] `Content-Type` 및 `Accept` 헤더 검증
- [ ] 적절한 HTTP 상태 코드 (생성 시 201, 삭제 시 204)

## 7. 배포 전 최종 단계

```bash
# Run full validation suite
poetry run ruff check .
poetry run mypy --strict .
poetry run pytest --cov --cov-fail-under=80 -q
pip-audit

# Verify Docker build
docker compose build --no-cache
docker compose up -d
curl -f http://localhost:8000/health

# Verify migrations
docker compose exec app alembic check
```

## 8. 배포 후 검증

- [ ] 헬스 엔드포인트가 200 반환
- [ ] 핵심 사용자 플로우 스모크 테스트 (로그인, 핵심 CRUD)
- [ ] 모니터링 대시보드에서 에러율 확인 (기준치 비교)
- [ ] 로그 출력이 구조화되었고 로그 수집기에 도달하는지 확인
- [ ] 롤백 절차가 준비되고 문서화되었는지 확인
