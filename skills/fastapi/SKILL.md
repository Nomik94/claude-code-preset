---
name: fastapi
description: |
  FastAPI 프로젝트 고유 설정 및 패턴 레퍼런스.
  Use when: 프로젝트 구조 잡기, 폴더 구조, 디렉토리 구조, 초기 세팅, 새 프로젝트 시작,
  파일 분리, 파일이 너무 커, 폴더로 변환, 파일 비대, 모듈 분리, 패키지 분리,
  DI 패턴 선택, 의존성 주입, Depends vs Container vs Dishka,
  Ruff 설정, mypy 설정, 린터 세팅, 포맷터 세팅, pre-commit 설정, import-linter,
  App Factory, create_app, lifespan, pydantic-settings, 환경변수 설정, config 구조,
  레이어 분리, controllers/service/repository 구조, 도메인 레이어 도입 기준.
  NOT for: 단순 FastAPI 문법 질문 (Claude가 이미 앎), 일반적인 Ruff/mypy 사용법.
---

# FastAPI 스킬

**Python 3.13+ REQUIRED** — 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지. `X | None`, `list[X]` 사용.

## 프로젝트 구조 (Folder-First)

controllers/, dto/, exceptions/, constants/는 **처음부터 폴더로 생성**. File→Package 진화 없음.

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
│   │   │   └── mappings.py           # 도메인 예외 → HTTP 매핑 테이블
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
│   │   ├── exceptions/                # 도메인 예외 (domain/ 밖)
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
| domain/ 내부 | 파일로 시작 → 200줄+/클래스 3개+ 시 폴더 분리 |
| infrastructure/ | 파일로 시작 → 비대 시 폴더 분리 |

> 폴더 분리 시 `__init__.py` re-export MUST. 외부 import 경로 변경 없어야 함.

## 레이어 책임

```
controllers/             → HTTP only. No business logic. EndpointPath 필수.
dto/                     → Pydantic DTOs. from_domain() factory. 엔드포인트 1:1.
application/service.py   → Use case orchestration. Tx boundary. Event publish.
domain/entities.py       → Business rules enforced directly. ZERO framework imports.
domain/repositories.py   → Protocol (Port). Knows nothing about DB.
infrastructure/repo.py   → Protocol impl. Entity <-> Model conversion.
exceptions/domain.py     → 순수 도메인 예외. HTTP 코드 없음.
constants/               → 도메인 상수. enums, messages, limits 분리.
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
    register_exception_handlers(app)  # mappings.py 기반
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(CORSMiddleware, ...)
    return app
```

## DI 패턴 선택

| 규모 | 패턴 | 기준 |
|------|------|------|
| 소규모 (도메인 ≤3) | FastAPI Depends | 기본 DI |
| 중규모 (도메인 4-9) | Manual DI + Container | 수동 팩토리 클래스 |
| 대규모 (도메인 10+) | Dishka | IoC 컨테이너 |

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

## 도구 설정

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

[[tool.mypy.overrides]]
module = ["app.*.domain.*"]  # Strictest
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

[importlinter:contract:core-independence]
name = Core must not import domains
type = forbidden
source_modules = app.core
forbidden_modules = app.users, app.orders
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

### 추가 품질 도구
```bash
vulture app/ --min-confidence 80   # 사용하지 않는 코드 감지
deptry .                           # 사용하지 않는 의존성 감지
pip-audit                          # 알려진 취약점 감지
```

## SQLAlchemy 관련

MUST: `relationship(lazy="raise")` 기본값 사용 — N+1 컴파일타임 방지. 상세는 `/sqlalchemy` 스킬 참조.

## 체크리스트

- [ ] controllers/ 폴더로 생성 (router.py 아님)
- [ ] SQLAlchemy relationship에 `lazy="raise"` 설정
- [ ] dto/ 폴더로 생성 (엔드포인트 1:1 매핑)
- [ ] exceptions/ 폴더로 생성 (domain.py 포함)
- [ ] constants/ 폴더로 생성 (enums.py, messages.py, limits.py)
- [ ] core/exceptions/mappings.py 존재
- [ ] EndpointPath 헬퍼 사용 (하드코딩 경로 금지)
- [ ] domain/에 framework import 없음
- [ ] import-linter 계약 통과
- [ ] Ruff target-version = "py313"
- [ ] Conventional Commits 사용
