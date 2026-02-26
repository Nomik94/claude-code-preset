---
name: alembic
description: |
  Alembic DB 마이그레이션 패턴 레퍼런스.
  Use when: 마이그레이션 생성, DB 스키마 변경, 테이블 추가, 컬럼 변경,
  alembic revision, autogenerate, downgrade, 롤백, 마이그레이션 이력,
  데이터 마이그레이션, bulk data update, 인덱스 추가, 외래키 변경,
  alembic.ini 설정, env.py 설정, 마이그레이션 충돌 해결.
  NOT for: SQLAlchemy 모델 정의, ORM 쿼리 패턴.
---

# Alembic Skill

## 초기 설정

```bash
poetry add alembic
alembic init -t async migrations   # async 템플릿 사용
```

### alembic.ini (핵심 설정만)
```ini
[alembic]
script_location = migrations
# sqlalchemy.url은 env.py에서 동적으로 설정 (하드코딩 금지)
sqlalchemy.url =
file_template = %%(year)d%%(month).2d%%(day).2d_%%(hour).2d%%(minute).2d_%%(rev)s_%%(slug)s
```

### env.py (비동기 템플릿)
```python
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import get_settings
from app.core.database import Base

# 모든 모델 import 필수 (autogenerate가 감지하려면)
from app.users.infrastructure.models import *  # noqa: F401,F403
from app.orders.infrastructure.models import *  # noqa: F401,F403

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (SQL 스크립트 생성)."""
    url = get_settings().database.url
    context.configure(url=url, target_metadata=target_metadata,
                      literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in 'online' mode (async engine)."""
    settings = get_settings()
    configuration = config.get_section(config.config_ini_section, {})
    configuration["sqlalchemy.url"] = settings.database.url

    connectable = async_engine_from_config(
        configuration, prefix="sqlalchemy.", poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_async_migrations())
```

## 리비전 명령어

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
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), onupdate=sa.func.now()),
    )

def downgrade() -> None:
    op.drop_table("users")
```

### 컬럼 추가 (기존 행을 위한 server_default)
```python
def upgrade() -> None:
    # server_default 필수: 기존 행에 NULL 방지
    op.add_column("users", sa.Column(
        "is_active", sa.Boolean, nullable=False, server_default=sa.text("true"),
    ))

def downgrade() -> None:
    op.drop_column("users", "is_active")
```

### 인덱스 추가
```python
def upgrade() -> None:
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    # 복합 인덱스
    op.create_index("ix_orders_user_status", "orders", ["user_id", "status"])

def downgrade() -> None:
    op.drop_index("ix_orders_user_status", table_name="orders")
    op.drop_index("ix_users_email", table_name="users")
```

### 컬럼 이름 변경 (SQLite 호환)
```python
def upgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column("name", new_column_name="display_name")

def downgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column("display_name", new_column_name="name")
```

### 데이터 마이그레이션 (op.execute)
```python
def upgrade() -> None:
    # DDL 변경
    op.add_column("users", sa.Column("role", sa.String(20),
                                     nullable=False, server_default="member"))
    # 기존 데이터 업데이트
    op.execute(sa.text("""
        UPDATE users SET role = 'admin'
        WHERE email IN (SELECT email FROM admin_emails)
    """))

def downgrade() -> None:
    op.drop_column("users", "role")
```

### 외래키 제약조건 추가
```python
def upgrade() -> None:
    op.add_column("orders", sa.Column("user_id", sa.BigInteger, nullable=False))
    op.create_foreign_key(
        "fk_orders_user_id",     # constraint 이름 명시
        "orders", "users",       # source_table, referent_table
        ["user_id"], ["id"],     # local_cols, remote_cols
        ondelete="CASCADE",
    )

def downgrade() -> None:
    op.drop_constraint("fk_orders_user_id", "orders", type_="foreignkey")
    op.drop_column("orders", "user_id")
```

## Downgrade 베스트 프랙티스

```
1. 모든 upgrade에 대응하는 downgrade 작성 (빈 downgrade 금지)
2. downgrade에서 데이터 손실 주의 (drop column 전 백업 고려)
3. CI에서 upgrade → downgrade → upgrade 왕복 테스트
4. production downgrade 전 반드시 DB 스냅샷
```

## CI/CD에서의 마이그레이션

```yaml
# GitHub Actions example
- name: Check pending migrations
  run: poetry run alembic check
  # 모델 변경했는데 revision 안 만들면 실패

- name: Test migration roundtrip
  run: |
    poetry run alembic upgrade head
    poetry run alembic downgrade base
    poetry run alembic upgrade head
```

## 충돌 해결 (다중 Head)

```bash
# 여러 브랜치에서 migration 생성 후 merge 시
alembic heads                          # 다중 head 확인
alembic merge heads -m "merge branch migrations"  # 머지 revision 생성
alembic upgrade head                   # 적용
```

## 규칙

```
1. 메시지는 서술적으로: "add users table", "add email index to orders"
2. 하나의 revision = 하나의 논리적 변경 (테이블 + 인덱스는 같이 OK)
3. 데이터 마이그레이션은 스키마 변경과 분리 (별도 revision)
4. constraint 이름 항상 명시 (fk_*, ix_*, uq_*, ck_*)
5. server_default 사용 시 Python default가 아닌 DB-level default
6. 대용량 테이블 변경 시 downtime 고려 (ADD COLUMN은 보통 safe)
```
