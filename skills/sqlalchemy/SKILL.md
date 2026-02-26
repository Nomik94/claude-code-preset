---
name: sqlalchemy
description: |
  SQLAlchemy 2.0 async 인프라 패턴 레퍼런스.
  Use when: DB 모델 정의, Base 모델 설정, 테이블 매핑, relationship 설정,
  세션 관리, AsyncSession, sessionmaker, connection pool,
  쿼리 작성, select, join, subquery, 페이지네이션,
  Mixin 만들기, TimestampMixin, SoftDeleteMixin,
  N+1 해결, selectinload, joinedload, expire_on_commit,
  트랜잭션 관리, nested transaction, savepoint.
  NOT for: 도메인 엔티티 설계 (domain-layer skill 참조), Alembic 마이그레이션.
---

# SQLAlchemy 2.0 Async 스킬

## Base 모델 설정

```python
from datetime import datetime
from sqlalchemy import String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, registry

class Base(DeclarativeBase):
    registry = registry(
        type_annotation_map={
            str: String(255),  # default string length
        }
    )
```

## Mixin

```python
from sqlalchemy import Boolean, DateTime, Integer, text

class IdMixin:
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

class SoftDeleteMixin:
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    def soft_delete(self) -> None:
        self.deleted_at = func.now()
        self.is_active = False


# Usage: class UserModel(IdMixin, TimestampMixin, SoftDeleteMixin, Base): ...
```

## 세션 관리

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine(
    settings.database.url,  # "postgresql+asyncpg://..."
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=settings.debug,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # critical: prevents lazy-load after commit
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## 커넥션 풀 설정

```
pool_size=20          # steady-state connections
max_overflow=10       # burst capacity (total max = 30)
pool_pre_ping=True    # detect stale connections before use
pool_recycle=3600     # recycle connections after 1 hour (avoid DB timeout)
pool_timeout=30       # wait max 30s for available connection
```

## 관계 패턴

### 일대다

```python
class UserModel(IdMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))

    posts: Mapped[list["PostModel"]] = relationship(back_populates="author", lazy="noload")

class PostModel(IdMixin, TimestampMixin, Base):
    __tablename__ = "posts"

    title: Mapped[str] = mapped_column(String(200))
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)

    author: Mapped["UserModel"] = relationship(back_populates="posts", lazy="noload")
```

### 다대다 (연관 테이블)

```python
post_tags = Table(
    "post_tags", Base.metadata,
    Column("post_id", ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)

class PostModel(IdMixin, Base):
    __tablename__ = "posts"
    tags: Mapped[list["TagModel"]] = relationship(secondary=post_tags, back_populates="posts", lazy="noload")

class TagModel(IdMixin, Base):
    __tablename__ = "tags"
    name: Mapped[str] = mapped_column(String(50), unique=True)
    posts: Mapped[list["PostModel"]] = relationship(secondary=post_tags, back_populates="tags", lazy="noload")
```

## 쿼리 패턴

### 기본 조회

```python
from sqlalchemy import select

stmt = select(UserModel).where(UserModel.email == email)
result = await db.execute(stmt)
user = result.scalar_one_or_none()
```

### Join 쿼리

```python
stmt = (
    select(PostModel, UserModel.name)
    .join(UserModel, PostModel.author_id == UserModel.id)
    .where(UserModel.is_active == True)
    .order_by(PostModel.created_at.desc())
)
rows = (await db.execute(stmt)).all()  # list[Row(PostModel, str)]
```

### 페이지네이션 (Offset/Limit)

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

### Eager Loading (N+1 방지)

```python
from sqlalchemy.orm import selectinload, joinedload

# selectinload: separate IN query (preferred for collections)
stmt = select(UserModel).options(selectinload(UserModel.posts)).where(UserModel.id == user_id)

# joinedload: single JOIN (preferred for single relations)
stmt = select(PostModel).options(joinedload(PostModel.author)).where(PostModel.id == post_id)

# nested eager loading
stmt = select(UserModel).options(
    selectinload(UserModel.posts).selectinload(PostModel.tags)
)
```

### Exists 서브쿼리

```python
from sqlalchemy import exists

has_posts = (
    exists()
    .where(PostModel.author_id == UserModel.id)
    .where(PostModel.is_active == True)
)
stmt = select(UserModel).where(has_posts)
active_authors = (await db.execute(stmt)).scalars().all()
```

## Repository 구현

도메인 레이어의 Protocol을 구현합니다 (Adapter 패턴).

```python
from app.users.domain.repositories import UserRepository  # Protocol

class SqlAlchemyUserRepository:
    """Implements UserRepository Protocol defined in domain layer."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def find_by_id(self, user_id: int) -> UserEntity | None:
        stmt = select(UserModel).where(UserModel.id == user_id)
        model = (await self.db.execute(stmt)).scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def save(self, entity: UserEntity) -> UserEntity:
        if entity.id is None:
            model = self._to_model(entity)
            self.db.add(model)
            await self.db.flush()  # get generated id
            return self._to_entity(model)
        else:
            stmt = select(UserModel).where(UserModel.id == entity.id)
            model = (await self.db.execute(stmt)).scalar_one()
            self._update_model(model, entity)
            await self.db.flush()
            return self._to_entity(model)

    def _to_entity(self, model: UserModel) -> UserEntity:
        return UserEntity(id=model.id, email=Email(model.email), name=model.name, ...)

    def _to_model(self, entity: UserEntity) -> UserModel:
        return UserModel(email=entity.email.value, name=entity.name, ...)

    def _update_model(self, model: UserModel, entity: UserEntity) -> None:
        model.email = entity.email.value
        model.name = entity.name
```

## 트랜잭션 패턴

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

### 중첩 트랜잭션 (Savepoint)

```python
async def transfer_with_savepoint(self, from_id: int, to_id: int, amount: Money) -> None:
    async with self.db.begin_nested() as savepoint:  # SAVEPOINT
        from_account = await self.account_repo.find_by_id(from_id)
        to_account = await self.account_repo.find_by_id(to_id)
        from_account.withdraw(amount)
        to_account.deposit(amount)
        await self.account_repo.save(from_account)
        await self.account_repo.save(to_account)
        # savepoint auto-commits on exit, or rollback on exception
    await self.db.commit()  # outer commit
```
