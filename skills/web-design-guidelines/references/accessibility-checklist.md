# WCAG 2.1 AA 접근성 체크리스트 상세

## 시맨틱 HTML

### A1.1: 시맨틱 요소 사용

`<div>`, `<span>`으로 인터랙티브 요소를 만들지 말 것.

```tsx
// Bad
<div onClick={handleClick} className="button">Click me</div>

// Good
<button onClick={handleClick}>Click me</button>
```

### A1.2: aria-label 필수

아이콘 전용 버튼, 이미지 링크 등 텍스트 없는 인터랙티브 요소.

```tsx
// Bad
<button onClick={onClose}><XIcon /></button>

// Good
<button onClick={onClose} aria-label="닫기"><XIcon /></button>
```

### A1.3: 헤딩 계층구조

h1 -> h2 -> h3 순서 준수. 건너뛰기 금지.

```tsx
// Bad: h1 다음에 바로 h3
<h1>페이지 제목</h1>
<h3>섹션 제목</h3>

// Good
<h1>페이지 제목</h1>
<h2>섹션 제목</h2>
```

### A1.4: alt 텍스트

모든 `<img>`에 의미 있는 alt 텍스트. 장식 이미지는 `alt=""`.

```tsx
// 정보 이미지
<img src="/chart.png" alt="2024년 분기별 매출 추이 그래프" />

// 장식 이미지
<img src="/divider.png" alt="" role="presentation" />
```

### A1.5: 키보드 핸들러 동반

`onClick`만 있는 비-버튼 요소에는 `onKeyDown`과 `role`, `tabIndex` 필수.

```tsx
// Good (하지만 button이 더 나음)
<div
  role="button"
  tabIndex={0}
  onClick={handleSelect}
  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleSelect(); }}
>
  Select
</div>

// Best
<button onClick={handleSelect}>Select</button>
```

### A1.6: ARIA 라이브 영역

동적으로 변하는 콘텐츠(토스트, 에러 메시지)에 `aria-live` 적용.

```tsx
<div role="alert" aria-live="polite">
  {errorMessage}
</div>
```

### A1.7: 스킵 내비게이션

반복되는 내비게이션을 건너뛸 수 있는 링크 제공.

```tsx
<a href="#main-content" className="sr-only focus:not-sr-only">
  메인 콘텐츠로 건너뛰기
</a>
```

### A1.8: 색상 대비

텍스트와 배경 간 최소 대비 비율:
- 일반 텍스트 (< 18pt): **4.5:1**
- 큰 텍스트 (>= 18pt 또는 14pt bold): **3:1**
- UI 컴포넌트/그래픽: **3:1**

검증 도구:
- Chrome DevTools > Accessibility
- axe DevTools 확장
- Contrast Checker (WebAIM)

### A1.9: role="status" 로딩 표시

```tsx
<div role="status" aria-label="로딩 중">
  <Spinner />
</div>
```

---

## 포커스 관리

### F2.1: focus-visible 사용

마우스 클릭 시 포커스 링 숨기고, 키보드 탐색 시에만 표시.

```css
button:focus-visible {
  outline: 2px solid blue;
  outline-offset: 2px;
}

button:focus:not(:focus-visible) {
  outline: none;
}
```

### F2.2: Tailwind focus-visible 클래스

```tsx
// Bad
<button className="focus:ring-2 focus:ring-blue-500">

// Good
<button className="focus-visible:ring-2 focus-visible:ring-blue-500">
```

### F2.3: 포커스 트래핑 (모달)

모달, 다이얼로그 내에서 Tab 키가 모달 밖으로 나가지 않도록.

```tsx
// native dialog 사용 (자동 포커스 트래핑)
<dialog ref={dialogRef}>
  <form method="dialog">
    <input autoFocus />
    <button>확인</button>
  </form>
</dialog>
```

### F2.4: 포커스 복원

모달 닫힐 때 이전에 포커스되었던 요소로 복귀.

```tsx
const triggerRef = useRef<HTMLButtonElement>(null);

function openModal() {
  triggerRef.current = document.activeElement as HTMLButtonElement;
  setOpen(true);
}

function closeModal() {
  setOpen(false);
  triggerRef.current?.focus();
}
```

### F2.5: tabIndex 관리

`tabIndex` > 0 사용 금지. 0 또는 -1만 사용.

| 값 | 용도 |
|----|------|
| 0 | 자연스러운 탭 순서에 포함 |
| -1 | 프로그래밍 방식으로만 포커스 가능 |
| > 0 | **금지** — 탭 순서 혼란 |

---

## 폼 접근성

### FM3.1: autocomplete 속성

```tsx
<input type="email" name="email" autoComplete="email" />
<input type="password" autoComplete="current-password" />
<input type="text" autoComplete="name" />
<input type="tel" autoComplete="tel" />
<input type="text" autoComplete="address-line1" />
```

### FM3.3: 인라인 에러 메시지

```tsx
<div>
  <label htmlFor="email">이메일</label>
  <input
    id="email"
    aria-describedby="email-error"
    aria-invalid={!!error}
  />
  {error && (
    <p id="email-error" role="alert" className="text-red-500">
      {error}
    </p>
  )}
</div>
```

### FM3.4: label 연결

```tsx
// Bad
<span>이메일</span>
<input type="email" />

// Good: htmlFor
<label htmlFor="email">이메일</label>
<input id="email" type="email" />

// Good: 감싸기
<label>
  이메일
  <input type="email" />
</label>
```

### FM3.5: 필수 필드 표시

```tsx
<label htmlFor="name">
  이름 <span aria-hidden="true" className="text-red-500">*</span>
</label>
<input id="name" required aria-required="true" />
```

---

## 모션 접근성

### prefers-reduced-motion 존중

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

```tsx
// JS에서 확인
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;
```
