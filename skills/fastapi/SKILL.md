---
name: fastapi
description: |
  Use when FastAPI 프로젝트 구조, DI 패턴, EndpointPath, Sub-Application,
  DTO/Pydantic 스키마, 미들웨어, 환경 설정, Async 패턴 관련 작업.
  NOT for 단순 FastAPI 문법 질문, 일반 Ruff/mypy 사용법.
files:
  - references/endpoint-path.md
  - references/di-patterns.md
  - references/dto-examples.md
  - references/middleware-order.md
---

# FastAPI

**Python 3.13+ REQUIRED** -- `X | None`, `list[X]` 사용. 레거시 타입 금지.

## 1. 프로젝트 구조 (Folder-First)

controllers/, dto/, exceptions/, constants/는 **처음부터 폴더로 생성**. File->Package 진화 없음.

```
project-root/
├── pyproject.toml / poetry.lock / alembic.ini
├── app/
│   ├── main.py                        # App factory (create_app)
│   ├── core/
│   │   ├── config/                    # pydantic-settings
│   │   ├── database.py                # Engine, session, Base
│   │   ├── security/                  # JWT, password, RBAC
│   │   ├── exceptions/                # 앱 예외
│   │   └── middleware/
│   ├── common/
│   │   ├── base_repository.py         # BaseRepository[ModelType]
│   │   ├── base_dto.py                # CamelModel base
│   │   └── pagination.py
│   ├── {domain}/
│   │   ├── controllers/               # HTTP endpoints
│   │   ├── dto/                       # Pydantic DTOs (엔드포인트 1:1)
│   │   ├── constants/                 # enums, messages, limits
│   │   ├── exceptions/                # 도메인 예외
│   │   ├── dependencies.py            # Depends() factories
│   │   ├── domain/                    # Pure business logic (ZERO framework imports)
│   │   ├── application/service.py
│   │   └── infrastructure/
│   │       ├── models.py              # SQLAlchemy ORM
│   │       └── repository.py
└── tests/
```

### Folder-First 규칙

| 대상 | 규칙 |
|------|------|
| controllers/ | 처음부터 폴더. 클라이언트별 `{role}_controller.py` |
| dto/ | 처음부터 폴더. 엔드포인트별 파일 + common.py |
| exceptions/ | 처음부터 폴더. `domain.py` 시작 |
| constants/ | 처음부터 폴더. enums/messages/limits 분리 |
| domain/ 내부 | 파일 시작 -> 200줄+/클래스 3개+ 시 폴더 분리 |

> 폴더 분리 시 `__init__.py` re-export MUST. 외부 import 경로 불변.

### 레이어 책임

```
controllers/             -> HTTP only. EndpointPath 필수.
dto/                     -> Pydantic DTOs. from_domain() factory. 엔드포인트 1:1.
application/service.py   -> Use case. Tx boundary. Event publish.
domain/entities.py       -> Business rules. ZERO framework imports.
domain/repositories.py   -> Protocol (Port).
infrastructure/repo.py   -> Protocol impl. Entity <-> Model 변환.
exceptions/domain.py     -> 순수 도메인 예외. HTTP 코드 없음.
constants/               -> enums, messages, limits 분리.
```

## 2. DI 패턴

| 규모 | 패턴 | 기준 |
|------|------|------|
| 소 (도메인 3개 이하) | FastAPI Depends | 기본 |
| 중 (4-9개) | Manual DI + Container | 수동 팩토리 |
| 대 (10개+) | Dishka | IoC 컨테이너 |

금지: dependency-injector (Cython 이슈)

> 상세 → references/di-patterns.md

## 3. EndpointPath

**하드코딩 경로 금지.** `/{client}/v{version}/{domain}/{action}` 패턴.

```python
ep = EndpointPath("app", 1, "users")
# ep.root -> "/app/v1/users"  /  ep.action("me") -> "/app/v1/users/me"
```

> 전체 → references/endpoint-path.md

## 4. Sub-Application

클라이언트별 미들웨어/Swagger 독립 구성.

```python
def create_app() -> FastAPI:
    root_app = FastAPI()
    admin_app = FastAPI(title="Admin API", docs_url="/docs")
    client_app = FastAPI(title="Client API", docs_url="/docs")
    web_app = FastAPI(title="Web API", docs_url="/docs")
    setup_middleware(root_app, settings)
    admin_app.add_middleware(AdminAuthMiddleware)
    client_app.add_middleware(JWTAuthMiddleware)
    root_app.mount("/admin", admin_app)
    root_app.mount("/app", client_app)
    root_app.mount("/web", web_app)
    return root_app
```

## 5. DTO (Pydantic v2)

> Pydantic v2 상세는 `/python-best-practices`. FastAPI 고유만 명시.

- `CamelModel` 사용 (BaseSchema 금지), 모든 DTO 상속
- `ErrorBody` + `FieldError` 에러 응답 형식
- `from_domain()` factory로 도메인 엔티티 -> DTO 변환

> 코드 예시 → references/dto-examples.md

## 6. 미들웨어

**등록 순서 (LIFO):**

| 등록 순서 | 미들웨어 | 실행 순서 |
|-----------|---------|-----------|
| 1 (첫 등록) | RequestLogging | 3 (innermost) |
| 2 | RateLimit | 2 |
| 3 (마지막) | CORS | 1 (outermost) |

**Decorator 순서:** `@log_execution` -> `@retry` -> `@transactional` (최내곽)

> 상세 → references/middleware-order.md

## 7. 환경 설정

- `env_nested_delimiter="__"` (DB__HOST 등)
- Settings 싱글톤: `@lru_cache(maxsize=1)` + `get_settings()`
- prod `model_validator`: debug=False, 실제 JWT secret, DB password 필수
- `.env.example` 커밋, `.env` git-ignored

## 8. Async 패턴

- CPU-bound: `run_in_threadpool`
- 비동기 백그라운드: `BackgroundTasks`
- **금지:** async 내 `time.sleep()`, `requests.get()`, `open().read()`
- **올바른:** `asyncio.sleep()`, `httpx.AsyncClient`, `aiofiles`

## 9. 도구 설정

- Ruff: `target-version = "py313"`, 포괄적 rule set
- mypy: `strict = true`, pydantic + sqlalchemy 플러그인
- import-linter: domain 순수성/독립성 계약
- pre-commit: ruff, mypy, import-linter, conventional-commits

## 체크리스트

- [ ] controllers/ dto/ exceptions/ constants/ 폴더로 생성
- [ ] EndpointPath 사용 (하드코딩 금지)
- [ ] domain/에 framework import 없음
- [ ] 미들웨어 LIFO 순서 (CORS 마지막 등록)
- [ ] Decorator: @log_execution -> @retry -> @transactional
- [ ] ErrorBody + FieldError 에러 형식
- [ ] Pydantic v2: ConfigDict, model_dump(), field_validator
- [ ] pydantic-settings + env_nested_delimiter
- [ ] Ruff py313, import-linter 통과
- [ ] relationship `lazy="raise"`
