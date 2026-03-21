# Python Best Practices Gotchas

## 자주 발생하는 실수

### 1. Optional[X] 레거시 문법 사용
❌ `from typing import Optional` → `Optional[str]`
→ ✅ `str | None` — Python 3.10+ 문법 사용. `typing.Optional` import 금지

프로젝트는 Python 3.13+를 요구한다. 레거시 타입 힌트는 코드 리뷰에서 거부된다.

### 2. @dataclass에 slots=True 누락
❌ `@dataclass` — 기본값은 `__dict__` 사용 (메모리 낭비, 속도 저하)
→ ✅ `@dataclass(slots=True)` 또는 `@dataclass(frozen=True, slots=True)`

slots=True는 메모리 효율과 속성 접근 속도를 개선한다. 항상 명시하라.

### 3. from typing import List, Dict 사용
❌ `from typing import List, Dict, Tuple, Set` → `List[int]`, `Dict[str, int]`
→ ✅ `list[int]`, `dict[str, int]`, `tuple[str, ...]`, `set[int]` — builtin 제네릭 사용

Python 3.9+부터 builtin 타입이 제네릭을 지원한다. typing import가 불필요하다.

### 4. try/except Exception — 너무 넓은 catch
❌ `except Exception:` 또는 `except:` — 모든 예외를 삼킴
→ ✅ 구체적 예외 타입을 catch. `except (ValueError, KeyError):` 형태

넓은 catch는 디버깅을 어렵게 만들고, 예상치 못한 에러를 숨긴다.

### 5. f-string 안에서 비싼 연산
❌ `logger.debug(f"Result: {expensive_query()}")` — 로그 레벨과 무관하게 항상 실행
→ ✅ `logger.debug("Result: %s", expensive_query())` 또는 레벨 체크 후 f-string

structlog 사용 시에도 마찬가지. 바인딩 시점에 비싼 연산이 실행되면 성능 저하.

### 6. Sequence를 typing에서 import
❌ `from typing import Sequence`
→ ✅ `from collections.abc import Sequence`

typing 모듈의 컬렉션 타입은 Python 3.9+에서 deprecated이다. collections.abc를 사용하라.

### 7. class Status(str, Enum) 패턴
❌ `class Status(str, Enum):` — 레거시 패턴
→ ✅ `class Status(StrEnum):` — Python 3.11+에서 제공하는 StrEnum 사용

StrEnum은 자동으로 문자열 비교를 지원하고, `str` mixin보다 명확하다.

### 8. 반환 타입에 문자열 forward reference 사용
❌ `def create(self) -> "ClassName":` — self 반환 시 문자열 참조
→ ✅ `def create(self) -> Self:` — `from typing import Self` 사용

Self 타입은 상속 시에도 정확한 타입을 보장한다. 문자열 참조는 불필요하다.
