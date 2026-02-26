---
name: security-audit
description: |
  프로젝트 보안 패턴 및 예외 처리 레퍼런스.
  Use when: 로그인 구현, 인증 구현, JWT 토큰 발급, 액세스 토큰, 리프레시 토큰,
  권한 관리, RBAC 설정, 역할 기반 접근제어, require_roles, 관리자 권한,
  예외 처리 설계, Exception 계층, 도메인 예외 vs 앱 예외, 에러 핸들러 등록,
  패스워드 해싱, 비밀번호 암호화, bcrypt, HashedPassword,
  보안 점검, 보안 체크리스트, 취약점 확인, OWASP, 코드 감사,
  CORS 설정, rate limiting, 에러 응답에 민감정보 노출.
  NOT for: 일반적인 HTTP 상태코드 의미, OAuth2 프로바이더 연동.
---

# 보안 감사 스킬

## JWT 인증

```python
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

def create_access_token(user_id: int, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt.access_expire_minutes)
    payload = {"sub": str(user_id), "role": role, "exp": expire, "iat": datetime.now(timezone.utc)}
    return jwt.encode(payload, settings.jwt.secret, algorithm=settings.jwt.algorithm)

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    try:
        payload = jwt.decode(token, settings.jwt.secret, algorithms=[settings.jwt.algorithm])
        user_id = int(payload.get("sub"))
    except (JWTError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user = await repo.find_by_id(user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=401)
    return user
```

## RBAC

```python
def require_roles(*allowed_roles: Role):
    async def checker(current_user=Depends(get_current_user)):
        if current_user.role.value not in [r.value for r in allowed_roles]:
            raise HTTPException(status_code=403,
                detail=f"Requires {', '.join(r.value for r in allowed_roles)}")
        return current_user
    return checker

@router.delete("/{id}", dependencies=[Depends(require_roles(Role.ADMIN))])
async def delete_user(id: int): ...
```

## 예외 계층 구조

```
AppException (HTTP-aware)
├── NotFoundException(404)
├── AlreadyExistsException(409)
├── BusinessException(422)
├── UnauthorizedException(401)
└── ForbiddenException(403)

DomainException (HTTP-unaware, pure business)
├── UserNotFoundException
├── EmailAlreadyExistsException
├── InvalidOrderStatusTransitionError
└── InsufficientStockException
```

## 예외 핸들러 등록

```python
def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def app_handler(request, exc):
        return JSONResponse(status_code=exc.status_code,
            content={"success": False, "error": {"code": exc.code, "message": exc.message}})

    @app.exception_handler(UserNotFoundException)
    async def user_not_found(request, exc):
        return JSONResponse(status_code=404, content={"success": False, "error": {...}})

    @app.exception_handler(Exception)
    async def unhandled(request, exc):
        logger.error("unhandled_exception", exc_info=exc)
        return JSONResponse(status_code=500,
            content={"success": False, "error": {"code": "INTERNAL_ERROR"}})
```

## 패스워드 해싱 (Value Object)

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

## 보안 체크리스트

- [ ] 하드코딩된 자격증명 없음 (환경 변수 사용)
- [ ] 모든 입력값 검증됨 (Pydantic 모델)
- [ ] SQL 인젝션 방지됨 (SQLAlchemy 파라미터화 쿼리)
- [ ] XSS 방지됨 (응답에 raw HTML 없음)
- [ ] 모든 엔드포인트에 적절한 인증/인가 적용
- [ ] Rate limiting 적용됨
- [ ] 에러 메시지에 민감 정보 미노출
- [ ] 의존성 스캔 완료 (pip-audit)
- [ ] 서브 애플리케이션별 CORS 적절히 설정됨
- [ ] 시크릿은 환경 변수로 관리, 코드에 미포함
