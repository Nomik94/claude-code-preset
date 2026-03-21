# Alembic 마이그레이션 가이드

## 초기 설정

```bash
poetry add alembic
alembic init -t async migrations   # async 템플릿 사용
```

## alembic.ini (핵심 설정)

```ini
[alembic]
script_location = migrations
sqlalchemy.url =
file_template = %%(year)d%%(month).2d%%(day).2d_%%(hour).2d%%(minute).2d_%%(rev)s_%%(slug)s
```

`sqlalchemy.url`은 env.py에서 동적으로 설정 (하드코딩 금지).

## env.py (비동기 템플릿)

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


def run_migrations_offline() -> None:
    """오프라인 모드 마이그레이션 (SQL 생성만)."""
    settings = get_settings()
    context.configure(
        url=settings.database.url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


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


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

## 명령어

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

## 일반 마이그레이션 패턴

### 테이블 추가

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

### 컬럼 추가 (기존 행을 위한 server_default)

```python
def upgrade() -> None:
    op.add_column("users", sa.Column(
        "is_active", sa.Boolean, nullable=False, server_default=sa.text("true"),
    ))
```

### 인덱스 추가

```python
def upgrade() -> None:
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_orders_user_status", "orders", ["user_id", "status"])
```

### 데이터 마이그레이션 (op.execute)

```python
def upgrade() -> None:
    op.add_column("users", sa.Column("role", sa.String(20),
                                     nullable=False, server_default="member"))
    op.execute(sa.text("""
        UPDATE users SET role = 'admin'
        WHERE email IN (SELECT email FROM admin_emails)
    """))
```

### 외래키 제약조건

```python
def upgrade() -> None:
    op.add_column("orders", sa.Column("user_id", sa.BigInteger, nullable=False))
    op.create_foreign_key(
        "fk_orders_user_id", "orders", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )
```

## 충돌 해결 (다중 Head)

```bash
alembic heads                          # 다중 head 확인
alembic merge heads -m "merge branch migrations"
alembic upgrade head
```

## Downgrade 규칙

1. 모든 upgrade에 대응하는 downgrade 작성 (빈 downgrade 금지)
2. downgrade에서 데이터 손실 주의 (drop column 전 백업 고려)
3. CI에서 upgrade -> downgrade -> upgrade 왕복 테스트
4. production downgrade 전 반드시 DB 스냅샷

## 마이그레이션 규칙

1. 메시지는 서술적으로: "add users table", "add email index to orders"
2. 하나의 revision = 하나의 논리적 변경
3. 데이터 마이그레이션은 스키마 변경과 분리 (별도 revision)
4. constraint 이름 항상 명시 (fk_*, ix_*, uq_*, ck_*)
5. server_default 사용 시 Python default가 아닌 DB-level default
6. 대용량 테이블 변경 시 downtime 고려

## CI/CD 마이그레이션

```yaml
- name: Check pending migrations
  run: poetry run alembic check

- name: Test migration roundtrip
  run: |
    poetry run alembic upgrade head
    poetry run alembic downgrade base
    poetry run alembic upgrade head
```
