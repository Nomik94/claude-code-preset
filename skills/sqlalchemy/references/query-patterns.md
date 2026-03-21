# 쿼리 최적화 패턴

## Basic Select

```python
stmt = select(UserModel).where(UserModel.email == email)
user = (await db.execute(stmt)).scalar_one_or_none()
```

## Join Query

```python
stmt = (
    select(PostModel, UserModel.name)
    .join(UserModel, PostModel.author_id == UserModel.id)
    .where(UserModel.is_active == True)
    .order_by(PostModel.created_at.desc())
)
rows = (await db.execute(stmt)).all()
```

## Offset/Limit Pagination

```python
stmt = (
    select(PostModel)
    .where(PostModel.is_active == True)
    .order_by(PostModel.created_at.desc())
    .offset(offset)
    .limit(limit)
)
items = (await db.execute(stmt)).scalars().all()

count_stmt = select(func.count()).select_from(PostModel).where(PostModel.is_active == True)
total = (await db.execute(count_stmt)).scalar_one()
```

## Exists Subquery

```python
has_posts = exists().where(PostModel.author_id == UserModel.id, PostModel.is_active == True)
stmt = select(UserModel).where(has_posts)
active_authors = (await db.execute(stmt)).scalars().all()
```

## N+1 방지 (Eager Loading)

`lazy="raise"` 상태에서 관련 데이터 접근 시 반드시 명시적 로딩 필요.

### selectinload — 컬렉션(one-to-many, many-to-many)에 적합

```python
from sqlalchemy.orm import selectinload

# 별도 IN 쿼리로 관련 데이터 로드
stmt = select(UserModel).options(
    selectinload(UserModel.posts),
).where(UserModel.id == user_id)
```

### joinedload — 스칼라 관계(many-to-one)에 적합

```python
from sqlalchemy.orm import joinedload

# 단일 JOIN으로 관련 데이터 로드
stmt = select(PostModel).options(
    joinedload(PostModel.author),
).where(PostModel.id == post_id)
```

### 중첩 eager loading

```python
stmt = select(UserModel).options(
    selectinload(UserModel.posts).selectinload(PostModel.tags),
)
```

### 선택 기준

| 로딩 전략 | 사용 시점 | SQL 패턴 |
|-----------|---------|----------|
| `selectinload` | 컬렉션 (one-to-many, many-to-many) | SELECT ... WHERE id IN (...) |
| `joinedload` | 스칼라 관계 (many-to-one) | LEFT OUTER JOIN |
| `subqueryload` | 복잡한 필터가 있는 컬렉션 | 서브쿼리 |

## Transaction 패턴

### Unit of Work (Application Service)

```python
class OrderApplicationService:
    def __init__(self, order_repo: OrderRepository, db: AsyncSession) -> None:
        self.order_repo = order_repo
        self.db = db

    async def place_order(self, command: PlaceOrderCommand) -> int:
        order = Order.create(...)
        saved = await self.order_repo.save(order)
        await self.db.commit()  # single commit at use-case boundary
        return saved.id
```

### Nested Transaction (Savepoint)

```python
async def transfer(self, from_id: int, to_id: int, amount: Money) -> None:
    async with self.db.begin_nested():  # SAVEPOINT
        from_acc = await self.account_repo.find_by_id(from_id)
        to_acc = await self.account_repo.find_by_id(to_id)
        from_acc.withdraw(amount)
        to_acc.deposit(amount)
        await self.account_repo.save(from_acc)
        await self.account_repo.save(to_acc)
    await self.db.commit()  # outer commit
```

## 인덱스 전략

### 카디널리티

- 높은 카디널리티 컬럼(email, username)에 인덱스 효과적
- 낮은 카디널리티(boolean, status)는 부분 인덱스 고려

### 복합 인덱스 순서

```python
# 좌측 접두어 규칙: WHERE에서 자주 쓰는 컬럼이 앞으로
Index("ix_orders_user_status", "user_id", "status")
# user_id 단독 쿼리도 이 인덱스 활용 가능
# status 단독 쿼리는 활용 불가
```

### 부분 인덱스

```python
Index("ix_users_active_email", "email",
      postgresql_where=text("is_active = true"), unique=True)
```
