---
name: security-audit
description: |
  Use when 인증/인가 구현, JWT, RBAC, 패스워드 해싱, 보안 점검,
  OWASP Top 10, API 보안, 데이터 보안 관련 작업.
  NOT for 일반적인 HTTP 상태코드 의미, OAuth2 프로바이더 연동.
---

# 보안 감사 스킬

---

## 1. 인증 (Authentication)

### JWT 라이브러리

MUST: **PyJWT** 사용. `python-jose` 금지.

```python
import jwt  # PyJWT
# NEVER: from jose import jwt
```

- `pyproject.toml`에 `PyJWT` 의존성 확인
- 알고리즘: `HS256` 기본, 설정으로 관리 (`settings.jwt.algorithm`)
- Secret: 환경 변수, 절대 하드코딩 금지

### 토큰 구조

**Access Token:**
- 짧은 수명 (15-30분)
- Payload: `sub`(user_id), `role`, `exp`, `iat`, `jti`
- MUST: `jti` (JWT ID) 포함 -- 블랙리스트 검증에 필수

**Refresh Token:**
- 긴 수명 (7-30일)
- MUST: **일회용** (One-Time Use)
- Redis에 저장, 사용 즉시 폐기 후 새 토큰 발급 (Rotation)

### Refresh Token Rotation

핵심 규칙:
1. Refresh token은 **Redis에 저장**, DB 아님
2. 사용 시 **즉시 삭제** 후 새 refresh token 발급
3. 이미 사용된 refresh token 재사용 감지 시 **해당 사용자 전체 토큰 무효화**

Redis key 패턴:

```
refresh:{jti} -> user_id, role, created_at   # TTL = refresh 만료 시간
refresh:family:{family_id} -> active_jti     # Token family 추적
```

Rotation 절차:

```
1. 클라이언트 -> refresh token 전송
2. Redis에서 jti 조회 -> 존재하면 유효
3. 기존 refresh token 삭제
4. 새 access token + 새 refresh token 발급
5. 새 refresh token Redis에 저장
6. 응답 반환
```

MUST: 재사용 감지(이미 삭제된 jti로 요청) 시 family 전체 무효화.

### Token Store (Redis)

| Key 패턴 | 용도 | TTL |
|----------|------|-----|
| `refresh:{jti}` | 유효한 refresh token | refresh 만료 시간 |
| `blacklist:{jti}` | 로그아웃된 access token | access token 잔여 만료 시간 |

**로그아웃 처리:**
1. Access token의 `jti`를 `blacklist:{jti}`로 Redis에 저장
2. TTL = access token 잔여 만료 시간
3. 해당 사용자의 refresh token 삭제

**get_current_user 블랙리스트 검증:**

```python
async def get_current_user(token: str = Depends(oauth2_scheme), ...):
    payload = jwt.decode(token, settings.jwt.secret, algorithms=[settings.jwt.algorithm])
    jti = payload.get("jti")
    if await redis.exists(f"blacklist:{jti}"):
        raise UnauthorizedException(detail="Token revoked")
    # ... user 조회
```

MUST: 모든 인증 요청에서 블랙리스트 확인.

### 패스워드 해싱 (Value Object)

```python
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

password_hash = PasswordHash((Argon2Hasher(),))

@dataclass(frozen=True, slots=True)
class HashedPassword:
    value: str

    @classmethod
    def from_plain(cls, plain: str) -> Self:
        return cls(value=password_hash.hash(plain))

    def verify(self, plain: str) -> bool:
        return password_hash.verify(plain, self.value)
```

- `pwdlib` + `Argon2Hasher` 사용 (passlib 대체)
- `password_hash.is_deprecated(hashed)` 로 알고리즘 마이그레이션 감지
- 도메인 레이어에 위치, framework import 없음
- plain password를 도메인 엔티티에 저장하지 않음

---

## 2. 인가 (Authorization)

### Role vs UserRole (이중 정의)

도메인 순수성을 위해 동일한 값을 두 곳에서 별도 정의.

| 타입 | 위치 | 용도 | import |
|------|------|------|--------|
| `Role` (StrEnum) | `core/security/rbac.py` | HTTP 접근 제어, 미들웨어 | FastAPI 레이어 |
| `UserRole` (StrEnum) | `domain/value_objects.py` | 비즈니스 로직 | 도메인 레이어 |

- 값은 동일 (`"admin"`, `"user"` 등)
- domain/ 에서 `Role` import 금지 (프레임워크 의존성)

### RBAC 패턴

```python
# core/security/rbac.py
class Role(StrEnum):
    ADMIN = "admin"
    USER = "user"

def require_roles(*allowed: Role) -> ...:
    async def checker(current_user=Depends(get_current_user)):
        if current_user.role not in allowed:
            raise ForbiddenException(...)
        return current_user
    return checker
```

### 프로젝트 예외 사용

MUST: `UnauthorizedException` / `ForbiddenException` 사용. `HTTPException` 직접 raise 금지.

```python
# CORRECT
raise UnauthorizedException(detail="Invalid credentials")
raise ForbiddenException(detail="Insufficient permissions")

# WRONG
raise HTTPException(status_code=401, detail="...")
raise HTTPException(status_code=403, detail="...")
```

---

## 3. OWASP Top 10 체크리스트

### A01: Broken Access Control

- [ ] 모든 엔드포인트에 인증/인가 확인
- [ ] 리소스 소유권 검증 (user_id 비교)
- [ ] CORS 올바르게 설정
- [ ] 디렉토리 트래버설 방지

### A02: Cryptographic Failures

- [ ] 비밀번호는 Argon2로 해싱 (pwdlib)
- [ ] JWT secret 충분한 길이 (256bit+)
- [ ] HTTPS 강제 (production)
- [ ] 민감 데이터 로그에 미노출

### A03: Injection

- [ ] SQLAlchemy ORM/파라미터화 쿼리 사용 (raw SQL 금지)
- [ ] Pydantic v2로 모든 입력 검증
- [ ] 쿼리 파라미터 바인딩 사용

### A04: Insecure Design

- [ ] Rate limiting 적용
- [ ] 비즈니스 로직 남용 방지 (예: 무제한 쿠폰 사용)
- [ ] 적절한 에러 메시지 (내부 정보 미노출)

### A05: Security Misconfiguration

- [ ] DEBUG=False in production
- [ ] docs_url=None in production
- [ ] 기본 자격증명 변경
- [ ] 불필요한 HTTP 메서드 비활성화

### A06: Vulnerable and Outdated Components

- [ ] `poetry run pip-audit` 통과
- [ ] 정기적 의존성 업데이트
- [ ] 알려진 취약점 없는 버전 사용

### A07: Identification and Authentication Failures

- [ ] 비밀번호 정책 강제 (최소 길이, 복잡도)
- [ ] 로그인 시도 제한 (brute force 방지)
- [ ] Refresh token rotation 적용
- [ ] 세션/토큰 만료 설정

### A08: Software and Data Integrity Failures

- [ ] JWT 서명 검증
- [ ] 의존성 무결성 확인 (poetry.lock)
- [ ] CI/CD 파이프라인 보안

### A09: Security Logging and Monitoring Failures

- [ ] 인증 실패 로깅
- [ ] 권한 위반 로깅
- [ ] structlog로 구조화된 로그
- [ ] 민감 정보 마스킹

### A10: Server-Side Request Forgery (SSRF)

- [ ] 외부 URL 입력 시 허용 목록 검증
- [ ] 내부 네트워크 접근 차단
- [ ] URL 스킴 제한 (http/https만)

---

## 4. API 보안

### Rate Limiting

| 환경 | 구현 |
|------|------|
| dev/local | In-memory (dict + sliding window) |
| production | Redis (INCR + EXPIRE) |

- IP 기반 + 사용자 기반 이중 제한
- 429 응답 시 `Retry-After` 헤더 포함

### CORS

- `allow_origins=["*"]` + `allow_credentials=True` 조합 prod 금지
- 환경별 origins 설정에서 관리
- `expose_headers`에 커스텀 헤더 명시

### CSRF

- SameSite cookie 설정
- Double Submit Cookie 패턴
- API-only 서비스는 CSRF 토큰 대신 Authorization 헤더

### 입력 검증

- 모든 요청은 Pydantic 모델로 검증
- 문자열 길이 제한 (MaxLen)
- 파일 업로드 크기/타입 제한
- 쿼리 파라미터도 Pydantic Query 모델 사용

---

## 5. 데이터 보안

### 암호화

- 비밀번호: Argon2 (pwdlib)
- 토큰: JWT (PyJWT)
- 민감 설정: pydantic-settings + 환경 변수

### PII 처리

- 필요 최소한의 개인정보만 수집
- 삭제 요청 시 실제 삭제 또는 비식별화
- 로그에서 PII 자동 마스킹

### 로그에서 민감정보 마스킹

```python
import structlog

def mask_sensitive_fields(_, __, event_dict):
    sensitive_keys = {"password", "token", "secret", "authorization", "cookie"}
    for key in event_dict:
        if key.lower() in sensitive_keys:
            event_dict[key] = "***MASKED***"
    return event_dict

structlog.configure(
    processors=[
        mask_sensitive_fields,
        # ... 다른 프로세서
    ]
)
```

---

## 검증 체크리스트

### 인증/인가

- [ ] PyJWT 사용 (`import jwt`), python-jose 아님
- [ ] Access token에 `jti` 포함
- [ ] Refresh token Redis 저장 + 일회용 rotation
- [ ] 재사용된 refresh token 감지 시 family 전체 무효화
- [ ] 로그아웃 시 access token jti 블랙리스트 등록
- [ ] `get_current_user`에서 블랙리스트 확인
- [ ] `UnauthorizedException` / `ForbiddenException` 사용 (HTTPException 금지)
- [ ] Role(core/security) vs UserRole(domain) 분리 유지
- [ ] mappings.py에 예외-HTTP 매핑 등록

### 일반 보안

- [ ] 하드코딩된 자격증명 없음 (환경 변수 사용)
- [ ] 모든 입력값 Pydantic 모델로 검증
- [ ] SQL 인젝션 방지 (SQLAlchemy 파라미터화 쿼리)
- [ ] 에러 메시지에 민감 정보 미노출
- [ ] Rate limiting 적용
- [ ] 서브 애플리케이션별 CORS 설정
- [ ] 의존성 취약점 스캔 완료 (`pip-audit`)

### 검증 절차

1. **Import 확인**: `from jose` 존재 여부 -- 발견 시 PyJWT로 교체
2. **HTTPException 직접 사용 확인**: 인증/인가 코드에서 `HTTPException(status_code=401` 또는 `403` -- 프로젝트 예외로 교체
3. **Refresh token 일회성 확인**: rotation 로직에서 삭제 후 재발급 흐름 확인
4. **블랙리스트 확인**: `get_current_user` 경로에 Redis 블랙리스트 체크 존재 확인
5. **Role/UserRole 경계 확인**: domain/ 내에서 `from core.security` import 없음 확인
6. **mappings.py 등록 확인**: 새로 추가된 예외가 매핑 테이블에 포함되어 있는지 확인
