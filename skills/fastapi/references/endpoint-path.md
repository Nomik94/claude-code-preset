# EndpointPath 헬퍼 상세

## 개요

`/{client}/v{version}/{domain}/{action}` 패턴을 강제하는 경로 생성 헬퍼.
하드코딩된 경로 문자열을 제거하고, 일관된 API 경로 구조를 보장한다.

## 전체 구현 코드

```python
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class EndpointPath:
    """API 엔드포인트 경로 생성기.

    /{client}/v{version}/{domain}/{action} 패턴을 강제.
    """

    client: str
    version: int
    domain: str

    @property
    def base(self) -> str:
        return f"/{self.client}/v{self.version}/{self.domain}"

    def action(self, name: str) -> str:
        """액션 경로 생성. 예: /app/v1/users/me"""
        return f"{self.base}/{name}"

    @property
    def root(self) -> str:
        """도메인 루트 경로. 예: /app/v1/users"""
        return self.base

    def detail(self, param: str = "{id}") -> str:
        """상세 경로. 예: /app/v1/users/{id}"""
        return f"{self.base}/{param}"
```

## 사용 예시

### 기본 사용

```python
ep = EndpointPath("app", 1, "users")

ep.root              # "/app/v1/users"
ep.action("me")      # "/app/v1/users/me"
ep.action("search")  # "/app/v1/users/search"
ep.detail()          # "/app/v1/users/{id}"
ep.detail("{user_id}")  # "/app/v1/users/{user_id}"
```

### 컨트롤러에서 사용

```python
from app.common.endpoint_path import EndpointPath

ep = EndpointPath("app", 1, "users")
router = APIRouter()

@router.get(ep.root)
async def list_users() -> PaginatedResponse[UserListItem]:
    ...

@router.post(ep.root)
async def create_user(request: CreateUserRequest) -> UserDetailResponse:
    ...

@router.get(ep.detail())
async def get_user(id: int) -> UserDetailResponse:
    ...

@router.put(ep.detail())
async def update_user(id: int, request: UpdateUserRequest) -> UserDetailResponse:
    ...

@router.get(ep.action("me"))
async def get_current_user() -> UserDetailResponse:
    ...
```

### 클라이언트별 분리

```python
# admin 클라이언트
admin_ep = EndpointPath("admin", 1, "users")
# /admin/v1/users, /admin/v1/users/{id}

# 모바일 앱 클라이언트
app_ep = EndpointPath("app", 1, "users")
# /app/v1/users, /app/v1/users/{id}

# 웹 클라이언트
web_ep = EndpointPath("web", 1, "users")
# /web/v1/users, /web/v1/users/{id}
```

### API 버전 관리

```python
# v1
ep_v1 = EndpointPath("app", 1, "orders")
# /app/v1/orders

# v2 (호환성 변경)
ep_v2 = EndpointPath("app", 2, "orders")
# /app/v2/orders
```

## 금지 패턴

```python
# 금지: 하드코딩된 경로 문자열
@router.get("/app/v1/users")          # ❌
@router.get("/app/v1/users/{id}")     # ❌
@router.get("/app/v1/users/me")       # ❌

# 올바른 패턴: EndpointPath 사용
ep = EndpointPath("app", 1, "users")
@router.get(ep.root)                  # ✅
@router.get(ep.detail())              # ✅
@router.get(ep.action("me"))          # ✅
```
