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

### 3. lazy="raise" 설정 후 joinedload 누락
❌ relationship에 `lazy="raise"`를 설정했지만 쿼리에서 `joinedload`/`selectinload` 안 씀
→ ✅ relationship 접근이 필요한 모든 쿼리에 명시적 로딩 전략 추가

`lazy="raise"`는 암묵적 lazy loading을 차단한다. 명시적 로딩 없이 접근하면 `InvalidRequestError` 발생.

### 4. Pydantic v2에서 레거시 메서드 사용
❌ `.dict()`, `.parse_obj()`, `@validator`, `class Config:` 사용
→ ✅ `.model_dump()`, `.model_validate()`, `@field_validator`, `model_config = ConfigDict(...)` 사용

Pydantic v2에서 레거시 메서드는 deprecation warning을 발생시키고 향후 제거된다.

### 5. response_model과 실제 return 타입 불일치
❌ `response_model=UserResponse`인데 실제로는 dict나 ORM 모델을 반환
→ ✅ response_model에 맞는 Pydantic 모델 인스턴스를 반환하거나 `from_attributes=True` 설정

불일치 시 직렬화 에러가 발생하거나 의도하지 않은 필드가 노출된다.

### 6. 미들웨어 등록 순서 역전
❌ CORS를 먼저 등록하고 Logging을 나중에 등록 → CORS가 innermost가 됨
→ ✅ 등록 순서: Logging(1번) → RateLimit(2번) → CORS(3번, 마지막). LIFO이므로 CORS가 outermost

`add_middleware`는 LIFO(후입선출)로 실행된다. 마지막 등록이 가장 먼저 실행됨을 기억하라.

### 7. EndpointPath 미사용으로 경로 하드코딩
❌ `@router.get("/app/v1/users")` — 경로 문자열 직접 작성
→ ✅ `EndpointPath("app", 1, "users")`로 경로 생성

하드코딩된 경로는 버전 변경이나 클라이언트 분리 시 일괄 수정이 불가능하다.

### 8. lifespan 대신 on_event 사용
❌ `@app.on_event("startup")` / `@app.on_event("shutdown")` 데코레이터 사용
→ ✅ `@asynccontextmanager` 기반 `lifespan` 함수 사용

`on_event`는 deprecated이다. lifespan 컨텍스트 매니저가 리소스 정리를 보장한다.
