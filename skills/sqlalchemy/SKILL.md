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

---

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

---

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
| `max_overflow` | 10 | burst capacity (total max = 30) |
| `pool_pre_ping` | True | detect stale connections |
| `pool_recycle` | 3600 | avoid DB timeout |

---

## 3. Relationship -- lazy="raise" 기본

**MUST: 모든 relationship에 `lazy="raise"` 설정.** N+1 쿼리를 속성 접근 시점에 `InvalidRequestError`로 감지.

```python
posts: Mapped[list["PostModel"]] = relationship(back_populates="author", lazy="raise")
author: Mapped["UserModel"] = relationship(back_populates="posts", lazy="raise")
```

Eager loading 선택:
| 로딩 전략 | 사용 시점 |
|-----------|---------|
| `selectinload` | 컬렉션 (one-to-many, many-to-many) |
| `joinedload` | 스칼라 관계 (many-to-one) |

> 쿼리 패턴 상세 및 N+1 방지 코드 예시는 references/query-patterns.md 참조

---

## 4. Repository 패턴 핵심 규칙

- `model_class` MUST be set on every concrete repository
- Domain Protocol in `domain/` -- zero SQLAlchemy imports
- Entity-Model mapping methods (`_to_entity`, `_to_model`) MUST be in repository
- Use `flush()` not `commit()` -- commit at service/use-case boundary

> BaseRepository 전체 코드, Protocol -> Adapter 패턴은 references/repository-pattern.md 참조

---

## 5. Transaction 패턴

- Application Service에서 단일 `commit()` (Unit of Work)
- 중첩 트랜잭션: `db.begin_nested()` (SAVEPOINT)

---

## 6. 인덱스 전략

- 높은 카디널리티 컬럼에 인덱스 (email, username)
- 낮은 카디널리티는 부분 인덱스 고려
- 복합 인덱스: 좌측 접두어 규칙 (WHERE 빈번 컬럼이 앞)
- constraint 이름 명시: fk_*, ix_*, uq_*, ck_*

---

## 7. 마이그레이션 (Alembic) 핵심 규칙

1. 메시지는 서술적으로: "add users table"
2. 하나의 revision = 하나의 논리적 변경
3. 데이터 마이그레이션은 스키마 변경과 분리
4. 모든 upgrade에 대응하는 downgrade 작성
5. server_default 사용 (Python default 아닌 DB-level)
6. CI에서 upgrade -> downgrade -> upgrade 왕복 테스트

> 초기 설정, env.py 코드, 명령어, 마이그레이션 패턴은 references/migration-guide.md 참조

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
