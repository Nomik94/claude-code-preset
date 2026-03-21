---
name: testing
description: |
  Use when 테스트 작성, conftest 설정, 픽스처, 도메인 유닛 테스트,
  통합 테스트, API 테스트, 커버리지, pytest 설정 관련 작업.
  NOT for pytest 기본 문법, assert 사용법.
---

# Testing 스킬

---

## 1. 테스트 피라미드

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

비율: Unit (70%) > Integration (20%) > E2E (10%)

---

## 2. 디렉토리 구조

```
tests/
├── conftest.py              # 공유 픽스처 (engine, session, client)
├── unit/
│   ├── domain/              # 순수 도메인 테스트 (no DB, no mock)
│   └── application/         # 서비스 테스트 (mock repo)
├── integration/
│   └── controllers/         # API 테스트 (real DB)
└── e2e/
```

---

## 3. conftest.py

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

---

## 4. 테스트 네이밍

```python
class TestOrder{Action}:           # e.g., TestOrderAddItem
    def test_{scenario}(self): ... # e.g., test_adds_item_increases_count
    def test_{condition}_raises(self): ...
```

패턴: `test_{동작}_{조건}_{결과}`

---

## 5. 도메인 유닛 테스트 (No DB)

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

---

## 6. Application Service 테스트 (Mock Repo)

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

---

## 7. 통합 테스트 (API via controllers/)

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

---

## 8. testcontainers (Real PostgreSQL)

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

---

## 9. pytest 설정

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --strict-markers"
markers = ["slow: marks tests as slow", "integration: marks integration tests"]
```

---

## 핵심 규칙

- MUST: `asyncio_mode = "auto"` -- `@pytest.mark.asyncio` 수동 추가 불필요
- MUST: 각 테스트는 트랜잭션 롤백으로 격리
- MUST: 도메인 유닛 테스트에 framework 모듈 import 금지
- MUST: async repository mock에 `AsyncMock` 사용
- MUST: 통합 테스트는 `tests/integration/controllers/`에 배치
- MUST: 테스트 파일명은 컨트롤러와 매칭: `test_{name}_controller.py`
- MUST: Python 3.13+ 문법 (builtin generics, `X | None` 등)

---

## 체크리스트

- [ ] `poetry run pytest` exit code 0
- [ ] `poetry run pytest --co -q` 예상 테스트 수 확인
- [ ] `poetry run ruff check tests/` 에러 없음
- [ ] 하드코딩된 시크릿/자격증명 없음
- [ ] 각 테스트 독립 -- 순서 의존성 없음
- [ ] 도메인 테스트에 DB/framework import 없음
- [ ] Mock 객체에 `spec=` 파라미터로 타입 안전성 확보
