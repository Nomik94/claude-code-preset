---
name: debugging
description: |
  Python/FastAPI 디버깅 도구 및 기법 레퍼런스.
  Use when: 디버깅, 버그 찾기, 에러 추적, 왜 안 돼, 문제 해결,
  print 디버깅, pdb, breakpoint, 로그 추적, 쿼리 확인,
  스택 트레이스, traceback, 에러 재현, 느린 원인,
  메모리 누수, 프로파일링, 비동기 디버깅, async 에러.
  NOT for: 에러 핸들링 설계 (error-handling 참조), 성능 최적화 전략 (monitoring 참조).
---

# 디버깅 스킬

## pytest 디버깅 플래그

```bash
# 첫 번째 실패에서 중단
poetry run pytest -x

# 실패 시 pdb 진입
poetry run pytest --pdb

# 마지막 실패한 테스트만 재실행
poetry run pytest --lf

# 실패한 테스트 먼저 실행
poetry run pytest --ff

# 특정 테스트만 실행
poetry run pytest -k "test_create_user"

# print 출력 보이기
poetry run pytest -s

# 조합: 실패 시 디버거 + 출력 표시
poetry run pytest -x -s --pdb
```

## SQLAlchemy 쿼리 디버깅

```python
# 1. echo=True: 모든 SQL 출력
engine = create_async_engine(url, echo=True)

# 2. 특정 요청에서만 쿼리 수 카운팅
from sqlalchemy import event

query_count = 0

@event.listens_for(engine.sync_engine, "before_cursor_execute")
def _count_queries(conn, cursor, statement, *args):
    nonlocal query_count
    query_count += 1

# 3. 느린 쿼리 감지
@event.listens_for(engine.sync_engine, "before_cursor_execute")
def _before(conn, cursor, statement, *args):
    conn.info["query_start"] = time.time()

@event.listens_for(engine.sync_engine, "after_cursor_execute")
def _after(conn, cursor, statement, *args):
    elapsed = time.time() - conn.info["query_start"]
    if elapsed > 0.5:
        logger.warning("slow_query", elapsed=elapsed, sql=statement[:200])
```

## N+1 쿼리 감지

```python
# 증상: 리스트 API에서 아이템 수만큼 SELECT 발생

# 확인: echo=True로 쿼리 수 세기
# N개 SELECT user → N+1 문제

# 해결: selectinload
from sqlalchemy.orm import selectinload

stmt = select(Order).options(
    selectinload(Order.items),
    selectinload(Order.user),
).where(Order.id == order_id)
```

## 비동기 디버깅

```python
# 1. asyncio 디버그 모드
import asyncio
asyncio.get_event_loop().set_debug(True)
# → 코루틴 await 누락, 느린 콜백 경고

# 2. 동기 호출 혼재 감지 (흔한 실수)
# ❌ Wrong: 비동기 컨텍스트에서 동기 DB 호출
def get_user(db, user_id):  # sync!
    return db.query(User).get(user_id)

# ✅ Right: async 전용
async def get_user(db: AsyncSession, user_id: int):
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# 3. await 누락 감지
# mypy가 잡아줌: "Coroutine[...] is not awaited"
# ruff도 감지: RUF006
```

## structlog 디버깅

```python
import structlog

logger = structlog.get_logger()

# 1. 요청 컨텍스트 추적
structlog.contextvars.bind_contextvars(
    request_id=request_id,
    user_id=current_user.id,
)
# 이후 모든 로그에 request_id, user_id 자동 포함

# 2. 특정 흐름 추적
logger.info("order_created", order_id=order.id, items=len(order.items))
logger.warning("stock_low", product_id=pid, remaining=stock)
logger.error("payment_failed", order_id=order.id, reason=str(e))

# 3. 개발 환경: 콘솔 출력 (컬러)
# 프로덕션: JSON 출력 (파싱 가능)
```

## 메모리/성능 프로파일링

```bash
# CPU 프로파일링
poetry run python -m cProfile -s cumulative app/main.py

# 메모리 프로파일링 (설치: poetry add -G dev memray)
poetry run memray run app/main.py
poetry run memray flamegraph output.bin

# 라인별 프로파일링 (설치: poetry add -G dev line-profiler)
# @profile 데코레이터 추가 후:
poetry run kernprof -l -v app/services/heavy_service.py
```

## 흔한 에러 → 원인 매핑

| 에러 | 흔한 원인 | 해결 |
|------|----------|------|
| `MissingGreenlet` | async 컨텍스트에서 lazy load (lazy="raise" 미적용) | lazy="raise" 기본 설정 + `selectinload()` 명시 |
| `DetachedInstanceError` | session 밖에서 relationship 접근 | `expire_on_commit=False` |
| `IntegrityError` | unique 제약 위반 | 중복 체크 로직 추가 |
| `TimeoutError` (DB) | connection pool 고갈 | pool_size 조정, 세션 누수 확인 |
| `422 Unprocessable Entity` | Pydantic 검증 실패 | 요청 바디 확인, 필드 타입 매칭 |
| `RuntimeError: Event loop closed` | 테스트에서 이벤트 루프 재사용 | `asyncio_mode = "auto"` 설정 |
| `sqlalchemy.exc.InvalidRequestError` | 트랜잭션 상태 꼬임 | session lifecycle 확인 |
| `ImportError: circular import` | 순환 의존성 | TYPE_CHECKING 블록 활용 |

## 디버깅 체크리스트

```
에러 발생 시:
1. [ ] 에러 메시지 전체 읽기 (마지막 줄부터)
2. [ ] 스택 트레이스에서 내 코드 위치 찾기
3. [ ] 해당 라인의 변수 값 확인 (print/pdb)
4. [ ] 최소 재현 케이스 만들기 (테스트)
5. [ ] echo=True / structlog로 흐름 추적
6. [ ] 가설 세우고 하나씩 검증
```
