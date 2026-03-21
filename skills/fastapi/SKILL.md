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

# FastAPI 스킬

**Python 3.13+ REQUIRED** -- 레거시 타입(`Optional`, `Union`, `List`, `Dict`) 금지. `X | None`, `list[X]` 사용.

---

## 1. 프로젝트 구조 (Folder-First)

controllers/, dto/, exceptions/, constants/는 **처음부터 폴더로 생성**. File->Package 진화 없음.

```
project-root/
├── pyproject.toml / poetry.lock / alembic.ini
├── app/
│   ├── main.py                        # App factory (create_app)
│   ├── core/
│   │   ├── config/                    # pydantic-settings (항상 폴더)
│   │   ├── database.py                # Engine, session, Base
│   │   ├── security/                  # JWT, password, RBAC
│   │   ├── exceptions/                # 애플리케이션 예외 (항상 폴더)
│   │   └── middleware/
│   ├── common/
│   │   ├── base_repository.py         # BaseRepository[ModelType] 제네릭
│   │   ├── base_dto.py                # CamelModel base
│   │   └── pagination.py
│   ├── {domain}/
│   │   ├── controllers/               # HTTP endpoints (항상 폴더)
│   │   ├── dto/                       # Pydantic DTOs (항상 폴더, 엔드포인트 1:1)
│   │   ├── constants/                 # 도메인 상수 (항상 폴더)
│   │   ├── exceptions/                # 도메인 예외 (항상 폴더)
│   │   ├── dependencies.py            # Depends() factories
│   │   ├── domain/                    # Pure business logic (ZERO framework imports)
│   │   ├── application/
│   │   │   └── service.py
│   │   └── infrastructure/
│   │       ├── models.py              # SQLAlchemy ORM
│   │       └── repository.py          # Protocol impl
└── tests/
```

### Folder-First 규칙

| 대상 | 규칙 |
|------|------|
| controllers/ | 처음부터 폴더. 클라이언트별 `{role}_controller.py` |
| dto/ | 처음부터 폴더. 엔드포인트별 파일 + common.py |
| exceptions/ | 처음부터 폴더. `domain.py` 하나로 시작 |
| constants/ | 처음부터 폴더. enums.py, messages.py, limits.py |
| domain/ 내부 | 파일로 시작 -> 200줄+/클래스 3개+ 시 폴더 분리 |

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

금지: dependency-injector (Cython 이슈, 단일 메인테이너)

> 상세 코드 예시는 references/di-patterns.md 참조

---

## 3. EndpointPath 헬퍼

**하드코딩된 경로 문자열 금지.** `/{client}/v{version}/{domain}/{action}` 패턴 사용.

```python
ep = EndpointPath("app", 1, "users")
# ep.root         -> "/app/v1/users"
# ep.action("me") -> "/app/v1/users/me"
```

> 전체 구현 및 사용 패턴은 references/endpoint-path.md 참조

---

## 4. Sub-Application

admin/app/web 분리, 클라이언트별 미들웨어/Swagger 독립 구성.

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

---

## 5. DTO (Pydantic v2) 핵심 규칙

> Pydantic v2 규칙 상세는 `/python-best-practices` 스킬을 따른다. FastAPI 고유 규칙만 명시.

- MUST: `CamelModel` 명칭 사용 (BaseSchema 금지), 모든 DTO 상속
- MUST: `ErrorBody` + `FieldError` 에러 응답 형식
- MUST: `from_domain()` factory 메서드로 도메인 엔티티 → DTO 변환

> 전체 코드 예시는 references/dto-examples.md 참조

---

## 6. 미들웨어 핵심 규칙

**MUST 등록 순서 (위에서 아래로 등록, LIFO):**

| 등록 순서 | 미들웨어 | 실행 순서 |
|-----------|---------|-----------|
| 1 (첫 등록) | RequestLoggingMiddleware | 3 (innermost) |
| 2 | RateLimitMiddleware | 2 |
| 3 (마지막 등록) | CORSMiddleware | 1 (outermost) |

**요청 흐름:** Client -> CORS -> RateLimit -> RequestLogging -> Route

**Decorator 순서:** `@log_execution` -> `@retry` -> `@transactional` (최내곽)

> 상세 코드 및 각 미들웨어 구현은 references/middleware-order.md 참조

---

## 7. 환경 설정 (pydantic-settings)

- `env_nested_delimiter="__"` 사용 (DB__HOST, REDIS__PORT 등)
- `Settings` 싱글톤: `@lru_cache(maxsize=1)` + `get_settings()`
- prod `model_validator`: debug=False, 실제 JWT secret, DB password 필수
- `.env.example` git 커밋, `.env` git-ignored

---

## 8. Async 패턴

- CPU-bound 작업: `run_in_threadpool` 사용
- 비동기 백그라운드: `BackgroundTasks`
- **금지:** async 함수 내 `time.sleep()`, `requests.get()`, `open().read()`
- **올바른:** `asyncio.sleep()`, `httpx.AsyncClient`, `aiofiles`

---

## 9. 도구 설정

- Ruff: `target-version = "py313"`, 포괄적 rule set
- mypy: `strict = true`, pydantic + sqlalchemy 플러그인
- import-linter: domain 순수성 계약, 도메인 간 독립성 계약
- pre-commit: ruff, mypy, import-linter, conventional-commits

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
