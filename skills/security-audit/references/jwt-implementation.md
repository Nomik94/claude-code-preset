# JWT 구현 상세

## PyJWT 사용

MUST: **PyJWT** 사용. `python-jose` 금지.

```python
import jwt  # PyJWT
# NEVER: from jose import jwt
```

- `pyproject.toml`에 `PyJWT` 의존성 확인
- 알고리즘: `HS256` 기본, 설정으로 관리 (`settings.jwt.algorithm`)
- Secret: 환경 변수, 절대 하드코딩 금지

## 토큰 구조

### Access Token

- 짧은 수명 (15-30분)
- Payload: `sub`(user_id), `role`, `exp`, `iat`, `jti`
- MUST: `jti` (JWT ID) 포함 -- 블랙리스트 검증에 필수

```python
import uuid
from datetime import datetime, timedelta, timezone

import jwt


def create_access_token(
    user_id: int,
    role: str,
    settings: JWTSettings,
) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": now + timedelta(minutes=settings.access_token_expire_minutes),
        "iat": now,
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)
```

### Refresh Token

- 긴 수명 (7-30일)
- MUST: **일회용** (One-Time Use)
- Redis에 저장, 사용 즉시 폐기 후 새 토큰 발급 (Rotation)

```python
def create_refresh_token(
    user_id: int,
    role: str,
    family_id: str,
    settings: JWTSettings,
) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": now + timedelta(days=settings.refresh_token_expire_days),
        "iat": now,
        "jti": str(uuid.uuid4()),
        "family": family_id,
        "type": "refresh",
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)
```

## Refresh Token Rotation

### 핵심 규칙

1. Refresh token은 **Redis에 저장**, DB 아님
2. 사용 시 **즉시 삭제** 후 새 refresh token 발급
3. 이미 사용된 refresh token 재사용 감지 시 **해당 사용자 전체 토큰 무효화**

### Redis Key 패턴

```
refresh:{jti} -> user_id, role, created_at   # TTL = refresh 만료 시간
refresh:family:{family_id} -> active_jti     # Token family 추적
```

### Rotation 절차

```
1. 클라이언트 -> refresh token 전송
2. Redis에서 jti 조회 -> 존재하면 유효
3. 기존 refresh token 삭제
4. 새 access token + 새 refresh token 발급
5. 새 refresh token Redis에 저장
6. 응답 반환
```

### 구현 코드

```python
from redis.asyncio import Redis


class TokenService:
    def __init__(self, redis: Redis, settings: JWTSettings) -> None:
        self.redis = redis
        self.settings = settings

    async def rotate_refresh_token(self, refresh_token: str) -> tuple[str, str]:
        """Refresh token rotation. 새 access + refresh token 쌍 반환."""
        payload = jwt.decode(
            refresh_token,
            self.settings.secret_key,
            algorithms=[self.settings.algorithm],
        )
        jti = payload["jti"]
        family_id = payload["family"]
        user_id = int(payload["sub"])
        role = payload["role"]

        # 1. Redis에서 유효성 확인
        stored = await self.redis.get(f"refresh:{jti}")
        if not stored:
            # 재사용 감지! family 전체 무효화
            await self._revoke_family(family_id)
            raise UnauthorizedException(detail="Token reuse detected")

        # 2. 기존 토큰 삭제
        await self.redis.delete(f"refresh:{jti}")

        # 3. 새 토큰 쌍 발급
        new_access = create_access_token(user_id, role, self.settings)
        new_refresh = create_refresh_token(user_id, role, family_id, self.settings)

        # 4. 새 refresh token Redis 저장
        new_payload = jwt.decode(
            new_refresh, self.settings.secret_key,
            algorithms=[self.settings.algorithm],
        )
        new_jti = new_payload["jti"]
        ttl = self.settings.refresh_token_expire_days * 86400
        await self.redis.setex(
            f"refresh:{new_jti}",
            ttl,
            f"{user_id}:{role}",
        )
        await self.redis.setex(f"refresh:family:{family_id}", ttl, new_jti)

        return new_access, new_refresh

    async def _revoke_family(self, family_id: str) -> None:
        """Token family 전체 무효화."""
        active_jti = await self.redis.get(f"refresh:family:{family_id}")
        if active_jti:
            await self.redis.delete(f"refresh:{active_jti}")
        await self.redis.delete(f"refresh:family:{family_id}")
```

## Token Store (Redis)

| Key 패턴 | 용도 | TTL |
|----------|------|-----|
| `refresh:{jti}` | 유효한 refresh token | refresh 만료 시간 |
| `blacklist:{jti}` | 로그아웃된 access token | access token 잔여 만료 시간 |

### 로그아웃 처리

1. Access token의 `jti`를 `blacklist:{jti}`로 Redis에 저장
2. TTL = access token 잔여 만료 시간
3. 해당 사용자의 refresh token 삭제

```python
async def logout(self, access_token: str) -> None:
    payload = jwt.decode(
        access_token, self.settings.secret_key,
        algorithms=[self.settings.algorithm],
    )
    jti = payload["jti"]
    exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
    remaining_ttl = int((exp - datetime.now(timezone.utc)).total_seconds())

    if remaining_ttl > 0:
        await self.redis.setex(f"blacklist:{jti}", remaining_ttl, "revoked")
```

### get_current_user 블랙리스트 검증

```python
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    redis: Redis = Depends(get_redis),
    settings: JWTSettings = Depends(get_jwt_settings),
) -> UserEntity:
    payload = jwt.decode(
        token, settings.secret_key, algorithms=[settings.algorithm],
    )
    jti = payload.get("jti")
    if await redis.exists(f"blacklist:{jti}"):
        raise UnauthorizedException(detail="Token revoked")
    # ... user 조회
```

MUST: 모든 인증 요청에서 블랙리스트 확인.

## 패스워드 해싱 (Value Object)

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
