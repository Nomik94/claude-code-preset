# Python Best Practices Gotchas

## 자주 발생하는 실수

### 1. try/except Exception — 너무 넓은 catch
❌ `except Exception:` 또는 `except:` — 모든 예외를 삼킴
→ ✅ 구체적 예외 타입을 catch. `except (ValueError, KeyError):` 형태

넓은 catch는 디버깅을 어렵게 만들고, 예상치 못한 에러를 숨긴다.

### 2. f-string 안에서 비싼 연산
❌ `logger.debug(f"Result: {expensive_query()}")` — 로그 레벨과 무관하게 항상 실행
→ ✅ `logger.debug("Result: %s", expensive_query())` 또는 레벨 체크 후 f-string

structlog 사용 시에도 마찬가지. 바인딩 시점에 비싼 연산이 실행되면 성능 저하.
