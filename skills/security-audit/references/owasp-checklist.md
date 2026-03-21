# OWASP Top 10 FastAPI 체크리스트

## A01: Broken Access Control

- [ ] 모든 엔드포인트에 인증/인가 확인
- [ ] 리소스 소유권 검증 (user_id 비교)
- [ ] CORS 올바르게 설정
- [ ] 디렉토리 트래버설 방지

### FastAPI 적용

```python
# 리소스 소유권 검증
@router.get(ep.detail())
async def get_order(
    order_id: int,
    current_user: UserEntity = Depends(get_current_user),
    service: OrderService = Depends(get_order_service),
) -> OrderResponse:
    order = await service.get(order_id)
    if order.user_id != current_user.id and current_user.role != UserRole.ADMIN:
        raise ForbiddenException(detail="이 주문에 접근할 권한이 없습니다")
    return OrderResponse.from_domain(order)
```

## A02: Cryptographic Failures

- [ ] 비밀번호는 Argon2로 해싱 (pwdlib)
- [ ] JWT secret 충분한 길이 (256bit+)
- [ ] HTTPS 강제 (production)
- [ ] 민감 데이터 로그에 미노출

### 시크릿 길이 검증

```python
@model_validator(mode="after")
def validate_jwt_secret(self) -> Self:
    if self.env == "prod" and len(self.jwt.secret_key) < 32:
        raise ValueError("JWT secret must be at least 256 bits (32 chars)")
    return self
```

## A03: Injection

- [ ] SQLAlchemy ORM/파라미터화 쿼리 사용 (raw SQL 금지)
- [ ] Pydantic v2로 모든 입력 검증
- [ ] 쿼리 파라미터 바인딩 사용

### SQL Injection 방지

```python
# Bad: raw SQL 문자열 조합
query = f"SELECT * FROM users WHERE email = '{email}'"

# Good: SQLAlchemy 파라미터화
stmt = select(UserModel).where(UserModel.email == email)

# Good: raw SQL 필요 시 바인딩
stmt = text("SELECT * FROM users WHERE email = :email")
result = await db.execute(stmt, {"email": email})
```

## A04: Insecure Design

- [ ] Rate limiting 적용
- [ ] 비즈니스 로직 남용 방지 (예: 무제한 쿠폰 사용)
- [ ] 적절한 에러 메시지 (내부 정보 미노출)

### 에러 메시지 필터링

```python
# Bad: 내부 정보 노출
raise HTTPException(status_code=500, detail=str(e))

# Good: 일반 메시지 + 로깅
logger.error("order_creation_failed", error=str(e), user_id=user_id)
raise InternalServerException(detail="주문 처리 중 오류가 발생했습니다")
```

## A05: Security Misconfiguration

- [ ] DEBUG=False in production
- [ ] docs_url=None in production
- [ ] 기본 자격증명 변경
- [ ] 불필요한 HTTP 메서드 비활성화

### Production 설정 검증

```python
def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
        openapi_url="/openapi.json" if settings.debug else None,
    )
    return app
```

## A06: Vulnerable and Outdated Components

- [ ] `poetry run pip-audit` 통과
- [ ] 정기적 의존성 업데이트
- [ ] 알려진 취약점 없는 버전 사용

```bash
# 의존성 취약점 스캔
poetry run pip-audit
poetry run bandit -r app/
```

## A07: Identification and Authentication Failures

- [ ] 비밀번호 정책 강제 (최소 길이, 복잡도)
- [ ] 로그인 시도 제한 (brute force 방지)
- [ ] Refresh token rotation 적용
- [ ] 세션/토큰 만료 설정

### 비밀번호 정책

```python
@field_validator("password")
@classmethod
def validate_password_strength(cls, v: str) -> str:
    if len(v) < 8:
        raise ValueError("비밀번호는 최소 8자 이상")
    if not any(c.isupper() for c in v):
        raise ValueError("대문자를 포함해야 합니다")
    if not any(c.isdigit() for c in v):
        raise ValueError("숫자를 포함해야 합니다")
    return v
```

### 로그인 시도 제한

```python
LOGIN_LIMIT_KEY = "login_attempts:{ip}:{email}"
MAX_ATTEMPTS = 5
LOCKOUT_SECONDS = 900  # 15분

async def check_login_rate_limit(ip: str, email: str, redis: Redis) -> None:
    key = LOGIN_LIMIT_KEY.format(ip=ip, email=email)
    attempts = await redis.incr(key)
    if attempts == 1:
        await redis.expire(key, LOCKOUT_SECONDS)
    if attempts > MAX_ATTEMPTS:
        raise TooManyRequestsException(detail="로그인 시도 횟수를 초과했습니다")
```

## A08: Software and Data Integrity Failures

- [ ] JWT 서명 검증
- [ ] 의존성 무결성 확인 (poetry.lock)
- [ ] CI/CD 파이프라인 보안

## A09: Security Logging and Monitoring Failures

- [ ] 인증 실패 로깅
- [ ] 권한 위반 로깅
- [ ] structlog로 구조화된 로그
- [ ] 민감 정보 마스킹

### 민감정보 마스킹

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

## A10: Server-Side Request Forgery (SSRF)

- [ ] 외부 URL 입력 시 허용 목록 검증
- [ ] 내부 네트워크 접근 차단
- [ ] URL 스킴 제한 (http/https만)

### URL 검증

```python
from urllib.parse import urlparse

ALLOWED_HOSTS = {"api.example.com", "cdn.example.com"}

def validate_external_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise ValueError("http/https 스킴만 허용")
    if parsed.hostname in ("localhost", "127.0.0.1", "0.0.0.0"):
        raise ValueError("내부 네트워크 접근 금지")
    if parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError("허용되지 않은 호스트")
    return url
```
