# New API Gotchas

## Claude가 자주 틀리는 패턴

### 1. router prefix 중복
- `EndpointPath`에 이미 prefix가 있는데 router에도 중복 지정
- 해결: `EndpointPath`를 사용하면 router prefix는 빈 문자열

### 2. DTO 네이밍 혼동
- Request/Response DTO를 `Schema`로 네이밍
- 해결: `{Action}{Domain}Request` / `{Action}{Domain}Response` 패턴 사용

### 3. repository 메서드에서 직접 commit
- service 레이어가 아닌 repository에서 `session.commit()` 호출
- 해결: repository는 `flush`만, commit은 service 또는 UoW에서

### 4. 테스트 파일에서 실제 DB 의존
- `conftest.py` 없이 테스트 작성하여 DB 연결 실패
- 해결: `/testing` 스킬의 conftest_template.py 참조
