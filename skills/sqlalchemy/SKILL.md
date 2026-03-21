---
name: sqlalchemy
description: |
  Use when SQLAlchemy 2.0 async 모델, 세션, 리포지토리, 쿼리, 관계,
  Alembic 마이그레이션, 인덱스 전략, N+1 방지 관련 작업.
  NOT for 도메인 엔티티 설계 (domain-layer), 단순 SQL 문법 질문.
---

# SQLAlchemy 2.0 Async + Alembic 스킬

---

## 1. Base & Mixin

### DeclarativeBase

```python
from sqlalchemy import String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, registry

class Base(DeclarativeBase):
    registry = registry(
        type_annotation_map={str: String(255)}
    )
```

### Mixins

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

---

## 2. Session 관리

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

---

## 3. Relationship -- lazy="raise" 기본

**MUST: 모든 relationship에 `lazy="raise"` 설정.** N+1 쿼리를 속성 접근 시점에 `InvalidRequestError`로 감지. `lazy="noload"`(빈 값 반환)과 달리 실수를 즉시 발견.

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
```

### Eager Loading (N+1 Prevention)

`lazy="raise"` 상태에서 관련 데이터 접근 시 반드시 명시적 로딩 필요:

```python
from sqlalchemy.orm import selectinload, joinedload

# selectinload: 별도 IN 쿼리 -- 컬렉션(one-to-many, many-to-many)에 적합
stmt = select(UserModel).options(selectinload(UserModel.posts)).where(UserModel.id == user_id)

# joinedload: 단일 JOIN -- 스칼라 관계(many-to-one)에 적합
stmt = select(PostModel).options(joinedload(PostModel.author)).where(PostModel.id == post_id)

# 중첩 eager loading
stmt = select(UserModel).options(
    selectinload(UserModel.posts).selectinload(PostModel.tags),
)
```

---

## 4. Repository 패턴

### BaseRepository[ModelType] Generic

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

    async def get_many(self, *, offset: int = 0, limit: int = 100) -> list[ModelType]:
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

### Domain Protocol -> Infrastructure Adapter

```python
# domain/repositories.py (Protocol -- no SQLAlchemy imports)
class UserRepository(Protocol):
    async def find_by_id(self, user_id: int) -> UserEntity | None: ...
    async def find_by_email(self, email: str) -> UserEntity | None: ...
    async def save(self, entity: UserEntity) -> UserEntity: ...

# infrastructure/repositories/user_repository.py
class SqlAlchemyUserRepository(BaseRepository[UserModel]):
    model_class = UserModel

    async def find_by_email(self, email: str) -> UserEntity | None:
        stmt = select(UserModel).where(UserModel.email == email)
        model = (await self.db.execute(stmt)).scalar_one_or_none()
        return self._to_entity(model) if model else None

    # MUST: _to_entity(), _to_model() 변환 메서드 구현
    # MUST: save()에서 create/update 분기 처리
```

### Repository 규칙

- `model_class` MUST be set on every concrete repository
- Domain Protocol in `domain/` -- zero SQLAlchemy imports
- Entity-Model mapping methods (`_to_entity`, `_to_model`) MUST be in repository
- Use `flush()` not `commit()` -- commit at service/use-case boundary

---

## 5. Query 패턴

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

### Exists Subquery

```python
has_posts = exists().where(PostModel.author_id == UserModel.id, PostModel.is_active == True)
stmt = select(UserModel).where(has_posts)
active_authors = (await db.execute(stmt)).scalars().all()
```

---

## 6. Transaction 패턴

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

---

## 7. 인덱스 전략

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

---

## 8. 마이그레이션 (Alembic)

### 초기 설정

```bash
poetry add alembic
alembic init -t async migrations   # async 템플릿 사용
```

### alembic.ini (핵심 설정)

```ini
[alembic]
script_location = migrations
sqlalchemy.url =
file_template = %%(year)d%%(month).2d%%(day).2d_%%(hour).2d%%(minute).2d_%%(rev)s_%%(slug)s
```

`sqlalchemy.url`은 env.py에서 동적으로 설정 (하드코딩 금지).

### env.py (비동기 템플릿)

```python
import asyncio
from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config
from app.core.config import get_settings
from app.core.database import Base

# 모든 모델 import 필수 (autogenerate가 감지하려면)
from app.users.infrastructure.models import *  # noqa: F401,F403
from app.orders.infrastructure.models import *  # noqa: F401,F403

target_metadata = Base.metadata

async def run_async_migrations() -> None:
    settings = get_settings()
    configuration = config.get_section(config.config_ini_section, {})
    configuration["sqlalchemy.url"] = settings.database.url
    connectable = async_engine_from_config(
        configuration, prefix="sqlalchemy.", poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()
```

### 명령어

```bash
# Autogenerate (모델 변경 감지)
alembic revision --autogenerate -m "add users table"

# Manual revision (데이터 마이그레이션 등)
alembic revision -m "backfill user display names"

# Upgrade / Downgrade
alembic upgrade head          # 최신으로
alembic upgrade +1            # 한 단계 앞으로
alembic downgrade -1          # 한 단계 롤백
alembic downgrade base        # 전체 롤백

# 현재 상태 확인
alembic current               # 현재 revision
alembic history --verbose     # 전체 이력
alembic check                 # pending migration 감지 (CI용)
```

### 일반 마이그레이션 패턴

**테이블 추가:**

```python
def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )

def downgrade() -> None:
    op.drop_table("users")
```

**컬럼 추가 (기존 행을 위한 server_default):**

```python
def upgrade() -> None:
    op.add_column("users", sa.Column(
        "is_active", sa.Boolean, nullable=False, server_default=sa.text("true"),
    ))
```

**인덱스 추가:**

```python
def upgrade() -> None:
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_orders_user_status", "orders", ["user_id", "status"])
```

**데이터 마이그레이션 (op.execute):**

```python
def upgrade() -> None:
    op.add_column("users", sa.Column("role", sa.String(20),
                                     nullable=False, server_default="member"))
    op.execute(sa.text("""
        UPDATE users SET role = 'admin'
        WHERE email IN (SELECT email FROM admin_emails)
    """))
```

**외래키 제약조건:**

```python
def upgrade() -> None:
    op.add_column("orders", sa.Column("user_id", sa.BigInteger, nullable=False))
    op.create_foreign_key(
        "fk_orders_user_id", "orders", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )
```

### 충돌 해결 (다중 Head)

```bash
alembic heads                          # 다중 head 확인
alembic merge heads -m "merge branch migrations"
alembic upgrade head
```

### Downgrade 규칙

1. 모든 upgrade에 대응하는 downgrade 작성 (빈 downgrade 금지)
2. downgrade에서 데이터 손실 주의 (drop column 전 백업 고려)
3. CI에서 upgrade -> downgrade -> upgrade 왕복 테스트
4. production downgrade 전 반드시 DB 스냅샷

### 마이그레이션 규칙

1. 메시지는 서술적으로: "add users table", "add email index to orders"
2. 하나의 revision = 하나의 논리적 변경
3. 데이터 마이그레이션은 스키마 변경과 분리 (별도 revision)
4. constraint 이름 항상 명시 (fk_*, ix_*, uq_*, ck_*)
5. server_default 사용 시 Python default가 아닌 DB-level default
6. 대용량 테이블 변경 시 downtime 고려

### CI/CD 마이그레이션

```yaml
- name: Check pending migrations
  run: poetry run alembic check

- name: Test migration roundtrip
  run: |
    poetry run alembic upgrade head
    poetry run alembic downgrade base
    poetry run alembic upgrade head
```

---

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
| constraint naming | fk_*, ix_*, uq_*, ck_* |
