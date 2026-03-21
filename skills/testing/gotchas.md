# Testing Gotchas

## 자주 발생하는 실수

### 1. 실제 DB 대신 mock만 사용
❌ Repository를 전부 mock으로 대체하여 실제 쿼리가 동작하는지 검증 안 함
→ ✅ Unit은 mock, Integration은 실제 DB (testcontainers 또는 테스트 DB) 사용

mock만 쓰면 SQL 문법 에러, 제약조건 위반, 트랜잭션 문제를 전혀 잡지 못한다.

### 2. fixture 스코프 실수 (session vs function)
❌ DB session fixture를 `scope="session"`으로 설정하여 테스트 간 데이터 오염
→ ✅ DB session은 `scope="function"` 기본. 각 테스트가 독립된 트랜잭션 사용

session 스코프 fixture는 한 테스트의 데이터가 다른 테스트에 영향을 미친다.

### 3. assert 하나도 없는 테스트
❌ API를 호출만 하고 `assert` 없이 "에러 안 나면 통과" 방식
→ ✅ 모든 테스트에 최소 1개의 명시적 assert. 상태 코드 + 응답 본문 검증

assert 없는 테스트는 아무것도 검증하지 않는다. 잘못된 응답도 통과한다.

### 4. 테스트 간 상태 공유로 순서 의존성
❌ test_A가 만든 데이터를 test_B가 사용 → test_A 없이 test_B 실행 시 실패
→ ✅ 각 테스트가 자체 setup/teardown으로 필요한 데이터를 독립적으로 생성

`pytest --randomly` 플러그인으로 순서 의존성을 발견할 수 있다.

### 5. async 테스트에서 이벤트 루프 문제
❌ `@pytest.mark.asyncio` 누락하거나 `asyncio_mode` 설정 없이 async 테스트 작성
→ ✅ `pytest.ini`에 `asyncio_mode = "auto"` 설정하거나 매 테스트에 마크 추가

async 테스트가 sync로 실행되면 coroutine 객체만 반환되고 실제 실행이 안 된다.

### 6. 테스트 데이터 하드코딩
❌ 테스트마다 `email="test@test.com"` 같은 고정값 사용 → unique 제약조건 충돌
→ ✅ factory 패턴이나 faker로 동적 테스트 데이터 생성

고정 데이터는 병렬 실행이나 테스트 순서 변경 시 충돌한다.

### 7. 에러 케이스 테스트 누락
❌ 성공 케이스만 테스트하고 실패/예외 상황은 검증 안 함
→ ✅ 정상 + 에러(400, 401, 404, 422, 409) + 엣지 케이스 모두 테스트

에러 핸들링 버그는 프로덕션에서 가장 흔한 장애 원인이다.
