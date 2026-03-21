# Web Design Guidelines Gotchas

## 자주 발생하는 실수

### 1. div에 onClick — 버튼을 사용해야 함
❌ `<div onClick={handleClick}>클릭</div>` — 키보드 접근 불가, 스크린 리더 인식 불가
→ ✅ `<button onClick={handleClick}>클릭</button>` — 네이티브 시맨틱 요소 사용

div는 포커스, 키보드 이벤트, ARIA 역할이 없다. 접근성 트리에서 무시된다.

### 2. transition: all 사용
❌ `transition: all 0.3s ease` — 의도하지 않은 속성까지 전환
→ ✅ `transition: transform 0.3s ease, opacity 0.3s ease` — 필요한 속성만 명시

`all`은 layout 속성(width, height)까지 전환하여 성능 저하와 예기치 않은 애니메이션을 유발한다.

### 3. aria-label 누락
❌ 아이콘만 있는 버튼에 텍스트 레이블 없음: `<button><Icon /></button>`
→ ✅ `<button aria-label="메뉴 열기"><Icon /></button>` — 접근 가능한 이름 제공

시각적 아이콘만으로는 스크린 리더 사용자가 버튼의 기능을 알 수 없다.

### 4. user-scalable=no 설정
❌ `<meta name="viewport" content="..., user-scalable=no">` — 확대/축소 비활성화
→ ✅ `user-scalable=no` 제거. 사용자가 콘텐츠를 확대할 수 있어야 함

저시력 사용자의 접근성을 심각하게 해친다. WCAG 위반이다.

### 5. color만으로 상태 표현
❌ 에러 상태를 빨간색으로만 표시 — 색맹 사용자가 구분 불가
→ ✅ 색상 + 아이콘 + 텍스트로 상태 표현. 색상은 보조 수단

전체 인구의 약 8% (남성 기준)가 색각 이상이다. 색상만으로 정보를 전달하면 안 된다.

### 6. focus 스타일 제거
❌ `outline: none` — 키보드 사용자가 현재 포커스 위치를 알 수 없음
→ ✅ `outline: none` 사용 시 대체 포커스 스타일 제공 (box-shadow, border 등)

포커스 인디케이터는 키보드 네비게이션의 필수 요소다. 제거하면 WCAG 2.4.7 위반.

### 7. 고정 단위(px)만 사용
❌ `font-size: 16px`, `padding: 20px` — 사용자 설정 무시
→ ✅ `font-size: 1rem`, `padding: 1.25rem` — 상대 단위 사용

px 고정값은 사용자의 브라우저 글꼴 크기 설정을 무시한다.
