---
name: new-api
description: |
  Use when creating a new API endpoint, resource, or CRUD feature in FastAPI.
  NOT for modifying existing endpoints or debugging API issues.
---

# /new-api -- FastAPI 엔드포인트 스캐폴딩

controllers → service → repository 전체를 한 번에 스캐폴딩.

## 입력

| 파라미터 | 필수 | 설명 | 예시 |
|----------|------|------|------|
| 리소스 이름 | O | 단수 snake_case | `user`, `order_item` |
| CRUD 범위 | O | 생성할 엔드포인트 | `CRUD`, `CR`, `RU`, `R` |
| 클라이언트 | X | sub-app 구분 (기본: `app`) | `app`, `admin`, `web` |
| API 버전 | X | 버전 (기본: `1`) | `1` |

## 생성 파일

```
controllers/{resource}/{resource}_controller.py
dto/{resource}/{resource}_request.py, {resource}_response.py
services/{resource}_service.py
repositories/{resource}_repository.py
tests/test_{resource}/test_{resource}_service.py, test_{resource}_api.py
```

## 생성 순서 (의존성 방향: 하위→상위)

1. **DTO** -- Pydantic v2 스키마
2. **Repository** -- AsyncSession, lazy="raise"
3. **Service** -- Repository 주입
4. **Controller** -- EndpointPath 헬퍼
5. **Tests** -- 유닛 + 통합

## 필수 규칙

- **Folder-First**: controllers/, dto/ 폴더 생성 (단일 파일 금지)
- **EndpointPath**: 하드코딩 경로 금지
- **lazy="raise"**: relationship 기본값
- **Pydantic v2**: ConfigDict, model_dump(), field_validator
- **Async**: 모든 DB에 AsyncSession
- **Python 3.13+**: `X | None`, `list[X]`, `StrEnum`

### 네이밍
- 파일: snake_case / 클래스: PascalCase / JSON: camelCase / URL: kebab-case / 상수: SCREAMING_SNAKE

### API 경로
```
/{client}/v{version}/{domain}/{action}
```

### DTO 구조
- `{Resource}CreateRequest` / `{Resource}UpdateRequest` / `{Resource}Response` / `{Resource}ListResponse`

### 테스트
- 유닛: Service + mock repo / 통합: httpx.AsyncClient + 실제 DB
- `pytest-asyncio` + `httpx`

## 템플릿

`skills/new-api/templates/` 의 `.tmpl` 파일 참조.

플레이스홀더: `{resource}` snake / `{Resource}` Pascal / `{RESOURCE}` SCREAMING

## 체크리스트

- [ ] `__init__.py` 존재
- [ ] DTO Pydantic v2 준수
- [ ] Repository AsyncSession 사용
- [ ] Controller EndpointPath 사용
- [ ] mypy --strict + ruff check 통과
- [ ] 테스트 기본 케이스 포함
