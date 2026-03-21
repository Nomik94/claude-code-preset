# Webapp Testing Gotchas

## 자주 발생하는 실수

### 1. networkidle 대기 안 함
❌ 페이지 이동 후 바로 요소 검색 → 아직 로딩 중이라 요소 없음
→ ✅ `page.goto(url, wait_until="networkidle")` 또는 특정 요소 대기 사용

SPA는 초기 HTML 로드 후 API 호출로 콘텐츠를 채운다. 네트워크 완료까지 대기해야 한다.

### 2. 브라우저 종료 누락
❌ 테스트 실패 시 브라우저 인스턴스가 정리되지 않아 리소스 누수
→ ✅ `try/finally` 또는 fixture에서 `browser.close()` 보장

브라우저 프로세스가 쌓이면 CI 서버 메모리가 고갈되어 이후 테스트가 모두 실패한다.

### 3. 하드코딩된 셀렉터 사용 (data-testid 미사용)
❌ `page.locator("div.main-content > div:nth-child(3) > span")` — 깨지기 쉬운 셀렉터
→ ✅ `page.get_by_test_id("user-name")` 또는 `page.get_by_role("button", name="제출")`

CSS 구조가 바뀌면 하드코딩된 셀렉터는 전부 깨진다. 의미 기반 셀렉터를 사용하라.

### 4. async playwright 사용 (sync를 써야 하는 경우)
❌ pytest에서 `async_playwright`를 사용하여 이벤트 루프 충돌
→ ✅ pytest에서는 `sync_playwright` 사용. async가 필요하면 `pytest-playwright` 플러그인 활용

pytest-asyncio와 playwright의 이벤트 루프가 충돌하면 예측 불가능한 행데드락이 발생한다.

### 5. 고정 대기 시간(sleep) 사용
❌ `time.sleep(3)` — 느린 환경에서는 부족하고, 빠른 환경에서는 낭비
→ ✅ `page.wait_for_selector()`, `expect(locator).to_be_visible()` — 조건 기반 대기

고정 sleep은 CI 환경에서 flaky 테스트의 가장 큰 원인이다.

### 6. 테스트 간 상태 격리 안 됨
❌ 이전 테스트에서 로그인한 상태가 다음 테스트에 영향
→ ✅ 각 테스트에서 새 브라우저 컨텍스트 생성 또는 `context.clear_cookies()` 호출

쿠키, localStorage, 세션이 공유되면 테스트 순서에 따라 결과가 달라진다.

### 7. 스크린샷/트레이스 미설정
❌ 테스트 실패 시 원인 파악을 위한 증거가 없음
→ ✅ `--screenshot on-failure`, `--tracing retain-on-failure` 옵션 설정

실패 시 스크린샷과 트레이스가 없으면 CI에서 재현이 불가능한 실패를 디버깅할 수 없다.
