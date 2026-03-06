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

# Testing Skill

## Test Pyramid

```
Unit (domain, no DB)  -->  Fast, pure Python 3.13+
  ├── test_order_entity.py         Domain rules, state transitions
  ├── test_user_entity.py          Value object validation
  └── test_application_service.py  Mock repository, use case flows

Integration (API)     -->  Real DB (SQLite or testcontainers)
  ├── test_users_controller.py     Full HTTP cycle
  └── test_orders_controller.py

E2E                   -->  External services included
```

## Test Naming Convention

MUST follow Conventional Commits style prefix in test docstrings/comments when relevant:

| Prefix | Usage |
|--------|-------|
| `test:` | 새 테스트 추가 커밋 |
| `fix:` | 깨진 테스트 수정 커밋 |
| `refactor:` | 테스트 구조 개선 커밋 |

Test class/method naming:

```python
class TestOrder{Action}:           # e.g., TestOrderAddItem
    def test_{scenario}(self): ... # e.g., test_adds_item_increases_count
    def test_{condition}_raises(self): ...
```

## Directory Structure

```
tests/
├── conftest.py              # Shared fixtures (engine, session, client)
├── unit/
│   ├── domain/              # Pure domain tests (no DB, no mock)
│   └── application/         # Service tests (mock repo)
├── integration/
│   └── controllers/         # API tests (real DB)
└── e2e/
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
    """Per-test transaction rollback isolation."""
    factory = async_sessionmaker(test_engine, class_=AsyncSession)
    async with factory() as session:
        async with session.begin():
            yield session
            await session.rollback()

@pytest.fixture
async def client(db_session):
    app = create_app()
    app.dependency_overrides[get_db] = lambda: db_session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

## Domain Unit Test (No DB)

```python
class TestOrderAddItem:
    def test_adds_item_increases_count(self):
        order = make_order()
        order.add_item(1, "Product A", 2, Money.won(10000), 100)
        assert order.item_count == 1 and order.subtotal == Money.won(20000)

    def test_insufficient_stock_raises(self):
        order = make_order()
        with pytest.raises(InsufficientStockException):
            order.add_item(1, "Product A", 10, Money.won(10000), stock=5)

    def test_records_domain_event(self):
        order = make_order()
        order.add_item(1, "Product A", 2, Money.won(10000), 100)
        assert isinstance(order.pull_domain_events()[0], OrderItemAddedEvent)
```

## Application Service Test (Mock Repo)

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
    async def test_create_order_success(self, service, mock_order_repo):
        order = await service.create_order(user_id=1, request=CreateOrderRequest(...))
        assert order.status == OrderStatus.PENDING
        mock_order_repo.save.assert_called_once()

    async def test_other_user_access_denied(self, service, mock_order_repo):
        existing = Order.create(user_id=99, shipping_address=MagicMock())
        existing.id = 1
        mock_order_repo.find_by_id.return_value = existing
        with pytest.raises(OrderOwnershipException):
            await service.get_order(user_id=1, order_id=1)
```

## Integration Test (API via controllers/)

```python
class TestUsersController:
    async def test_create_user_201(self, client):
        resp = await client.post("/api/v1/users", json={
            "name": "Test", "email": "test@example.com",
            "password": "Test1234!", "passwordConfirm": "Test1234!",
        })
        assert resp.status_code == 201
        assert "password" not in resp.json()

    async def test_unauthenticated_401(self, client):
        resp = await client.get("/api/v1/users/me")
        assert resp.status_code == 401
```

## testcontainers (Real PostgreSQL)

```python
@pytest.fixture(scope="session")
async def test_engine():
    with PostgresContainer("postgres:17") as pg:
        url = pg.get_connection_url().replace("psycopg2", "asyncpg")
        engine = create_async_engine(url)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        yield engine
```

## pytest Configuration

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --strict-markers"
markers = ["slow: marks tests as slow", "integration: marks integration tests"]
```

## Key Rules

- MUST use `asyncio_mode = "auto"` -- no manual `@pytest.mark.asyncio` needed
- MUST isolate each test with transaction rollback
- MUST NOT import framework modules in domain unit tests
- MUST use `AsyncMock` for async repository mocks
- MUST place integration tests under `tests/integration/controllers/`
- MUST name test files matching controller files: `test_{name}_controller.py`
- MUST use Python 3.13+ syntax (builtin generics, `X | None`, etc.)

## Verification Checklist

Before declaring tests complete:

- [ ] `poetry run pytest` passes with exit code 0
- [ ] `poetry run pytest --co -q` shows expected test count
- [ ] `poetry run ruff check tests/` has no errors
- [ ] `poetry run mypy tests/` passes (if strict mode enabled for tests)
- [ ] No hardcoded secrets or credentials in test code
- [ ] Each test is independent -- no ordering dependency
- [ ] Domain tests have zero DB/framework imports
- [ ] Mock objects use `spec=` parameter for type safety
