---
name: testing
description: |
  프로젝트 테스트 패턴 레퍼런스.
  Use when: 테스트 작성, 테스트 코드 짜기, 테스트 구조 잡기, 테스트 어떻게 써,
  conftest 설정, 픽스처 만들기, fixture 구성, db_session 픽스처,
  도메인 유닛 테스트, 서비스 테스트, mock repository, AsyncMock,
  통합 테스트, API 테스트, httpx AsyncClient, TestClient,
  testcontainers, 실제 PostgreSQL 테스트, 테스트 DB,
  커버리지, coverage 설정, pytest 설정, asyncio_mode,
  테스트 격리, 트랜잭션 롤백, 테스트별 독립.
  NOT for: pytest 기본 문법, assert 사용법.
---

# 테스팅 스킬

## 테스트 피라미드

```
Unit (domain, no DB)  →  Fast, pure Python
  ├── test_order_entity.py         Domain rules, state transitions
  ├── test_user_entity.py          Value object validation
  └── test_application_service.py  Mock repository, use case flows

Integration (API)     →  Real DB (SQLite or testcontainers)
  ├── test_users_api.py            Full HTTP cycle
  └── test_orders_api.py

E2E                   →  External services included
```

## conftest.py

```python
TEST_DB_URL = "sqlite+aiosqlite:///./test.db"

@pytest.fixture(scope="session")
async def test_engine():
    engine = create_async_engine(TEST_DB_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine

@pytest.fixture
async def db_session(test_engine):
    """Per-test transaction rollback isolation"""
    session_factory = async_sessionmaker(test_engine, class_=AsyncSession)
    async with session_factory() as session:
        async with session.begin():
            yield session
            await session.rollback()

@pytest.fixture
async def client(db_session):
    app = create_app()
    app.dependency_overrides[get_db] = lambda: db_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

## 도메인 유닛 테스트 (DB 없음)

```python
class TestOrderAddItem:
    def test_adds_item_increases_count(self):
        order = make_order()
        order.add_item(1, "Product A", 2, Money.won(10000), 100)
        assert order.item_count == 1
        assert order.subtotal == Money.won(20000)

    def test_insufficient_stock_raises(self):
        order = make_order()
        with pytest.raises(InsufficientStockException) as exc_info:
            order.add_item(1, "Product A", 10, Money.won(10000), stock=5)
        assert exc_info.value.requested == 10

    def test_records_domain_event(self):
        order = make_order()
        order.add_item(1, "Product A", 2, Money.won(10000), 100)
        events = order.pull_domain_events()
        assert len(events) == 1
        assert isinstance(events[0], OrderItemAddedEvent)
```

## Application Service 테스트 (Mock Repo)

```python
@pytest.fixture
def service(mock_order_repo, mock_product_repo, mock_user_repo):
    return OrderApplicationService(
        db=AsyncMock(), order_repo=mock_order_repo,
        product_repo=mock_product_repo, user_repo=mock_user_repo,
        pricing_service=OrderPricingService(),
        validation_service=OrderValidationService(),
    )

class TestOrderApplicationService:
    @pytest.mark.asyncio
    async def test_create_order_success(self, service, mock_order_repo):
        order = await service.create_order(user_id=1, request=CreateOrderRequest(...))
        assert order.status == OrderStatus.PENDING
        mock_order_repo.save.assert_called_once()

    @pytest.mark.asyncio
    async def test_other_user_access_denied(self, service, mock_order_repo):
        existing = Order.create(user_id=99, shipping_address=MagicMock())
        existing.id = 1
        mock_order_repo.find_by_id.return_value = existing
        with pytest.raises(OrderOwnershipException):
            await service.get_order(user_id=1, order_id=1)
```

## 통합 테스트 (API)

```python
class TestUsersAPI:
    @pytest.mark.asyncio
    async def test_create_user_201(self, client):
        response = await client.post("/api/v1/users", json={
            "name": "Test", "email": "test@example.com",
            "password": "Test1234!", "password_confirm": "Test1234!",
        })
        assert response.status_code == 201
        assert "password" not in response.json()

    @pytest.mark.asyncio
    async def test_unauthenticated_401(self, client):
        response = await client.get("/api/v1/users/me")
        assert response.status_code == 401
```

## testcontainers (실제 PostgreSQL)

```python
@pytest.fixture(scope="session")
async def test_engine():
    with PostgresContainer("postgres:16") as pg:
        url = pg.get_connection_url().replace("psycopg2", "asyncpg")
        engine = create_async_engine(url)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        yield engine
```

## pytest 설정

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --strict-markers"
markers = ["slow: marks tests as slow", "integration: marks integration tests"]
```
