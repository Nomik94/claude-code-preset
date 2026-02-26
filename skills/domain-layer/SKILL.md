---
name: domain-layer
description: |
  Domain Layer 구현 패턴 레퍼런스.
  Use when: 엔티티 만들기, 엔티티 설계, Value Object 구현, VO 만들기,
  Aggregate Root 설계, 도메인 이벤트 발행, 이벤트 버스 구현,
  비즈니스 로직 어디에 넣어, 서비스가 너무 커, 서비스 비대, 로직 분리,
  Repository Protocol 정의, Port/Adapter 패턴, 도메인 순수성,
  도메인 서비스 vs 애플리케이션 서비스, 상태 전이, 도메인 예외,
  dataclass entity, frozen dataclass, domain event flow.
  NOT for: 단순 dataclass 문법, SQLAlchemy 모델 작성 (그건 일반 지식).
---

# Domain Layer 스킬

## Value Objects (`@dataclass(frozen=True, slots=True)`)

불변, 식별자 없음, 자체 검증.

```python
from typing import Self

@dataclass(frozen=True, slots=True)
class Email:
    value: str
    def __post_init__(self):
        if not re.match(r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$", self.value):
            raise ValueError(f"Invalid email: {self.value}")
    def mask(self) -> str:
        local, domain = self.value.split("@")
        return f"{local[:2]}{'*' * (len(local) - 2)}@{domain}"

@dataclass(frozen=True, slots=True)
class Money:
    amount: Decimal
    currency: str = "KRW"
    def __post_init__(self):
        if self.amount < Decimal("0"):
            raise ValueError(f"Negative amount: {self.amount}")
    def add(self, other: Self) -> Self:
        if self.currency != other.currency:
            raise ValueError("Currency mismatch")
        return Money(amount=self.amount + other.amount, currency=self.currency)
    @classmethod
    def won(cls, amount: int | Decimal) -> Self:
        return cls(amount=Decimal(str(amount)), currency="KRW")

class OrderStatus(StrEnum):
    PENDING = "pending"
    PAID = "paid"
    def can_transition_to(self, next_status: Self) -> bool:
        return next_status in _TRANSITIONS.get(self, set())
    def transition_to(self, next_status: Self) -> Self:
        if not self.can_transition_to(next_status):
            raise InvalidOrderStatusTransitionError(self, next_status)
        return next_status
```

## Entities (`@dataclass(slots=True)`)

식별자(id)를 가지며, 비즈니스 규칙을 강제하고, 도메인 이벤트를 수집.

```python
@dataclass(slots=True)
class UserEntity:
    id: int | None
    email: Email
    name: str
    hashed_password: HashedPassword
    role: UserRole
    is_active: bool
    _domain_events: list = field(default_factory=list, init=False, repr=False)

    @classmethod
    def create(cls, email: Email, name: str, hashed_password: HashedPassword) -> Self:
        user = cls(id=None, email=email, name=name, ...)
        user._record_event(UserCreatedEvent(...))
        return user

    def deactivate(self, reason: str = "") -> None:
        if not self.is_active: return  # Idempotent
        self.is_active = False
        self._record_event(UserDeactivatedEvent(...))

    def pull_domain_events(self) -> list:
        events = self._domain_events.copy()
        self._domain_events.clear()
        return events
```

## Aggregate Root

일관성 경계. 외부 접근은 루트를 통해서만 가능.

```python
@dataclass(slots=True)
class Order:  # Aggregate Root
    id: int | None
    items: list[OrderItem]       # Internal entities
    status: OrderStatus
    shipping_address: Address    # Value Object

    def add_item(self, product_id: int, ..., stock: int) -> None:
        """Stock injected from outside — domain never queries infra."""
        if self.status != OrderStatus.PENDING:
            raise InvalidOrderStatusTransitionError(...)
        if stock < requested:
            raise InsufficientStockException(...)
        self.items.append(OrderItem.create(...))

    def place(self) -> None:
        if not self.items: raise EmptyOrderException()
        self._transition_status(OrderStatus.PAID)
        self._record_event(OrderPlacedEvent(...))
```

## Repository Protocol (Port)

```python
@runtime_checkable
class OrderRepository(Protocol):
    async def find_by_id(self, order_id: int) -> Order | None: ...
    async def save(self, order: Order) -> Order: ...
    async def find_by_user_id(self, user_id: int, *, offset: int = 0, limit: int = 20) -> list[Order]: ...
```

## 인프라 Repository (Adapter)

```python
class SqlAlchemyOrderRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def find_by_id(self, order_id: int) -> Order | None:
        result = await self.db.execute(
            select(OrderModel).options(selectinload(OrderModel.items)).where(OrderModel.id == order_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    def _to_entity(self, model: OrderModel) -> Order:
        # ORM model → domain entity with value objects
        ...
```

## Domain Service vs Application Service

| 구분 | Domain Service | Application Service |
|--------|---------------|---------------------|
| 위치 | `domain/services.py` | `application/service.py` |
| 의존성 | 순수 Python (인프라 없음) | Repo, EventBus, DB session |
| 역할 | Aggregate 간 계산 | 유스케이스 오케스트레이션, 트랜잭션 경계 |
| 테스트 | 순수 단위 테스트 (DB 없음) | Mock repository 단위 테스트 |

## 이벤트 흐름

```
Order.place()                          # Aggregate records event
  └→ order._record_event(OrderPlacedEvent)

ApplicationService.place_order()       # Publishes after tx commit
  └→ order.pull_domain_events()
  └→ event_bus.emit(OrderPlacedEvent)

@event_bus.on(OrderPlacedEvent)        # Async handlers
  └→ send_confirmation_email()
  └→ reserve_inventory()
```
