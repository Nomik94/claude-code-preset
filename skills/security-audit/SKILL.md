---
name: security-audit
description: |
  Use when 인증/인가 구현, JWT, RBAC, 패스워드 해싱, 보안 점검,
  OWASP Top 10, API 보안, 데이터 보안 관련 작업.
  NOT for 일반적인 HTTP 상태코드 의미, OAuth2 프로바이더 연동.
files:
  - references/jwt-implementation.md
  - references/owasp-checklist.md
---

# 보안 감사 스킬

---

## 1. 인증 (Authentication) 핵심 규칙

### JWT

- MUST: **PyJWT** 사용 (`import jwt`). `python-jose` 금지
- Access Token: 15-30분, `sub`/`role`/`exp`/`iat`/`jti` 포함
- Refresh Token: 7-30일, **일회용**, Redis 저장, Rotation 필수
- `jti` (JWT ID) MUST: 블랙리스트 검증에 필수

### Refresh Token Rotation 흐름

1. Refresh token Redis에서 jti 조회
2. 존재하면 유효 -> **즉시 삭제**
3. 새 access + refresh token 발급, Redis에 저장
4. **재사용 감지 시 family 전체 무효화**

### Token Store (Redis)

| Key 패턴 | 용도 | TTL |
|----------|------|-----|
| `refresh:{jti}` | 유효한 refresh token | refresh 만료 시간 |
| `blacklist:{jti}` | 로그아웃된 access token | 잔여 만료 시간 |

### 패스워드 해싱

- `pwdlib` + `Argon2Hasher` 사용 (passlib 대체)
- `HashedPassword` Value Object, 도메인 레이어에 위치

> JWT 전체 구현, Rotation 코드, 패스워드 해싱 상세는 references/jwt-implementation.md 참조

---

## 2. 인가 (Authorization)

### Role vs UserRole (이중 정의)

| 타입 | 위치 | 용도 |
|------|------|------|
| `Role` (StrEnum) | `core/security/rbac.py` | HTTP 접근 제어 |
| `UserRole` (StrEnum) | `domain/value_objects.py` | 비즈니스 로직 |

- 값은 동일, domain/에서 `Role` import 금지

### RBAC 패턴

```python
def require_roles(*allowed: Role) -> ...:
    async def checker(current_user=Depends(get_current_user)):
        if current_user.role not in allowed:
            raise ForbiddenException(...)
        return current_user
    return checker
```

### 프로젝트 예외 사용

MUST: `UnauthorizedException` / `ForbiddenException` 사용. `HTTPException` 직접 raise 금지.

---

## 3. OWASP Top 10 핵심 체크

| 항목 | 핵심 대응 |
|------|----------|
| A01 Broken Access Control | 모든 엔드포인트 인증/인가, 리소스 소유권 검증 |
| A02 Cryptographic Failures | Argon2 해싱, JWT secret 256bit+, HTTPS |
| A03 Injection | SQLAlchemy ORM, Pydantic 입력 검증 |
| A05 Security Misconfiguration | DEBUG=False, docs_url=None (prod) |
| A07 Auth Failures | 비밀번호 정책, 로그인 제한, Token rotation |

> 각 항목별 FastAPI 체크리스트 상세는 references/owasp-checklist.md 참조

---

## 4. API 보안

- Rate Limiting: IP + 사용자 이중 제한, 429 + Retry-After
- CORS: `allow_origins=["*"]` + `allow_credentials=True` prod 금지
- 입력 검증: 모든 요청 Pydantic 모델, 문자열 길이 제한
- CSRF: SameSite cookie, API-only는 Authorization 헤더

---

## 5. 데이터 보안

- 민감 설정: pydantic-settings + 환경 변수 (하드코딩 금지)
- PII: 최소 수집, 삭제/비식별화, 로그 마스킹
- 로그 마스킹: structlog 프로세서로 password/token/secret 필터링

---

## 검증 체크리스트

### 인증/인가
- [ ] PyJWT 사용, python-jose 아님
- [ ] Access token에 `jti` 포함
- [ ] Refresh token Redis 저장 + 일회용 rotation
- [ ] 재사용 감지 시 family 전체 무효화
- [ ] 로그아웃 시 access token jti 블랙리스트 등록
- [ ] `get_current_user`에서 블랙리스트 확인
- [ ] `UnauthorizedException` / `ForbiddenException` 사용
- [ ] Role(core/security) vs UserRole(domain) 분리 유지

### 일반 보안
- [ ] 하드코딩된 자격증명 없음
- [ ] 모든 입력값 Pydantic 모델로 검증
- [ ] SQL 인젝션 방지 (SQLAlchemy 파라미터화 쿼리)
- [ ] Rate limiting 적용
- [ ] 의존성 취약점 스캔 (`pip-audit`)

### 검증 절차
1. `from jose` 존재 여부 -> PyJWT로 교체
2. `HTTPException(status_code=401|403)` -> 프로젝트 예외로 교체
3. Refresh token rotation 삭제 후 재발급 흐름 확인
4. `get_current_user` 블랙리스트 체크 확인
5. domain/ 내 `from core.security` import 없음 확인
