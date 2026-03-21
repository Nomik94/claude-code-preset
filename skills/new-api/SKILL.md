---
name: new-api
description: |
  Use when creating a new API endpoint, resource, or CRUD feature in FastAPI.
  NOT for modifying existing endpoints or debugging API issues.
---

# /new-api — FastAPI 엔드포인트 스캐폴딩

## 목적

새로운 API 리소스(엔드포인트)를 생성할 때 사용한다. controllers → service → repository 레이어 전체를 한 번에 스캐폴딩하여 일관된 구조를 보장한다.

## 입력

| 파라미터 | 필수 | 설명 | 예시 |
|----------|------|------|------|
| 리소스 이름 | O | 도메인 리소스 (단수 snake_case) | `user`, `product`, `order_item` |
| CRUD 범위 | O | 생성할 엔드포인트 선택 | `CRUD`, `CR`, `RU`, `R` 등 |
| 클라이언트 | X | sub-application 구분 | `app`, `admin`, `web` (기본: `app`) |
| API 버전 | X | 버전 번호 | `1` (기본값) |

## 생성 파일 목록

```
{project_root}/
├── controllers/{resource}/
│   ├── __init__.py
│   └── {resource}_controller.py    # 라우터, 엔드포인트
├── dto/{resource}/
│   ├── __init__.py
│   ├── {resource}_request.py       # 요청 스키마
│   └── {resource}_response.py      # 응답 스키마
├── services/
│   └── {resource}_service.py       # 비즈니스 로직
├── repositories/
│   └── {resource}_repository.py    # 데이터 접근 계층
└── tests/test_{resource}/
    ├── __init__.py
    ├── test_{resource}_service.py   # 유닛 테스트
    └── test_{resource}_api.py       # 통합 테스트 (httpx)
```

## 생성 순서

반드시 아래 순서대로 생성한다. 의존성 방향(하위 → 상위)을 따른다.

1. **DTO** — 요청/응답 스키마 먼저 정의 (Pydantic v2)
2. **Repository** — 데이터 접근 계층 (AsyncSession, lazy="raise")
3. **Service** — 비즈니스 로직 (Repository 주입)
4. **Controller** — 라우터 + 엔드포인트 (EndpointPath 헬퍼)
5. **Tests** — 유닛 + 통합 테스트

## 적용 규칙

### 필수 준수 사항
- **Folder-First**: `controllers/`, `dto/` 는 반드시 폴더로 생성 (단일 파일 금지)
- **EndpointPath 헬퍼**: 컨트롤러에서 하드코딩된 경로 문자열 금지
- **lazy="raise"**: 모든 relationship의 기본값, N+1 컴파일타임 방지
- **Pydantic v2**: `model_config = ConfigDict(...)`, `model_dump()`, `field_validator`
- **Async**: 모든 DB 작업은 `AsyncSession` 사용
- **Python 3.13+ 문법**: `X | None` (Optional 금지), `list[X]` (List 금지), `StrEnum`

### 네이밍 규칙
- 파일명: `snake_case` (예: `user_service.py`)
- 클래스: `PascalCase` (예: `UserService`)
- API JSON 필드: `camelCase` (예: `createdAt`)
- URL 경로: `kebab-case` (예: `/api/v1/user-stats`)
- 상수: `SCREAMING_SNAKE_CASE` (예: `MAX_PAGE_SIZE`)

### API 경로 패턴
```
/{client}/v{version}/{domain}/{action}
```
EndpointPath 헬퍼를 사용하여 경로를 구성한다.

### DTO 구조
- `{Resource}CreateRequest` — 생성 요청
- `{Resource}UpdateRequest` — 수정 요청
- `{Resource}Response` — 단일 응답
- `{Resource}ListResponse` — 목록 응답 (페이지네이션 포함)

### 테스트 구조
- **유닛 테스트**: Service 레이어, mock repository
- **통합 테스트**: httpx.AsyncClient, 실제 DB (테스트 컨테이너 또는 SQLite)
- `pytest-asyncio` + `httpx` 사용

## 템플릿 참조

`skills/new-api/templates/` 디렉토리의 `.tmpl` 파일을 참조하여 보일러플레이트를 생성한다.

| 템플릿 | 용도 |
|--------|------|
| `controller.py.tmpl` | 컨트롤러 (라우터 + 엔드포인트) |
| `dto.py.tmpl` | 요청/응답 DTO |
| `service.py.tmpl` | 서비스 레이어 |
| `repository.py.tmpl` | 리포지토리 레이어 |
| `test_api.py.tmpl` | 통합 테스트 |

플레이스홀더:
- `{resource}` — snake_case (예: `order_item`)
- `{Resource}` — PascalCase (예: `OrderItem`)
- `{RESOURCE}` — SCREAMING_SNAKE (예: `ORDER_ITEM`)

## 완료 후 체크리스트

- [ ] 모든 파일에 `__init__.py` 존재
- [ ] DTO가 Pydantic v2 규칙 준수 (`ConfigDict`, `model_dump`)
- [ ] Repository가 `AsyncSession` 사용
- [ ] Controller에 하드코딩된 경로 없음 (EndpointPath 사용)
- [ ] 타입 힌트 완전 (mypy strict 통과 가능)
- [ ] 테스트 파일 존재 및 기본 케이스 포함
- [ ] `ruff check` 통과
- [ ] `mypy --strict` 통과
