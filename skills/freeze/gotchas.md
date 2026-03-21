# freeze gotchas — Claude가 자주 틀리는 패턴

### 1. 상대 경로로 freeze 설정
❌ `freeze src/` → 현재 디렉토리 기준이라 이동 시 깨짐
→ ✅ 절대 경로 사용

### 2. 테스트 파일 수정 차단
❌ freeze로 `src/`만 허용했는데 `tests/` 수정 필요
→ ✅ 테스트 디렉토리도 함께 허용 목록에 추가

### 3. freeze 해제 잊고 다른 작업 시작
❌ 디버깅 끝나고 freeze 해제 안 하고 다른 기능 구현 시작
→ ✅ 작업 전환 시 freeze 상태 확인 습관화
