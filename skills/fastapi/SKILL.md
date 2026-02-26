---
name: fastapi
description: |
  FastAPI 프로젝트 고유 설정 및 패턴 레퍼런스.
  Use when: 프로젝트 구조 잡기, 폴더 구조, 디렉토리 구조, 초기 세팅, 새 프로젝트 시작,
  파일 분리, 파일이 너무 커, 폴더로 변환, 파일 비대, 모듈 분리, 패키지 분리,
  DI 패턴 선택, 의존성 주입, Depends vs Container vs Dishka,
  Ruff 설정, mypy 설정, 린터 세팅, 포맷터 세팅, pre-commit 설정, import-linter,
  App Factory, create_app, lifespan, pydantic-settings, 환경변수 설정, config 구조,
  레이어 분리, router/service/repository 구조, 도메인 레이어 도입 기준.
  NOT for: 단순 FastAPI 문법 질문 (Claude가 이미 앎), 일반적인 Ruff/mypy 사용법.
---

# FastAPI 스킬

## 프로젝트 구조

초기 단일 파일로 시작. 비대해지면 같은 이름의 폴더로 진화 (아래 "File → Package Evolution" 참조).

```
project-root/
├── pyproject.toml / poetry.lock / alembic.ini
├── .pre-commit-config.yaml / .importlinter
├── migrations/
│   ├── env.py
│   └── versions/
├── app/
│   ├── main.py                        # App factory (create_app)
│   ├── core/                          # Infrastructure (no domain deps)
│   │   ├── config.py                  # pydantic-settings  → config/ 가능
│   │   ├── database.py                # Engine, session, Base
│   │   ├── security.py                # JWT, password       → security/ 가능
│   │   ├── exceptions.py              # Base exceptions     → exceptions/ 가능
│   │   ├── middleware.py              # Logging, CORS       → middleware/ 가능
│   │   ├── event_bus.py
│   │   └── cache.py
│   ├── common/                        # Cross-domain utilities
│   │   ├── pagination.py / base_repository.py / base_dto.py
│   │   ├── types.py                   # KoreanPhone, PositiveInt
│   │   └── decorators.py             # @transactional, @retry, @log_execution
│   ├── {domain}/
│   │   ├── router.py                  # HTTP endpoints       → router/ 가능
│   │   ├── dto.py                 # Pydantic DTOs        → dto/ 가능
│   │   ├── dependencies.py            # Depends() factories
│   │   ├── domain/                    # Pure business logic (ZERO dependencies)
│   │   │   ├── entities.py            # Entities             → entities/ 가능
│   │   │   ├── value_objects.py       # VOs                  → value_objects/ 가능
│   │   │   ├── services.py            # Domain services      → services/ 가능
│   │   │   ├── repositories.py        # Protocol interfaces (Ports)
│   │   │   ├── events.py / exceptions.py
│   │   ├── application/
│   │   │   └── service.py             # Use case orchestration → 파일 분리 가능
│   │   └── infrastructure/
│   │       ├── models.py              # SQLAlchemy ORM        → models/ 가능
│   │       └── repository.py          # Protocol impl         → repository/ 가능
└── tests/
    ├── conftest.py
    ├── unit/{domain}/                 # Pure domain tests (no DB)
    └── integration/                   # API tests with real DB
```

> **→ 가능**: 200줄+ 또는 클래스 3개+ 시 폴더로 분리. `__init__.py` re-export 필수.

## File → Package Evolution

파일이 비대해지면 (200줄+ 또는 클래스 3개+) **같은 이름의 폴더**로 변환하고 세부 파일로 분리.
`__init__.py`에서 re-export하여 **기존 import 경로를 유지**.

### 진화 규칙
```
200줄+ 또는 클래스 3개+ → 폴더 분리
__init__.py에서 반드시 re-export → 외부 import 경로 변경 없음
파일명 = 역할 기반 (entities_user.py ❌ → user.py ✅)
```

### Domain Layer 진화

```
# BEFORE: 단일 파일
{domain}/domain/
├── entities.py          # User, UserProfile, UserSettings (3개 엔티티)
├── value_objects.py
├── repositories.py
└── services.py

# AFTER: 폴더 분리
{domain}/domain/
├── entities/
│   ├── __init__.py      # from .user import User, UserProfile
│   ├── user.py          # User, UserProfile
│   └── user_settings.py # UserSettings
├── value_objects/
│   ├── __init__.py      # from .email import Email; from .phone import Phone
│   ├── email.py
│   └── phone.py
├── repositories.py      # Protocol은 보통 작으므로 파일 유지
└── services/
    ├── __init__.py      # from .auth import AuthDomainService
    ├── auth.py
    └── notification.py
```

### Router 진화

**Stage 1**: 단일 파일 → 역할별 분리

```
# BEFORE: 단일 router.py (CRUD + 특수 엔드포인트 15개+)
{domain}/
├── router.py            # 300줄+

# AFTER: 역할별 분리
{domain}/router/
├── __init__.py          # router = APIRouter(); router.include_router(...)
├── crud.py              # GET/POST/PUT/DELETE 기본 CRUD
├── auth.py              # 로그인/회원가입/토큰 관련
└── admin.py             # 관리자 전용 엔드포인트
```

**Stage 2**: 클라이언트별 분리 (admin/app/web)

한 도메인이 여러 클라이언트를 서비스할 때, 클라이언트별 라우터를 분리.

```
# 멀티 클라이언트: 같은 도메인, 다른 API
{domain}/router/
├── __init__.py
├── admin.py             # admin용 엔드포인트 (전체 CRUD + 통계)
├── app.py               # 모바일 앱용 (조회 + 제한된 수정)
└── web.py               # 웹 클라이언트용 (조회 중심)
```

```python
# {domain}/router/__init__.py
from fastapi import APIRouter
from core.util.versioning import admin, app, web

from .admin import router as admin_router
from .app import router as app_router
from .web import router as web_router

router = APIRouter()
router.include_router(admin_router)
router.include_router(app_router)
router.include_router(web_router)
```

```python
# {domain}/router/admin.py
from fastapi import APIRouter
from core.util.versioning import admin

router = APIRouter()
api = admin("user")

@router.get(api("/list"))              # /admin/v1/user/list
@router.get(api("/detail/{id}"))       # /admin/v1/user/detail/{id}
@router.post(api("/create"))           # /admin/v1/user/create
@router.delete(api("/delete/{id}"))    # /admin/v1/user/delete/{id}
@router.get(api("/stats"))             # /admin/v1/user/stats (admin 전용)
```

```python
# {domain}/router/app.py
from fastapi import APIRouter
from core.util.versioning import app

router = APIRouter()
api = app("user")

@router.get(api("/me"))                # /app/v1/user/me
@router.put(api("/me"))                # /app/v1/user/me (자기 정보 수정)
@router.get(api("/me", v=2))           # /app/v2/user/me (v2 응답 포맷)
```

**Stage 3**: 클라이언트 + 버전 분리 (대규모)

v1/v2 간 로직 차이가 큰 경우, 버전별로도 분리.

```
{domain}/router/
├── __init__.py
├── admin/
│   ├── __init__.py
│   ├── v1.py            # /admin/v1/user/*
│   └── v2.py            # /admin/v2/user/* (Breaking changes)
├── app/
│   ├── __init__.py
│   ├── v1.py            # /app/v1/user/*
│   └── v2.py            # /app/v2/user/*
└── web.py               # /web/v1/user/* (버전 하나면 파일 유지)
```

```python
# {domain}/router/admin/__init__.py
from fastapi import APIRouter
from .v1 import router as v1_router
from .v2 import router as v2_router

router = APIRouter()
router.include_router(v1_router)
router.include_router(v2_router)
```

```python
# {domain}/router/admin/v2.py
from fastapi import APIRouter
from core.util.versioning import admin

router = APIRouter()
api = admin("user", default_version=2)

@router.get(api("/list"))              # /admin/v2/user/list (새 응답 포맷)
@router.get(api("/analytics"))         # /admin/v2/user/analytics (v2 신규)
```

### Router 진화 판단 기준

| 상황 | 구조 |
|------|------|
| 단일 클라이언트, 엔드포인트 ≤10 | `router.py` 단일 파일 |
| 단일 클라이언트, 엔드포인트 10+ | `router/crud.py`, `router/auth.py` 역할별 |
| 멀티 클라이언트 (admin/app/web) | `router/admin.py`, `router/app.py`, `router/web.py` |
| 멀티 클라이언트 + 버전 차이 큼 | `router/admin/v1.py`, `router/admin/v2.py` |
| 버전 차이가 응답 포맷만 다름 | 파일 분리 대신 DTO 버저닝으로 처리 |

### DTO 진화

```
# BEFORE: 단일 dto.py
{domain}/
├── dto.py           # Request + Response + Internal 20개+

# AFTER: 폴더 분리
{domain}/dto/
├── __init__.py          # from .request import *; from .response import *
├── request.py           # CreateUserRequest, UpdateUserRequest
├── response.py          # UserResponse, UserListResponse
└── internal.py          # 서비스 간 전달용 DTO
```

### Application Service 진화

```
# BEFORE
{domain}/application/
├── service.py           # UserService (CRUD + Auth + Notification 300줄+)

# AFTER
{domain}/application/
├── __init__.py
├── user_service.py      # CRUD use cases
├── auth_service.py      # 인증/인가 use cases
└── notification_service.py
```

### Infrastructure 진화

```
# BEFORE
{domain}/infrastructure/
├── models.py
├── repository.py

# AFTER
{domain}/infrastructure/
├── models/
│   ├── __init__.py
│   ├── user.py          # UserModel
│   └── user_settings.py # UserSettingsModel
├── repository/
│   ├── __init__.py
│   ├── user_repository.py
│   └── user_cache_repository.py
└── external/             # 외부 서비스 어댑터
    ├── __init__.py
    ├── email_client.py
    └── s3_client.py
```

### Core 진화

```
# BEFORE
app/core/
├── config.py
├── database.py
├── security.py
├── exceptions.py
├── middleware.py

# AFTER
app/core/
├── config/
│   ├── __init__.py      # from .settings import get_settings, Settings
│   ├── settings.py      # 메인 Settings
│   ├── database.py      # DatabaseConfig
│   └── redis.py         # RedisConfig
├── database.py           # Engine, session (보통 비대해지지 않음)
├── security/
│   ├── __init__.py
│   ├── jwt.py
│   ├── password.py
│   └── permissions.py
├── exceptions/
│   ├── __init__.py      # from .base import *; from .handlers import *
│   ├── base.py          # AppException hierarchy
│   └── handlers.py      # register_exception_handlers()
└── middleware/
    ├── __init__.py
    ├── logging.py
    ├── auth.py
    └── rate_limit.py
```

### __init__.py Re-export 패턴

```python
# entities/__init__.py
from .user import User, UserProfile
from .user_settings import UserSettings

__all__ = ["User", "UserProfile", "UserSettings"]
```

```python
# router/__init__.py
from fastapi import APIRouter

from .crud import router as crud_router
from .auth import router as auth_router
from .admin import router as admin_router

router = APIRouter()
router.include_router(crud_router)
router.include_router(auth_router)
router.include_router(admin_router, prefix="/admin")
```

### 분리 판단 기준

| 조건 | 액션 |
|------|------|
| 파일 ≤200줄, 클래스 ≤2개 | 그대로 유지 |
| 파일 200-400줄, 클래스 3-5개 | 폴더 분리 고려 |
| 파일 400줄+, 클래스 5개+ | **반드시 분리** |
| 관심사가 명확히 구분됨 | 줄 수 무관하게 분리 |
| 단일 클래스가 거대 | 클래스 자체를 책임 분리 (SRP) |

## 레이어 책임

```
router.py                    → HTTP only. No business logic.
dto.py                       → Pydantic DTOs. from_domain() factory.
application/service.py       → Use case orchestration. Tx boundary. Event publish.
domain/entities.py           → Business rules enforced directly.
domain/repositories.py       → Protocol (Port). Knows nothing about DB.
infrastructure/repository.py → Protocol impl. Entity ↔ Model conversion.
```

## App Factory

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, lifespan=lifespan,
                  docs_url="/docs" if settings.debug else None)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(CORSMiddleware, ...)
    register_exception_handlers(app)
    app.include_router(users_router, prefix="/api/v1/users", tags=["Users"])
    return app
```

## Config (pydantic-settings)

```python
class Settings(BaseSettings):
    database: DatabaseConfig = DatabaseConfig()
    redis: RedisConfig = RedisConfig()
    jwt: JWTConfig = JWTConfig()
    model_config = {"env_file": f".env.{os.getenv('APP_ENV', 'local')}",
                    "env_nested_delimiter": "__"}  # DATABASE__HOST=prod-db
```

## DI 패턴 선택

```
services ≤5, no domain layer       → FastAPI Depends
domain layer + large               → Dishka (Protocol binding)
```

### FastAPI Depends (Default)
```python
def get_user_repository(db: AsyncSession = Depends(get_db)) -> SqlAlchemyUserRepository:
    return SqlAlchemyUserRepository(db)

def get_user_service(repo=Depends(get_user_repository), db=Depends(get_db)) -> UserApplicationService:
    return UserApplicationService(repo=repo, db=db)

# Singleton: @lru_cache + get_settings()
# Test: app.dependency_overrides[get_user_service] = lambda: mock
```


### Dishka (Large)
```python
class UserProvider(Provider):
    user_repository = provide(SqlAlchemyUserRepository, provides=UserRepository, scope=Scope.REQUEST)
router = APIRouter(route_class=DishkaRoute)
```

금지: dependency-injector (Cython 이슈, 단일 메인테이너)

## 도구 설정

### Ruff
```toml
[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = ["E","W","F","I","N","UP","SIM","B","A","C4","RET","PIE","TCH","RUF",
          "ASYNC","S","PT","T20","ARG","ERA","DTZ","G"]
ignore = ["S101","B008","RUF012"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101","ARG","S106"]
"migrations/**" = ["ERA"]
```

### mypy
```toml
[tool.mypy]
python_version = "3.12"
strict = true
plugins = ["pydantic.mypy", "sqlalchemy.ext.mypy.plugin"]

[[tool.mypy.overrides]]
module = ["cashews.*","apscheduler.*","celery.*"]
ignore_missing_imports = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

[[tool.mypy.overrides]]
module = ["app.*.domain.*"]  # Strictest
```

### import-linter
```ini
[importlinter:contract:domain-independence]
name = Domain must not import infrastructure
type = forbidden
source_modules = app.users.domain, app.orders.domain
forbidden_modules = app.core.database, sqlalchemy, fastapi, pydantic
```

### pre-commit
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks: [{id: ruff, args: [--fix]}, {id: ruff-format}]
  - repo: https://github.com/pre-commit/mirrors-mypy
    hooks: [{id: mypy, additional_dependencies: [pydantic, sqlalchemy[mypy]]}]
  - repo: local
    hooks: [{id: import-linter, entry: poetry run lint-imports, language: system}]
```
