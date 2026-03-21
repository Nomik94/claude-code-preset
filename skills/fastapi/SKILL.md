---
name: fastapi
description: |
  Use when FastAPI 프로젝트 구조, DI 패턴, EndpointPath, Sub-Application,
  DTO/Pydantic 스키마, 미들웨어, 환경 설정, Async 패턴 관련 작업.
  NOT for 단순 FastAPI 문법 질문, 일반 Ruff/mypy 사용법.
---

# FastAPI 스킬

**Python 3.13+ REQUIRED** -- 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지. `X | None`, `list[X]` 사용.

---

## 1. 프로젝트 구조 (Folder-First)

controllers/, dto/, exceptions/, constants/는 **처음부터 폴더로 생성**. File->Package 진화 없음.

```
project-root/
├── pyproject.toml / poetry.lock / alembic.ini
├── .pre-commit-config.yaml / .importlinter
├── migrations/
│   ├── env.py
│   └── versions/
├── app/
│   ├── main.py                        # App factory (create_app)
│   ├── core/
│   │   ├── config/                    # pydantic-settings (항상 폴더)
│   │   │   ├── __init__.py
│   │   │   ├── settings.py
│   │   │   ├── database.py
│   │   │   └── redis.py
│   │   ├── database.py                # Engine, session, Base
│   │   ├── security/                  # JWT, password, RBAC
│   │   │   ├── __init__.py
│   │   │   ├── jwt.py
│   │   │   ├── password.py
│   │   │   └── rbac.py
│   │   ├── exceptions/                # 애플리케이션 예외 (항상 폴더)
│   │   │   ├── __init__.py
│   │   │   ├── base.py               # AppException hierarchy
│   │   │   ├── handlers.py           # register_exception_handlers()
│   │   │   └── mappings.py           # 도메인 예외 -> HTTP 매핑 테이블
│   │   └── middleware/
│   │       ├── __init__.py
│   │       ├── logging.py
│   │       └── rate_limit.py
│   ├── common/
│   │   ├── base_repository.py         # BaseRepository[ModelType] 제네릭
│   │   ├── base_dto.py                # CamelModel base
│   │   ├── pagination.py
│   │   ├── types.py
│   │   └── decorators.py             # @transactional, @retry, @log_execution
│   ├── {domain}/
│   │   ├── controllers/               # HTTP endpoints (항상 폴더)
│   │   │   ├── __init__.py
│   │   │   ├── admin_controller.py    # admin 클라이언트용
│   │   │   ├── app_controller.py      # 모바일 앱용
│   │   │   └── web_controller.py      # 웹 클라이언트용
│   │   ├── dto/                       # Pydantic DTOs (항상 폴더, 엔드포인트 1:1)
│   │   │   ├── __init__.py
│   │   │   ├── create_user.py         # CreateUserRequest, CreateUserResponse
│   │   │   ├── update_user.py
│   │   │   ├── list_users.py
│   │   │   └── common.py             # 공유 DTO (UserBase 등)
│   │   ├── constants/                 # 도메인 상수 (항상 폴더)
│   │   │   ├── __init__.py
│   │   │   ├── enums.py
│   │   │   ├── messages.py
│   │   │   └── limits.py
│   │   ├── exceptions/                # 도메인 예외 (항상 폴더)
│   │   │   ├── __init__.py
│   │   │   └── domain.py             # 순수 도메인 예외
│   │   ├── dependencies.py            # Depends() factories
│   │   ├── domain/                    # Pure business logic (ZERO framework imports)
│   │   │   ├── entities.py
│   │   │   ├── value_objects.py
│   │   │   ├── services.py
│   │   │   ├── repositories.py        # Protocol interfaces (Ports)
│   │   │   └── events.py
│   │   ├── application/
│   │   │   └── service.py
│   │   └── infrastructure/
│   │       ├── models.py              # SQLAlchemy ORM
│   │       └── repository.py          # Protocol impl
└── tests/
    ├── conftest.py
    ├── unit/{domain}/
    └── integration/
```

### Folder-First 규칙

| 대상 | 규칙 |
|------|------|
| controllers/ | 처음부터 폴더. 클라이언트별 `{role}_controller.py` |
| dto/ | 처음부터 폴더. 엔드포인트별 파일 + common.py |
| exceptions/ | 처음부터 폴더. `domain.py` 하나로 시작 |
| constants/ | 처음부터 폴더. enums.py, messages.py, limits.py |
| domain/ 내부 | 파일로 시작 -> 200줄+/클래스 3개+ 시 폴더 분리 |
| infrastructure/ | 파일로 시작 -> 비대 시 폴더 분리 |

> 폴더 분리 시 `__init__.py` re-export MUST. 외부 import 경로 변경 없어야 함.

### 레이어 책임

```
controllers/             -> HTTP only. No business logic. EndpointPath 필수.
dto/                     -> Pydantic DTOs. from_domain() factory. 엔드포인트 1:1.
application/service.py   -> Use case orchestration. Tx boundary. Event publish.
domain/entities.py       -> Business rules enforced directly. ZERO framework imports.
domain/repositories.py   -> Protocol (Port). Knows nothing about DB.
infrastructure/repo.py   -> Protocol impl. Entity <-> Model conversion.
exceptions/domain.py     -> 순수 도메인 예외. HTTP 코드 없음.
constants/               -> 도메인 상수. enums, messages, limits 분리.
```

---

## 2. DI 패턴 선택

| 규모 | 패턴 | 기준 |
|------|------|------|
| 소규모 (도메인 3개 이하) | FastAPI Depends | 기본 DI |
| 중규모 (도메인 4-9개) | Manual DI + Container | 수동 팩토리 클래스 |
| 대규모 (도메인 10개 이상) | Dishka | IoC 컨테이너 |

### FastAPI Depends (Default)

```python
def get_user_repository(db: AsyncSession = Depends(get_db)) -> SqlAlchemyUserRepository:
    return SqlAlchemyUserRepository(db)

def get_user_service(repo=Depends(get_user_repository), db=Depends(get_db)) -> UserApplicationService:
    return UserApplicationService(repo=repo, db=db)
```

### Manual DI + Container (Medium)

```python
class Container:
    def __init__(self, db: AsyncSession) -> None:
        self.user_repo = SqlAlchemyUserRepository(db)
        self.user_service = UserApplicationService(repo=self.user_repo, db=db)

async def get_container(db: AsyncSession = Depends(get_db)) -> Container:
    return Container(db)
```

### Dishka (Large)

```python
class UserProvider(Provider):
    user_repository = provide(SqlAlchemyUserRepository, provides=UserRepository, scope=Scope.REQUEST)
router = APIRouter(route_class=DishkaRoute)
```

금지: dependency-injector (Cython 이슈, 단일 메인테이너)

---

## 3. EndpointPath 헬퍼

**하드코딩된 경로 문자열 금지.** `/{client}/v{version}/{domain}/{action}` 패턴 사용.

```python
class EndpointPath:
    def __init__(self, client: str, version: int, domain: str) -> None:
        self.base = f"/{client}/v{version}/{domain}"

    def action(self, name: str) -> str:
        return f"{self.base}/{name}"

    @property
    def root(self) -> str:
        return self.base

# 사용 예시
ep = EndpointPath("app", 1, "users")
# ep.root         -> "/app/v1/users"
# ep.action("me") -> "/app/v1/users/me"
```

---

## 4. Sub-Application

admin/app/web 분리, 클라이언트별 미들웨어/Swagger 독립 구성.

```python
def create_app() -> FastAPI:
    root_app = FastAPI()

    admin_app = FastAPI(title="Admin API", docs_url="/docs")
    client_app = FastAPI(title="Client API", docs_url="/docs")
    web_app = FastAPI(title="Web API", docs_url="/docs")

    # 공통 미들웨어는 root에 등록
    setup_middleware(root_app, settings)

    # sub-app별 인증 미들웨어
    admin_app.add_middleware(AdminAuthMiddleware)
    client_app.add_middleware(JWTAuthMiddleware)

    root_app.mount("/admin", admin_app)
    root_app.mount("/app", client_app)
    root_app.mount("/web", web_app)
    return root_app
```

### App Factory

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield

def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, lifespan=lifespan,
                  docs_url="/docs" if settings.debug else None)
    register_exception_handlers(app)  # mappings.py 기반
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(CORSMiddleware, ...)
    return app
```

---

## 5. DTO (Pydantic v2)

### CamelModel (Base DTO)

모든 DTO가 상속하는 기반 클래스. 이름은 반드시 `CamelModel`.

```python
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

class CamelModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        alias_generator=to_camel,
    )
```

- MUST: `CamelModel` 명칭 사용 (BaseSchema 금지)
- MUST: 모든 DTO는 CamelModel 상속
- MUST: `from_attributes=True` (ORM 변환용)

### dto/ 폴더 구조

```
{domain}/dto/
  __init__.py          # re-export all DTOs
  create_user.py       # CreateUserRequest, CreateUserResponse
  update_user.py       # UpdateUserRequest
  list_users.py        # ListUsersRequest (query params), UserListItem
  get_user.py          # UserDetailResponse
  common.py            # 공유 nested schemas (AddressResponse 등)
```

### Request/Response 패턴

```python
# dto/create_user.py
class CreateUserRequest(CamelModel):
    email: str
    name: str
    password: str
    password_confirm: str

# dto/update_user.py -- partial update
class UpdateUserRequest(CamelModel):
    email: str | None = None
    name: str | None = None
    phone: str | None = None

    def apply_simple_fields(self, entity: UserEntity) -> None:
        """Partial update 헬퍼. model_fields_set 기반."""
        for field_name in self.model_fields_set:
            setattr(entity, field_name, getattr(self, field_name))

# dto/get_user.py
class UserDetailResponse(CamelModel):
    id: int
    email: str
    name: str
    role: UserRole
    is_active: bool
    created_at: datetime

    @classmethod
    def from_domain(cls, entity: "UserEntity") -> Self:
        return cls(
            id=entity.id,
            email=entity.email.value,
            name=entity.name,
            role=entity.role,
            is_active=entity.is_active,
            created_at=entity.created_at,
        )
```

### 페이지네이션

```python
T = TypeVar("T", bound=BaseModel)

class PaginatedResponse(CamelModel, Generic[T]):
    items: Sequence[T]
    total: int
    page: int
    size: int

    @computed_field  # type: ignore[prop-decorator]
    @property
    def total_pages(self) -> int:
        return (self.total + self.size - 1) // self.size if self.size > 0 else 0

    @computed_field  # type: ignore[prop-decorator]
    @property
    def has_next(self) -> bool:
        return self.page < self.total_pages
```

### ErrorBody

통일된 에러 응답 구조. 이름은 반드시 `ErrorBody` + `FieldError`.

```python
class FieldError(CamelModel):
    field: str
    message: str

class ErrorBody(CamelModel):
    code: str              # "VALIDATION_ERROR", "NOT_FOUND", "CONFLICT"
    message: str           # human-readable summary
    errors: list[FieldError] = []
```

- MUST: `ErrorBody` 명칭 사용 (ErrorResponse, ErrorDetail 금지)
- MUST: `errors` 필드명 사용 (details 금지)

### Validators

```python
class CreateUserRequest(CamelModel):
    email: str
    password: str
    password_confirm: str

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        if not re.match(r"^[\w.+-]+@[\w-]+\.[\w.]+$", v):
            raise ValueError("Invalid email format")
        return v.lower().strip()

    @model_validator(mode="after")
    def validate_passwords_match(self) -> Self:
        if self.password != self.password_confirm:
            raise ValueError("Passwords do not match")
        return self
```

- MUST: `field_validator` / `model_validator` 사용 (`@validator` 금지)
- MUST: `model_validator(mode="after")` 반환 타입은 `Self`

### 직렬화 Quick Reference

| Operation | Code |
|-----------|------|
| ORM -> DTO | `UserDetailResponse.model_validate(db_user)` |
| Entity -> DTO | `UserDetailResponse.from_domain(entity)` |
| DTO -> dict (camel) | `dto.model_dump(by_alias=True, exclude_none=True)` |
| DTO -> JSON string | `dto.model_dump_json(by_alias=True)` |

---

## 6. 미들웨어

### 실행 순서 (LIFO)

`app.add_middleware()`는 REVERSE order(LIFO)로 실행. 마지막 등록이 가장 먼저 실행.

**MUST 등록 순서 (위에서 아래로 등록):**

| 등록 순서 | 미들웨어 | 실행 순서 | 역할 |
|-----------|---------|-----------|------|
| 1 (첫 등록) | RequestLoggingMiddleware | 3 (innermost) | 정확한 타이밍 측정 |
| 2 | RateLimitMiddleware | 2 | CORS 통과 후 제한 |
| 3 (마지막 등록) | CORSMiddleware | 1 (outermost) | preflight 가장 먼저 처리 |

```python
def setup_middleware(app: FastAPI, settings: Settings) -> None:
    # 등록: 안쪽 -> 바깥쪽 (실행은 역순)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(RateLimitMiddleware, max_requests=100, window_seconds=60)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )
```

**요청 흐름:** Client -> CORS -> RateLimit -> RequestLogging -> Route -> (역순 응답)

### RequestLoggingMiddleware

MUST 포함 항목:
- X-Request-ID: 헤더에 있으면 재사용, 없으면 uuid4 생성
- structlog contextvars binding (request_id, method, path)
- 로그 필드: method, path, status_code, duration_ms, client_ip
- 응답 헤더에 X-Request-ID 포함
- `structlog.contextvars.clear_contextvars()` 호출로 이전 요청 컨텍스트 제거
- `time.perf_counter()`로 정밀 측정

### Rate Limiting

| 환경 | 구현 | 비고 |
|------|------|------|
| dev/local | In-memory (dict + sliding window) | 단일 프로세스용 |
| production | Redis (INCR + EXPIRE) | 멀티 인스턴스 대응 |

- MUST: IP 기반 제한 (`request.client.host`)
- MUST: 429 응답 시 `Retry-After` 헤더 포함

### CORS 설정

- MUST: `allow_origins=["*"]` + `allow_credentials=True` 조합은 prod에서 **절대 금지**
- 환경별 origins 분리 (settings에서 관리)

| 환경 | allow_origins | allow_credentials |
|------|--------------|-------------------|
| local/dev | localhost 명시 목록 | True |
| staging | 스테이징 도메인 목록 | True |
| prod | 프로덕션 도메인 목록 | True |

### Sub-Application 미들웨어

- 공통 미들웨어(CORS, Logging)는 root app에 등록
- 인증 미들웨어는 sub-app 레벨에서 등록 (admin/app 각각 다른 인증)

### Cross-Cutting Decorators

비즈니스 로직의 횡단 관심사를 decorator로 분리.

```python
@log_execution      # 1. 최외곽: 전체 실행 로깅 (진입/종료/에러)
@retry              # 2. 중간: 재시도 (에러 시 반복)
@transactional      # 3. 최내곽: 트랜잭션 (commit/rollback)
async def create_order(self, command: CreateOrderCommand) -> Order:
    ...
```

| Decorator | 역할 | 위치 |
|-----------|------|------|
| `@log_execution` | 함수 진입/종료/에러 로깅, 실행 시간 측정 | 최외곽 |
| `@retry` | 일시적 에러 시 재시도 (max_attempts, backoff) | 중간 |
| `@transactional` | AsyncSession commit/rollback 관리 | 최내곽 |

- MUST: `@transactional`은 항상 가장 안쪽 (함수 바로 위)
- MUST: `functools.wraps` 사용 필수

---

## 7. 환경 설정 (pydantic-settings)

### Settings 클래스

```python
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class DatabaseSettings(BaseSettings):
    host: str = "localhost"
    port: int = 5432
    user: str = "postgres"
    password: str = ""
    name: str = "app"

    @property
    def url(self) -> str:
        return f"postgresql+asyncpg://{self.user}:{self.password}@{self.host}:{self.port}/{self.name}"

class RedisSettings(BaseSettings):
    host: str = "localhost"
    port: int = 6379
    db: int = 0

    @property
    def url(self) -> str:
        return f"redis://{self.host}:{self.port}/{self.db}"

class JWTSettings(BaseSettings):
    secret_key: str = "CHANGE-ME"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
```

### Root Settings (중첩 서브모델)

```python
from typing import Literal
from functools import lru_cache

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", f".env.{os.getenv('APP_ENV', 'local')}"),
        env_file_encoding="utf-8",
        env_nested_delimiter="__",
        extra="ignore",
    )

    app_name: str = "my-app"
    env: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = False
    log_level: str = "INFO"

    db: DatabaseSettings = DatabaseSettings()
    redis: RedisSettings = RedisSettings()
    jwt: JWTSettings = JWTSettings()

    @model_validator(mode="after")
    def validate_production(self) -> Self:
        if self.env == "prod":
            assert not self.debug, "debug must be False in prod"
            assert self.jwt.secret_key != "CHANGE-ME", "Set a real JWT secret"
            assert self.db.password, "DB password required in prod"
        return self
```

### Settings 팩토리 (싱글톤)

```python
@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
```

### 환경 파일 구조

```
project/
  .env              # local development (git-ignored)
  .env.example      # template committed to git
  .env.dev          # dev server overrides
  .env.staging      # staging overrides
  .env.prod         # prod overrides (or use secrets manager)
```

### .env.example (git에 커밋)

```bash
APP_NAME=my-app
ENV=local
DEBUG=true
LOG_LEVEL=INFO
DB__HOST=localhost
DB__PORT=5432
DB__USER=postgres
DB__PASSWORD=
DB__NAME=app
REDIS__HOST=localhost
REDIS__PORT=6379
JWT__SECRET_KEY=CHANGE-ME
JWT__ALGORITHM=HS256
JWT__ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT__REFRESH_TOKEN_EXPIRE_DAYS=7
```

---

## 8. Async 패턴

### run_in_threadpool

CPU-bound 또는 sync 라이브러리 호출 시 사용.

```python
from starlette.concurrency import run_in_threadpool

async def resize_image(image: bytes) -> bytes:
    return await run_in_threadpool(sync_resize, image)
```

### BackgroundTasks

```python
from fastapi import BackgroundTasks

@router.post("/users")
async def create_user(request: CreateUserRequest, bg: BackgroundTasks):
    user = await user_service.create(request)
    bg.add_task(send_welcome_email, user.email)
    return user
```

### 안티패턴 (sync in async)

```python
# 금지: async 함수 내에서 sync 블로킹 호출
async def bad_example():
    time.sleep(5)           # 이벤트 루프 블로킹
    requests.get("...")     # httpx.AsyncClient 사용할 것
    open("file").read()     # aiofiles 사용할 것

# 올바른 패턴
async def good_example():
    await asyncio.sleep(5)
    async with httpx.AsyncClient() as client:
        await client.get("...")
    async with aiofiles.open("file") as f:
        await f.read()
```

---

## 9. 도구 설정

### Ruff

```toml
[tool.ruff]
target-version = "py313"
line-length = 120

[tool.ruff.lint]
select = ["E","W","F","I","N","UP","SIM","B","A","C4","RET","PIE","TCH","RUF",
          "ASYNC","S","PT","T20","ARG","ERA","DTZ","G","ANN","TID"]
ignore = ["S101","B008","RUF012","ANN101","ANN102"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101","ARG","S106","ANN"]
"migrations/**" = ["ERA","ANN"]
```

### mypy

```toml
[tool.mypy]
python_version = "3.13"
strict = true
plugins = ["pydantic.mypy", "sqlalchemy.ext.mypy.plugin"]

[[tool.mypy.overrides]]
module = ["cashews.*","apscheduler.*","celery.*"]
ignore_missing_imports = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false
```

### import-linter

```ini
[importlinter:contract:domain-clean]
name = Domain layer must be pure
type = forbidden
source_modules = app.users.domain, app.orders.domain
forbidden_modules = fastapi, sqlalchemy, pydantic, httpx, redis

[importlinter:contract:domain-independence]
name = Domains must not import each other
type = independence
modules = app.users.domain, app.orders.domain
```

### pre-commit

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks: [{id: ruff, args: [--fix]}, {id: ruff-format}]
  - repo: https://github.com/pre-commit/mirrors-mypy
    hooks: [{id: mypy, additional_dependencies: [pydantic, sqlalchemy[mypy]]}]
  - repo: local
    hooks:
      - {id: import-linter, entry: poetry run lint-imports, language: system}
      - {id: conventional-commits, entry: scripts/check_commit_msg.sh, language: script, stages: [commit-msg]}
```

---

## 체크리스트

- [ ] controllers/ 폴더로 생성 (router.py 아님)
- [ ] dto/ 폴더로 생성 (엔드포인트 1:1 매핑, CamelModel 상속)
- [ ] exceptions/ 폴더로 생성 (domain.py 포함)
- [ ] constants/ 폴더로 생성 (enums.py, messages.py, limits.py)
- [ ] EndpointPath 헬퍼 사용 (하드코딩 경로 금지)
- [ ] domain/에 framework import 없음
- [ ] 미들웨어 등록 순서 LIFO 준수 (CORS 마지막 등록)
- [ ] Decorator 순서: @log_execution -> @retry -> @transactional
- [ ] ErrorBody + FieldError 에러 응답 형식
- [ ] Pydantic v2: model_config, model_dump(), field_validator
- [ ] pydantic-settings + env_nested_delimiter
- [ ] Ruff target-version = "py313"
- [ ] import-linter 계약 통과
- [ ] SQLAlchemy relationship에 `lazy="raise"` 설정
