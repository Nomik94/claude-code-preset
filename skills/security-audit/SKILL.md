---
name: security-audit
description: |
  프로젝트 보안 패턴, JWT 인증, RBAC, 예외 처리 레퍼런스.
  Use when: 로그인 구현, 인증 구현, JWT 토큰 발급, 액세스 토큰, 리프레시 토큰,
  Refresh Token Rotation, 토큰 블랙리스트, Redis 토큰 저장소,
  권한 관리, RBAC 설정, 역할 기반 접근제어, require_roles, Role vs UserRole,
  예외 처리 설계, UnauthorizedException, ForbiddenException, mappings.py,
  패스워드 해싱, 비밀번호 암호화, bcrypt, HashedPassword,
  보안 점검, 보안 체크리스트, 취약점 확인, OWASP, 코드 감사,
  CORS 설정, rate limiting, 에러 응답에 민감정보 노출.
  NOT for: 일반적인 HTTP 상태코드 의미, OAuth2 프로바이더 연동.
---

# 보안 감사 스킬

## 1. JWT 라이브러리

MUST: **PyJWT** 사용. `python-jose` 금지.

```python
import jwt  # PyJWT
# NEVER: from jose import jwt
```

- `pyproject.toml`에 `PyJWT` 의존성 확인
- 알고리즘: `HS256` 기본, 설정으로 관리 (`settings.jwt.algorithm`)
- Secret: 환경 변수, 절대 하드코딩 금지

## 2. 토큰 구조

### Access Token

- 짧은 수명 (15-30분)
- Payload: `sub`(user_id), `role`, `exp`, `iat`, `jti`
- MUST: `jti` (JWT ID) 포함 -- 블랙리스트 검증에 필수

### Refresh Token

- 긴 수명 (7-30일)
- MUST: **일회용** (One-Time Use)
- Redis에 저장, 사용 즉시 폐기 후 새 토큰 발급 (Rotation)

## 3. Refresh Token Rotation

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
1. 클라이언트 → refresh token 전송
2. Redis에서 jti 조회 → 존재하면 유효
3. 기존 refresh token 삭제
4. 새 access token + 새 refresh token 발급
5. 새 refresh token Redis에 저장
6. 응답 반환
```

MUST: 재사용 감지(이미 삭제된 jti로 요청) 시 family 전체 무효화.

## 4. Token Store (Redis)

Redis가 관리하는 토큰 관련 데이터:

| Key 패턴 | 용도 | TTL |
|----------|------|-----|
| `refresh:{jti}` | 유효한 refresh token | refresh 만료 시간 |
| `blacklist:{jti}` | 로그아웃된 access token | access token 잔여 만료 시간 |

### 로그아웃 처리

1. Access token의 `jti`를 `blacklist:{jti}`로 Redis에 저장
2. TTL = access token 잔여 만료 시간
3. 해당 사용자의 refresh token 삭제

### get_current_user 블랙리스트 검증

```python
async def get_current_user(token: str = Depends(oauth2_scheme), ...):
    payload = jwt.decode(token, settings.jwt.secret, algorithms=[settings.jwt.algorithm])
    jti = payload.get("jti")
    if await redis.exists(f"blacklist:{jti}"):
        raise UnauthorizedException(detail="Token revoked")
    # ... user 조회
```

MUST: 모든 인증 요청에서 블랙리스트 확인.

## 5. Role vs UserRole (이중 정의)

도메인 순수성을 위해 동일한 값을 두 곳에서 별도 정의한다.

| 타입 | 위치 | 용도 | import |
|------|------|------|--------|
| `Role` (StrEnum) | `core/security/rbac.py` | HTTP 접근 제어, 미들웨어 | FastAPI 레이어 |
| `UserRole` (StrEnum) | `domain/value_objects.py` | 비즈니스 로직 | 도메인 레이어 |

- 값은 동일 (`"admin"`, `"user"` 등)
- domain/ 에서 `Role` import 금지 (프레임워크 의존성)
- core/security/ 에서 `UserRole` 사용 가능하나, `Role`이 기본

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

## 6. 프로젝트 예외 사용

MUST: `UnauthorizedException` / `ForbiddenException` 사용. `HTTPException` 직접 raise 금지.

```python
# CORRECT
raise UnauthorizedException(detail="Invalid credentials")
raise ForbiddenException(detail="Insufficient permissions")

# WRONG
raise HTTPException(status_code=401, detail="...")
raise HTTPException(status_code=403, detail="...")
```

### mappings.py 패턴

도메인 예외 -> HTTP 상태코드 매핑은 **한 곳**에서 관리:

```python
# {domain}/exceptions/mappings.py
EXCEPTION_STATUS_MAP: dict[type[DomainException], int] = {
    UnauthorizedException: 401,
    ForbiddenException: 403,
    EntityNotFoundException: 404,
    DuplicateEntityException: 409,
    BusinessRuleViolation: 422,
}
```

- 각 도메인 모듈이 자체 mappings.py 보유 가능
- 글로벌 핸들러가 이 매핑을 참조하여 HTTP 응답 생성
- 새 예외 추가 시 mappings.py에 등록 필수

## 7. 패스워드 해싱 (Value Object)

```python
@dataclass(frozen=True, slots=True)
class HashedPassword:
    value: str

    @classmethod
    def from_plain(cls, plain: str) -> Self:
        return cls(value=pwd_context.hash(plain))

    def verify(self, plain: str) -> bool:
        return pwd_context.verify(plain, self.value)
```

- `pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")`
- 도메인 레이어에 위치, framework import 없음
- plain password를 도메인 엔티티에 저장하지 않음

## 8. 보안 구현 체크리스트

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
- [ ] 에러 메시지에 민감 정보 미노출 (스택 트레이스, DB 스키마 등)
- [ ] Rate limiting 적용
- [ ] 서브 애플리케이션별 CORS 설정
- [ ] 시크릿은 환경 변수, 코드에 미포함
- [ ] 의존성 취약점 스캔 완료

## 9. 검증 절차

보안 관련 코드 리뷰 또는 구현 완료 시:

1. **Import 확인**: `from jose` 존재 여부 grep -- 발견 시 PyJWT로 교체
2. **HTTPException 직접 사용 확인**: 인증/인가 코드에서 `HTTPException(status_code=401` 또는 `403` grep -- 프로젝트 예외로 교체
3. **Refresh token 일회성 확인**: rotation 로직에서 삭제 후 재발급 흐름 확인
4. **블랙리스트 확인**: `get_current_user` 경로에 Redis 블랙리스트 체크 존재 확인
5. **Role/UserRole 경계 확인**: domain/ 내에서 `from core.security` import 없음 확인
6. **mappings.py 등록 확인**: 새로 추가된 예외가 매핑 테이블에 포함되어 있는지 확인
