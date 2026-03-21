# SQLAlchemy Gotchas

## 자주 발생하는 실수

### 1. Session을 요청 스코프 밖에서 사용
❌ 요청 핸들러에서 받은 session을 백그라운드 태스크나 다른 스코프에 전달
→ ✅ 각 스코프에서 새 session 생성. 백그라운드 태스크는 자체 session 사용

요청이 끝나면 session이 닫히므로 다른 스코프에서 사용하면 `DetachedInstanceError`가 발생한다.

### 2. autoflush 이해 부족으로 stale data
❌ 객체를 수정한 후 쿼리하면 자동으로 반영될 거라 가정 (또는 그 반대)
→ ✅ `autoflush=True` 동작을 이해하고, 필요 시 명시적으로 `await session.flush()` 호출

autoflush는 쿼리 실행 전에 pending 변경을 flush하지만, 모든 상황에서 예상대로 동작하지 않는다.

### 3. Alembic autogenerate가 못 잡는 변경
❌ `alembic revision --autogenerate`를 실행하면 모든 스키마 변경이 감지될 거라 가정
→ ✅ 인덱스 이름 변경, CHECK 제약조건, 트리거, 함수는 수동으로 마이그레이션 작성

autogenerate는 컬럼 추가/삭제, 테이블 생성 정도만 안정적으로 감지한다. 세부 제약조건은 누락된다.

### 4. 트랜잭션 안에서 외부 API 호출
❌ DB 트랜잭션 내에서 HTTP 요청, 이메일 전송 등 외부 I/O 수행
→ ✅ 외부 API 호출은 트랜잭션 밖에서 수행. 실패 시 보상 트랜잭션 패턴 사용

트랜잭션 내 외부 호출이 타임아웃되면 커넥션이 장시간 점유되어 DB 커넥션 풀이 고갈된다.

### 5. 벌크 연산 시 ORM 이벤트 미발동
❌ `session.execute(update(User).where(...).values(...))` 후 ORM 이벤트가 실행될 거라 기대
→ ✅ 벌크 UPDATE/DELETE는 ORM 이벤트를 트리거하지 않음. 필요 시 개별 객체 조작

`updated_at` 자동 갱신, 감사 로그 등 ORM 이벤트에 의존하는 로직은 벌크 연산에서 작동하지 않는다.
