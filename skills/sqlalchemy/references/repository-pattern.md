# Repository 패턴 상세

## BaseRepository[ModelType] 전체 코드

```python
from typing import Generic, TypeVar

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base

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

## Domain Protocol -> Infrastructure Adapter 패턴

### Protocol (Port) — domain/repositories.py

```python
from typing import Protocol


class UserRepository(Protocol):
    """도메인 리포지토리 인터페이스. SQLAlchemy import 없음."""

    async def find_by_id(self, user_id: int) -> UserEntity | None: ...
    async def find_by_email(self, email: str) -> UserEntity | None: ...
    async def save(self, entity: UserEntity) -> UserEntity: ...
    async def delete(self, entity: UserEntity) -> None: ...
```

### Adapter (구현) — infrastructure/repositories/user_repository.py

```python
from sqlalchemy import select

from app.common.base_repository import BaseRepository
from app.users.domain.entities import UserEntity
from app.users.infrastructure.models import UserModel


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
        if entity.id:
            # 기존 엔티티 업데이트
            model = await self.get_by_id(entity.id)
            if model is None:
                msg = f"User {entity.id} not found"
                raise ValueError(msg)
            self._apply_entity(model, entity)
            await self.db.flush()
        else:
            # 새 엔티티 생성
            model = self._to_model(entity)
            await self.create(model)
        return self._to_entity(model)

    def _to_entity(self, model: UserModel) -> UserEntity:
        """ORM 모델 -> 도메인 엔티티 변환."""
        return UserEntity(
            id=model.id,
            email=Email(model.email),
            name=model.name,
            hashed_password=HashedPassword(model.hashed_password),
            role=UserRole(model.role),
            is_active=model.is_active,
            created_at=model.created_at,
        )

    def _to_model(self, entity: UserEntity) -> UserModel:
        """도메인 엔티티 -> ORM 모델 변환."""
        return UserModel(
            email=entity.email.value,
            name=entity.name,
            hashed_password=entity.hashed_password.value,
            role=entity.role.value,
            is_active=entity.is_active,
        )

    def _apply_entity(self, model: UserModel, entity: UserEntity) -> None:
        """도메인 엔티티 변경사항을 ORM 모델에 적용."""
        model.email = entity.email.value
        model.name = entity.name
        model.hashed_password = entity.hashed_password.value
        model.role = entity.role.value
        model.is_active = entity.is_active
```

## Repository 규칙

- `model_class` MUST be set on every concrete repository
- Domain Protocol in `domain/` — zero SQLAlchemy imports
- Entity-Model mapping methods (`_to_entity`, `_to_model`) MUST be in repository
- Use `flush()` not `commit()` — commit at service/use-case boundary
- `save()`에서 create/update 분기 처리
