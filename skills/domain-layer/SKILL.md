---
name: domain-layer
description: |
  Domain Layer 설계 및 구현 가이드.
  Use when: Entity/Value Object/Aggregate Root 설계, 도메인 이벤트 구현,
  비즈니스 로직 배치 판단, Repository Protocol 정의, Domain vs Application Service 구분,
  상태 전이 로직, 도메인 예외 설계, 서비스 비대화 해결, 로직 분리.
  NOT for: 단순 CRUD (비즈니스 규칙 없으면 domain layer 불필요),
  SQLAlchemy 모델 작성, 단순 dataclass 문법.
---

# Domain Layer

## 적용 판단 기준

비즈니스 규칙이 존재하면 domain layer는 **필수**. 단순 CRUD만 있으면 생략.

| 신호 | 판단 |
|------|------|
| 상태 전이, 검증 규칙, 계산 로직 존재 | domain layer 필수 |
| 단순 Create/Read/Update/Delete | Application Service에서 직접 처리 |
| "if 조건이면 안 됨" 류의 규칙 2개 이상 | domain layer 필수 |

## 디렉토리 구조

```
src/{domain}/
  domain/
    entities.py          # Entity, Aggregate Root
    value_objects.py     # Value Objects, StrEnum
    services.py          # Domain Service (순수 계산)
    events.py            # Domain Events
    repositories.py      # Repository Protocol (Port)
  exceptions/
    domain.py            # Domain 예외 (domain/ 바깥)
  application/
    service.py           # Application Service
  infrastructure/
    repository.py        # Repository 구현 (Adapter)
```

**MUST**: `exceptions/domain.py`는 `domain/` 폴더 바깥에 위치. domain/ 내부가 아님.

## 핵심 원칙

### Domain Purity

domain/ 폴더 내부는 **순수 Python만** 허용.

- **MUST**: `import` 금지 대상 -- FastAPI, SQLAlchemy, Pydantic, 외부 라이브러리
- **MUST**: 허용 대상 -- stdlib, typing, dataclasses, collections.abc, enum, re, decimal
- **MUST**: 인프라 조회 금지 -- 필요한 데이터는 외부에서 주입 (인자로 전달)

### Value Object

`@dataclass(frozen=True, slots=True)` -- 불변, 식별자 없음, 자체 검증.

- `__post_init__`에서 불변식 검증
- 동등성은 값 기반 (dataclass 기본 동작)
- 팩토리 메서드로 생성 편의 제공

### Entity (Rich Domain Model)

`@dataclass(slots=True)` -- 식별자 보유, 비즈니스 규칙 강제, 이벤트 수집.

**MUST: Rich Domain Model 패턴 적용.** Entity는 데이터 컨테이너가 아니라 비즈니스 규칙의 단일 진입점이다.

- **MUST**: 상태 변경은 Entity 메서드를 통해서만. 외부에서 필드 직접 수정 금지
- **MUST**: 비즈니스 규칙(검증, 상태 전이, 계산)은 Entity 내부에 배치. Service에 분산 금지
- **MUST**: `_domain_events: list = field(default_factory=list, init=False, repr=False)`
- **MUST**: `pull_domain_events() -> list` 메서드 제공
- **MUST**: 상태 변경 메서드에서 불변식 검증 후 이벤트 기록
- 멱등성 고려 (이미 같은 상태면 무시)
- 팩토리 메서드(`create()`)로 생성 시 필수 검증 보장

Anemic Domain (Entity에 getter/setter만 있고 Service에 로직이 분산되는 패턴)은 **안티패턴**이다.

### Aggregate Root

일관성 경계. 하위 Entity 접근은 반드시 Root를 통해서만.

- **MUST**: 외부에서 하위 Entity 직접 수정 금지
- **MUST**: Repository는 Aggregate Root 단위로 정의
- 트랜잭션 경계 = Aggregate 경계

### StrEnum (상태 전이)

`class Status(StrEnum)` -- 전이 규칙을 VO로 캡슐화.

- `can_transition_to(next) -> bool`
- `transition_to(next) -> Self` (불가능 시 도메인 예외)
- 전이 맵은 모듈 수준 상수로 정의

## Repository Protocol

```python
@runtime_checkable
class OrderRepository(Protocol):
    async def find_by_id(self, order_id: int) -> Order | None: ...
    async def save(self, order: Order) -> Order: ...
```

- **MUST**: `typing.Protocol` 사용, domain/ 내부에 정의
- **MUST**: 반환 타입은 domain Entity (ORM 모델 아님)
- Infrastructure Adapter에서 ORM <-> Entity 변환 담당

## Domain Service vs Application Service

| 구분 | Domain Service | Application Service |
|------|---------------|---------------------|
| 위치 | `domain/services.py` | `application/service.py` |
| 의존성 | 순수 Python only | Repository, EventBus, Session |
| 역할 | Aggregate 간 순수 계산/검증 | 유스케이스 오케스트레이션 |
| 테스트 | 순수 단위 테스트 | Mock repository 단위 테스트 |

### Application Service 책임

- **MUST**: 트랜잭션 경계 관리
- **MUST**: Entity에서 이벤트 pull 후 발행 (트랜잭션 커밋 이후)
- **MUST**: 캐싱은 Application Service 레벨에서만 (domain layer 금지)
- 유스케이스 오케스트레이션 (Repository 호출, Entity 메서드 호출, 결과 반환)

## Domain Event 흐름

```
Entity.action()                        # 1. Entity가 이벤트 기록
  -> self._record_event(SomeEvent)

ApplicationService.use_case()          # 2. 트랜잭션 커밋 후 pull & publish
  -> entity = repo.find_by_id(id)
  -> entity.action()
  -> repo.save(entity)
  -> events = entity.pull_domain_events()
  -> for event in events: event_bus.emit(event)
```

- **MUST**: Entity 내부에서만 `_record_event` 호출
- **MUST**: ApplicationService에서만 `pull_domain_events` 호출
- **MUST**: 이벤트 발행은 트랜잭션 커밋 성공 이후

## Domain 예외

위치: `{domain}/exceptions/domain.py` (domain/ 폴더 바깥)

- 비즈니스 규칙 위반을 표현하는 커스텀 예외
- HTTP 상태 코드, FastAPI 의존성 등 포함 금지
- 예외 -> HTTP 변환은 `exceptions/mappings.py`에서 별도 처리

## Verification Checklist

구현 완료 후 반드시 확인:

- [ ] domain/ 내부에 FastAPI, SQLAlchemy, Pydantic import가 없는가 (DIP)
- [ ] exceptions/domain.py가 domain/ 폴더 바깥에 있는가
- [ ] Entity에 `_domain_events` 필드와 `pull_domain_events()` 메서드가 있는가
- [ ] Value Object가 `frozen=True, slots=True`인가
- [ ] Entity가 `slots=True`인가
- [ ] Repository Protocol이 domain Entity를 반환하는가 (DIP)
- [ ] 캐싱이 domain layer 밖에 있는가
- [ ] 상태 전이 로직이 StrEnum 또는 Entity 메서드에 캡슐화되었는가
- [ ] Application Service가 트랜잭션 커밋 후 이벤트를 발행하는가
- [ ] Entity가 Rich Domain Model인가 (비즈니스 메서드 보유, getter/setter만 있는 Anemic 아닌가)
- [ ] Service에 `if entity.status == ...` 같은 규칙 판단이 분산되어 있지 않은가 (SRP)
