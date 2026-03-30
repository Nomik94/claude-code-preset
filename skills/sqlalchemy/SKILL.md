---
name: sqlalchemy
description: |
  Use when SQLAlchemy 2.0 async 모델, 세션, 리포지토리, 쿼리, 관계,
  Alembic 마이그레이션, 인덱스 전략, N+1 방지 관련 작업.
  NOT for 도메인 엔티티 설계 (domain-layer), 단순 SQL 문법 질문.
files:
  - references/repository-pattern.md
  - references/migration-guide.md
  - references/query-patterns.md
---

# SQLAlchemy 2.0 Async + Alembic 스킬

## 1. Base & Mixin

```python
class Base(DeclarativeBase):
    registry = registry(type_annotation_map={str: String(255)})

class IdMixin:
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class SoftDeleteMixin:
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
```

## 2. Session 관리

```python
engine = create_async_engine(
    settings.database.url,
    pool_size=20, max_overflow=10,
    pool_pre_ping=True, pool_recycle=3600,
)
async_session_factory = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False,
)
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `pool_size` | 20 | steady-state connections |
| `max_overflow` | 10 | burst (total max = 30) |
| `pool_pre_ping` | True | stale connection 감지 |
| `pool_recycle` | 3600 | DB timeout 방지 |

## 3. Relationship — lazy="raise" 기본

**MUST: 모든 relationship에 `lazy="raise"`.** N+1을 속성 접근 시 `InvalidRequestError`로 감지.

```python
posts: Mapped[list["PostModel"]] = relationship(back_populates="author", lazy="raise")
author: Mapped["UserModel"] = relationship(back_populates="posts", lazy="raise")
```

| 로딩 전략 | 사용 시점 |
|-----------|---------|
| `selectinload` | 컬렉션 (one-to-many, many-to-many) |
| `joinedload` | 스칼라 관계 (many-to-one) |

> 쿼리 패턴 및 N+1 방지 예시 → references/query-patterns.md

## 4. Repository 패턴
- `model_class` MUST on every concrete repository
- Domain Protocol in `domain/` — zero SQLAlchemy imports
- `_to_entity`/`_to_model` 매핑 메서드 repository에 위치
- `flush()` 사용, `commit()`은 service/use-case 경계에서

> BaseRepository, Protocol→Adapter 패턴 → references/repository-pattern.md

## 5. Transaction
- Application Service에서 단일 `commit()` (Unit of Work)
- 중첩: `db.begin_nested()` (SAVEPOINT)

## 6. 인덱스 전략
- 높은 카디널리티 → 인덱스 (email, username)
- 낮은 카디널리티 → 부분 인덱스
- 복합 인덱스: WHERE 빈번 컬럼이 앞 (좌측 접두어)
- constraint 명명: fk_*, ix_*, uq_*, ck_*

## 7. Alembic 마이그레이션
1. 서술적 메시지: "add users table"
2. 1 revision = 1 논리적 변경
3. 데이터 마이그레이션 ↔ 스키마 변경 분리
4. 모든 upgrade에 downgrade 작성
5. server_default 사용 (DB-level)
6. CI: upgrade→downgrade→upgrade 왕복 테스트

> 초기 설정, env.py, 명령어 → references/migration-guide.md

## Quick Reference

| Rule | Detail |
|------|--------|
| `lazy="raise"` | MUST on all relationships |
| `expire_on_commit=False` | MUST on async sessionmaker |
| `selectinload` | collections |
| `joinedload` | scalar relations |
| `flush()` in repository | `commit()` in service |
| `pool_pre_ping=True` | MUST for production |
| constraint naming | fk_*, ix_*, uq_*, ck_* |
