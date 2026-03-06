---
name: sqlalchemy
description: |
  SQLAlchemy 2.0 async infrastructure pattern reference.
  Use when: DB model definition, Base model setup, table mapping, relationship config,
  session management, AsyncSession, sessionmaker, connection pool,
  query patterns (select, join, subquery, pagination),
  Mixin (Timestamp, SoftDelete), N+1 prevention (selectinload, joinedload),
  transaction management, nested transaction, savepoint,
  generic repository pattern, BaseRepository[ModelType].
  NOT for: domain entity design (domain-layer skill), Alembic migrations.
---

# SQLAlchemy 2.0 Async Skill

## Base Model

```python
from sqlalchemy import String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, registry

class Base(DeclarativeBase):
    registry = registry(
        type_annotation_map={str: String(255)}
    )
```

## Mixins

```python
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Integer, func

class IdMixin:
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False,
    )

class SoftDeleteMixin:
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    def soft_delete(self) -> None:
        self.deleted_at = func.now()
        self.is_active = False

# Usage: class UserModel(IdMixin, TimestampMixin, SoftDeleteMixin, Base): ...
```

## Session Management

```python
from collections.abc import AsyncGenerator
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
    engine, class_=AsyncSession, expire_on_commit=False,
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

### Connection Pool Settings

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `pool_size` | 20 | steady-state connections |
| `max_overflow` | 10 | burst capacity (total max = 30) |
| `pool_pre_ping` | True | detect stale connections |
| `pool_recycle` | 3600 | avoid DB timeout |
| `pool_timeout` | 30 | max wait for available connection |

## Relationship Patterns

**MUST use `lazy="raise"` on ALL relationships.** This prevents N+1 queries at attribute-access time by raising `InvalidRequestError` if a relationship is accessed without explicit eager loading. Unlike `lazy="noload"` (which silently returns empty), `lazy="raise"` fails loudly -- forcing developers to declare loading strategy in every query.

### Checklist

- [ ] Every `relationship()` MUST have `lazy="raise"`
- [ ] Every query accessing related data MUST use explicit `selectinload` / `joinedload`
- [ ] Never rely on implicit lazy loading in async context

### One-to-Many

```python
class UserModel(IdMixin, TimestampMixin, Base):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    posts: Mapped[list["PostModel"]] = relationship(back_populates="author", lazy="raise")

class PostModel(IdMixin, TimestampMixin, Base):
    __tablename__ = "posts"
    title: Mapped[str] = mapped_column(String(200))
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    author: Mapped["UserModel"] = relationship(back_populates="posts", lazy="raise")
```

### Many-to-Many (Association Table)

```python
post_tags = Table(
    "post_tags", Base.metadata,
    Column("post_id", ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)

class PostModel(IdMixin, Base):
    __tablename__ = "posts"
    tags: Mapped[list["TagModel"]] = relationship(
        secondary=post_tags, back_populates="posts", lazy="raise",
    )

class TagModel(IdMixin, Base):
    __tablename__ = "tags"
    name: Mapped[str] = mapped_column(String(50), unique=True)
    posts: Mapped[list["PostModel"]] = relationship(
        secondary=post_tags, back_populates="tags", lazy="raise",
    )
```

## Query Patterns

### Basic Select

```python
stmt = select(UserModel).where(UserModel.email == email)
user = (await db.execute(stmt)).scalar_one_or_none()
```

### Join Query

```python
stmt = (
    select(PostModel, UserModel.name)
    .join(UserModel, PostModel.author_id == UserModel.id)
    .where(UserModel.is_active == True)
    .order_by(PostModel.created_at.desc())
)
rows = (await db.execute(stmt)).all()
```

### Offset/Limit Pagination

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

### Eager Loading (N+1 Prevention)

With `lazy="raise"`, accessing an unloaded relationship raises an error. MUST use explicit loading:

```python
from sqlalchemy.orm import selectinload, joinedload

# selectinload: separate IN query -- preferred for collections
stmt = select(UserModel).options(selectinload(UserModel.posts)).where(UserModel.id == user_id)

# joinedload: single JOIN -- preferred for single/scalar relations
stmt = select(PostModel).options(joinedload(PostModel.author)).where(PostModel.id == post_id)

# nested eager loading
stmt = select(UserModel).options(
    selectinload(UserModel.posts).selectinload(PostModel.tags),
)
```

### Exists Subquery

```python
has_posts = exists().where(PostModel.author_id == UserModel.id, PostModel.is_active == True)
stmt = select(UserModel).where(has_posts)
active_authors = (await db.execute(stmt)).scalars().all()
```

## BaseRepository[ModelType] Generic

Generic CRUD repository that eliminates boilerplate. Concrete repositories inherit and add domain-specific queries.

```python
from typing import Generic, TypeVar
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

ModelType = TypeVar("ModelType", bound=Base)

class BaseRepository(Generic[ModelType]):
    """Generic async CRUD repository."""

    model_class: type[ModelType]

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, id: int) -> ModelType | None:
        return await self.db.get(self.model_class, id)

    async def get_many(
        self, *, offset: int = 0, limit: int = 100,
    ) -> list[ModelType]:
        stmt = select(self.model_class).offset(offset).limit(limit)
        return list((await self.db.execute(stmt)).scalars().all())

    async def create(self, model: ModelType) -> ModelType:
        self.db.add(model)
        await self.db.flush()
        return model

    async def update(self, model: ModelType, **attrs: object) -> ModelType:
        for key, value in attrs.items():
            setattr(model, key, value)
        await self.db.flush()
        return model

    async def delete(self, model: ModelType) -> None:
        await self.db.delete(model)
        await self.db.flush()
```

### Concrete Repository Example

Domain layer defines the Protocol; infrastructure implements via BaseRepository.

```python
# domain/repositories.py (Protocol -- no SQLAlchemy imports)
from typing import Protocol

class UserRepository(Protocol):
    async def find_by_id(self, user_id: int) -> UserEntity | None: ...
    async def find_by_email(self, email: str) -> UserEntity | None: ...
    async def save(self, entity: UserEntity) -> UserEntity: ...

# infrastructure/repositories/user_repository.py
class SqlAlchemyUserRepository(BaseRepository[UserModel]):
    model_class = UserModel

    async def find_by_id(self, user_id: int) -> UserEntity | None:
        model = await self.get_by_id(user_id)
        return self._to_entity(model) if model else None

    async def find_by_email(self, email: str) -> UserEntity | None:
        stmt = select(UserModel).where(UserModel.email == email)
        model = (await self.db.execute(stmt)).scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def save(self, entity: UserEntity) -> UserEntity:
        if entity.id is None:
            model = await self.create(self._to_model(entity))
        else:
            model = await self.get_by_id(entity.id)
            assert model is not None
            self._apply_changes(model, entity)
            await self.db.flush()
        return self._to_entity(model)

    def _to_entity(self, model: UserModel) -> UserEntity:
        return UserEntity(id=model.id, email=Email(model.email), name=model.name)

    def _to_model(self, entity: UserEntity) -> UserModel:
        return UserModel(email=entity.email.value, name=entity.name)

    def _apply_changes(self, model: UserModel, entity: UserEntity) -> None:
        model.email = entity.email.value
        model.name = entity.name
```

### BaseRepository Checklist

- [ ] `model_class` MUST be set on every concrete repository
- [ ] Domain Protocol in `domain/` -- zero SQLAlchemy imports
- [ ] Concrete repository in `infrastructure/` -- implements Protocol
- [ ] Entity-Model mapping methods (`_to_entity`, `_to_model`) MUST be in repository
- [ ] Use `flush()` not `commit()` -- commit at service/use-case boundary

## Transaction Patterns

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

## Quick Reference

| Rule | Detail |
|------|--------|
| `lazy="raise"` | MUST on all relationships |
| `expire_on_commit=False` | MUST on async sessionmaker |
| `selectinload` | collections (one-to-many, many-to-many) |
| `joinedload` | scalar relations (many-to-one) |
| `flush()` in repository | `commit()` in application service |
| `BaseRepository[ModelType]` | inherit for CRUD, extend for domain queries |
| `pool_pre_ping=True` | MUST for production |
