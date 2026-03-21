# Security Audit Gotchas

## 자주 발생하는 실수

### 1. JWT secret을 코드에 하드코딩
❌ `SECRET_KEY = "my-super-secret-key"` — 소스 코드에 시크릿 직접 작성
→ ✅ 환경 변수(`pydantic-settings`)로 관리. prod에서는 시크릿 매니저 사용

소스 코드에 포함된 시크릿은 git 히스토리에 영구히 남는다. 한 번 노출되면 전체 교체 필요.

### 2. Rate limiting 없는 인증 엔드포인트
❌ `/login`, `/register`, `/reset-password`에 rate limiting 미적용
→ ✅ 인증 관련 엔드포인트에 IP 기반 rate limiting 필수. 429 + Retry-After 헤더

brute force 공격으로 비밀번호가 탈취되거나, 대량 회원가입으로 리소스가 고갈될 수 있다.

### 3. SQL f-string 조합
❌ `f"SELECT * FROM users WHERE id = {user_id}"` — SQL injection 취약
→ ✅ `session.execute(select(User).where(User.id == user_id))` — ORM/파라미터 바인딩 사용

f-string으로 조합된 SQL은 입력값에 의한 SQL injection 공격에 노출된다.

### 4. 에러 메시지에 스택 트레이스 노출
❌ 프로덕션 API 응답에 `traceback`, `__file__`, 내부 경로 포함
→ ✅ prod에서는 일반적 에러 메시지만 반환. 상세 정보는 서버 로그에만 기록

스택 트레이스는 내부 구조, 라이브러리 버전, 파일 경로를 노출하여 공격 표면을 넓힌다.

### 5. CORS wildcard + credentials 조합
❌ `allow_origins=["*"]` + `allow_credentials=True` — 프로덕션에서 사용
→ ✅ 프로덕션에서는 허용된 도메인 목록을 명시. wildcard와 credentials 동시 사용 금지

이 조합은 모든 도메인에서 인증된 요청을 허용하여 CSRF 공격에 취약해진다.

### 6. 비밀번호 해싱에 MD5/SHA 사용
❌ `hashlib.md5(password)` 또는 `hashlib.sha256(password)` — 범용 해시 사용
→ ✅ `pwdlib`(argon2) 사용. bcrypt도 차선. 범용 해시 함수는 비밀번호용이 아님

MD5/SHA는 속도가 빨라서 brute force에 취약하다. argon2는 의도적으로 느리게 설계됨.

### 7. 권한 검사 누락
❌ 인증(Authentication)만 확인하고 인가(Authorization) 검사 없음
→ ✅ 리소스 소유자 확인, 역할 기반 접근 제어(RBAC) 적용

로그인한 사용자가 다른 사용자의 데이터를 조회/수정할 수 있으면 IDOR 취약점이다.
