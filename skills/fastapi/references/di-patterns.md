# DI 패턴 상세 비교

## 패턴 선택 기준

| 규모 | 패턴 | 기준 | 장점 | 단점 |
|------|------|------|------|------|
| 소규모 (도메인 3개 이하) | FastAPI Depends | 기본 DI | 단순, 프레임워크 네이티브 | 의존성 그래프 복잡해지면 관리 어려움 |
| 중규모 (도메인 4-9개) | Manual DI + Container | 수동 팩토리 클래스 | 명시적, 테스트 용이 | 보일러플레이트 증가 |
| 대규모 (도메인 10개 이상) | Dishka | IoC 컨테이너 | 자동 해석, 스코프 관리 | 학습 곡선, 추가 의존성 |

## 1. FastAPI Depends (소규모)

### 기본 패턴

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.users.infrastructure.repository import SqlAlchemyUserRepository
from app.users.application.service import UserApplicationService


def get_user_repository(
    db: AsyncSession = Depends(get_db),
) -> SqlAlchemyUserRepository:
    return SqlAlchemyUserRepository(db)


def get_user_service(
    repo: SqlAlchemyUserRepository = Depends(get_user_repository),
    db: AsyncSession = Depends(get_db),
) -> UserApplicationService:
    return UserApplicationService(repo=repo, db=db)
```

### 컨트롤러에서 사용

```python
@router.post(ep.root)
async def create_user(
    request: CreateUserRequest,
    service: UserApplicationService = Depends(get_user_service),
) -> UserDetailResponse:
    entity = await service.create(request)
    return UserDetailResponse.from_domain(entity)
```

### 인증 의존성 체인

```python
def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_service: UserApplicationService = Depends(get_user_service),
) -> ...:
    # JWT 디코딩 + 사용자 조회
    ...

def require_admin(
    current_user: UserEntity = Depends(get_current_user),
) -> UserEntity:
    if current_user.role != UserRole.ADMIN:
        raise ForbiddenException(detail="관리자 권한이 필요합니다")
    return current_user
```

## 2. Manual DI + Container (중규모)

### Container 클래스

```python
from sqlalchemy.ext.asyncio import AsyncSession


class Container:
    """수동 DI 컨테이너. 세션당 1개 인스턴스."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._init_repositories()
        self._init_services()

    def _init_repositories(self) -> None:
        self.user_repo = SqlAlchemyUserRepository(self._db)
        self.order_repo = SqlAlchemyOrderRepository(self._db)
        self.product_repo = SqlAlchemyProductRepository(self._db)

    def _init_services(self) -> None:
        self.user_service = UserApplicationService(
            repo=self.user_repo, db=self._db,
        )
        self.order_service = OrderApplicationService(
            order_repo=self.order_repo,
            product_repo=self.product_repo,
            db=self._db,
        )
```

### FastAPI 연동

```python
async def get_container(
    db: AsyncSession = Depends(get_db),
) -> Container:
    return Container(db)


@router.post(ep.root)
async def create_order(
    request: CreateOrderRequest,
    container: Container = Depends(get_container),
) -> OrderDetailResponse:
    entity = await container.order_service.create(request)
    return OrderDetailResponse.from_domain(entity)
```

### 테스트에서 Mock Container

```python
@pytest.fixture
def mock_container():
    container = Container.__new__(Container)
    container.user_service = AsyncMock(spec=UserApplicationService)
    container.order_service = AsyncMock(spec=OrderApplicationService)
    return container

async def test_create_order(mock_container):
    app.dependency_overrides[get_container] = lambda: mock_container
    # ... 테스트 코드
```

## 3. Dishka (대규모)

### Provider 정의

```python
from dishka import Provider, Scope, provide


class RepositoryProvider(Provider):
    """리포지토리 레이어 DI 설정."""

    user_repository = provide(
        SqlAlchemyUserRepository,
        provides=UserRepository,  # Protocol 타입으로 제공
        scope=Scope.REQUEST,
    )
    order_repository = provide(
        SqlAlchemyOrderRepository,
        provides=OrderRepository,
        scope=Scope.REQUEST,
    )


class ServiceProvider(Provider):
    """서비스 레이어 DI 설정."""

    user_service = provide(
        UserApplicationService,
        scope=Scope.REQUEST,
    )
    order_service = provide(
        OrderApplicationService,
        scope=Scope.REQUEST,
    )
```

### 컨테이너 생성 및 등록

```python
from dishka import make_async_container
from dishka.integrations.fastapi import DishkaRoute, setup_dishka


container = make_async_container(
    RepositoryProvider(),
    ServiceProvider(),
)

# FastAPI 앱에 등록
setup_dishka(container, app)

# 라우터에 DishkaRoute 적용
router = APIRouter(route_class=DishkaRoute)
```

### 컨트롤러에서 사용 (FromDishka)

```python
from dishka.integrations.fastapi import FromDishka


@router.post(ep.root)
async def create_user(
    request: CreateUserRequest,
    service: FromDishka[UserApplicationService],
) -> UserDetailResponse:
    entity = await service.create(request)
    return UserDetailResponse.from_domain(entity)
```

## 금지 라이브러리

- **dependency-injector**: Cython 이슈, 단일 메인테이너, async 지원 불완전. 사용 금지.
