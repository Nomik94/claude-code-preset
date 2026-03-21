# FastAPI Gotchas

## 자주 발생하는 실수

### 1. async def 안에서 sync I/O 호출
❌ `async def` 함수 내에서 `time.sleep()`, `requests.get()`, `open().read()` 사용
→ ✅ `asyncio.sleep()`, `httpx.AsyncClient`, `aiofiles` 사용. 불가피하면 `run_in_threadpool`

sync I/O는 이벤트 루프를 블로킹하여 전체 서버의 동시 처리 능력을 마비시킨다.

### 2. Depends 반환값을 함수 밖에서 재사용
❌ `db = Depends(get_db)`의 결과를 변수에 저장하여 다른 함수에서 재사용
→ ✅ 각 엔드포인트에서 독립적으로 `Depends(get_db)` 선언

Depends는 요청 스코프 DI이다. 함수 밖에서 재사용하면 세션이 이미 닫혀있다.

### 3. response_model과 실제 return 타입 불일치
❌ `response_model=UserResponse`인데 실제로는 dict나 ORM 모델을 반환
→ ✅ response_model에 맞는 Pydantic 모델 인스턴스를 반환하거나 `from_attributes=True` 설정

불일치 시 직렬화 에러가 발생하거나 의도하지 않은 필드가 노출된다.

### 4. lifespan 대신 on_event 사용
❌ `@app.on_event("startup")` / `@app.on_event("shutdown")` 데코레이터 사용
→ ✅ `@asynccontextmanager` 기반 `lifespan` 함수 사용

`on_event`는 deprecated이다. lifespan 컨텍스트 매니저가 리소스 정리를 보장한다.
