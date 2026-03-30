---
name: testing
description: |
  Use when 테스트 작성, conftest 설정, 픽스처, 도메인 유닛 테스트,
  통합 테스트, API 테스트, 커버리지, pytest 설정 관련 작업.
  NOT for pytest 기본 문법, assert 사용법.
---

# Testing

## 1. 테스트 피라미드

```
Unit (domain, no DB)  -->  Fast, pure Python 3.13+
Integration (API)     -->  Real DB (SQLite or testcontainers)
E2E                   -->  External services included
```

비율: Unit 70% > Integration 20% > E2E 10%

## 2. 디렉토리 구조

```
tests/
├── conftest.py              # 공유 픽스처
├── unit/
│   ├── domain/              # 순수 도메인 (no DB, no mock)
│   └── application/         # 서비스 (mock repo)
├── integration/controllers/ # API (real DB)
└── e2e/
```

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

## 4. 네이밍

```python
class TestOrder{Action}:           # e.g., TestOrderAddItem
    def test_{scenario}(self): ... # e.g., test_adds_item_increases_count
    def test_{condition}_raises(self): ...
```

패턴: `test_{동작}_{조건}_{결과}`

## 5. 도메인 유닛 테스트

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
```

## 6. Application Service 테스트

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
```

## 7. 통합 테스트

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

## 8. testcontainers

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

## 9. pytest 설정

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --strict-markers"
markers = ["slow: marks tests as slow", "integration: marks integration tests"]
```

## 핵심 규칙

- `asyncio_mode = "auto"` -- `@pytest.mark.asyncio` 수동 추가 불필요
- 각 테스트 트랜잭션 롤백 격리
- 도메인 유닛 테스트에 framework import 금지
- async repo mock에 `AsyncMock` 사용
- 통합 테스트: `tests/integration/controllers/`
- 파일명: `test_{name}_controller.py` (컨트롤러 매칭)
- Python 3.13+ 문법

## 체크리스트

- [ ] `poetry run pytest` exit 0
- [ ] `poetry run pytest --co -q` 예상 수 확인
- [ ] `poetry run ruff check tests/` 에러 없음
- [ ] 하드코딩 시크릿 없음
- [ ] 각 테스트 독립 (순서 무관)
- [ ] 도메인 테스트에 DB/framework import 없음
- [ ] Mock에 `spec=` 파라미터로 타입 안전성

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
