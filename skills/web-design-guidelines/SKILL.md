---
name: web-design-guidelines
description: |
  Use when UI 컴포넌트 코드 리뷰, 접근성 검수, 디자인 시스템 준수 여부 확인 시.
  NOT for 백엔드 API 로직, 순수 비즈니스 로직 리뷰.
---

# Web Interface Guidelines

> Vercel Web Interface Guidelines 기반 UI 코드 리뷰 스킬.
> 접근성, 포커스, 폼, 애니메이션, 타이포그래피, 성능, 내비게이션, 다크모드 전반을 다룸.

---

## 1. 접근성 (Accessibility)

### A1.1: 시맨틱 HTML 사용

`<div>`, `<span>`으로 인터랙티브 요소를 만들지 말 것.

```tsx
// ❌ Bad
<div onClick={handleClick} className="button">Click me</div>

// ✅ Good
<button onClick={handleClick}>Click me</button>
```

### A1.2: aria-label 필수

아이콘 전용 버튼, 이미지 링크 등 텍스트 없는 인터랙티브 요소.

```tsx
// ❌ Bad
<button onClick={onClose}><XIcon /></button>

// ✅ Good
<button onClick={onClose} aria-label="닫기"><XIcon /></button>
```

### A1.3: 헤딩 계층구조

h1 → h2 → h3 순서 준수. 건너뛰기 금지.

```tsx
// ❌ Bad — h1 다음에 바로 h3
<h1>페이지 제목</h1>
<h3>섹션 제목</h3>

// ✅ Good
<h1>페이지 제목</h1>
<h2>섹션 제목</h2>
```

### A1.4: alt 텍스트

모든 `<img>`에 의미 있는 alt 텍스트. 장식 이미지는 `alt=""`.

```tsx
// ❌ Bad
<img src="/chart.png" />

// ✅ Good — 정보 이미지
<img src="/chart.png" alt="2024년 분기별 매출 추이 그래프" />

// ✅ Good — 장식 이미지
<img src="/divider.png" alt="" role="presentation" />
```

### A1.5: 키보드 핸들러 동반

`onClick`만 있는 비-버튼 요소에는 `onKeyDown`과 `role`, `tabIndex` 필수.

```tsx
// ❌ Bad
<div onClick={handleSelect}>Select</div>

// ✅ Good — 하지만 button이 더 나음
<div
  role="button"
  tabIndex={0}
  onClick={handleSelect}
  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleSelect(); }}
>
  Select
</div>

// ✅ Best
<button onClick={handleSelect}>Select</button>
```

### A1.6: ARIA 라이브 영역

동적으로 변하는 콘텐츠(토스트, 에러 메시지)에 `aria-live` 적용.

```tsx
// ✅ Good
<div role="alert" aria-live="polite">
  {errorMessage}
</div>
```

### A1.7: 스킵 내비게이션

반복되는 내비게이션을 건너뛸 수 있는 링크 제공.

```tsx
// ✅ Good
<a href="#main-content" className="sr-only focus:not-sr-only">
  메인 콘텐츠로 건너뛰기
</a>
```

### A1.8: 색상 대비

텍스트와 배경 간 최소 대비 비율: 일반 텍스트 4.5:1, 큰 텍스트 3:1.

### A1.9: role="status" 로딩 표시

로딩 스피너에 스크린리더 안내.

```tsx
<div role="status" aria-label="로딩 중">
  <Spinner />
</div>
```

---

## 2. 포커스 (Focus)

### F2.1: focus-visible 사용

마우스 클릭 시 포커스 링 숨기고, 키보드 탐색 시에만 표시.

```css
/* ❌ Bad — 마우스 클릭에도 포커스 링 */
button:focus {
  outline: 2px solid blue;
}

/* ✅ Good */
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
// ❌ Bad
<button className="focus:ring-2 focus:ring-blue-500">

// ✅ Good
<button className="focus-visible:ring-2 focus-visible:ring-blue-500">
```

### F2.3: 포커스 트래핑 (모달)

모달, 다이얼로그 내에서 Tab 키가 모달 밖으로 나가지 않도록.

```tsx
// ✅ Good — native dialog
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

---

## 3. 폼 (Forms)

### FM3.1: autocomplete 속성

모든 입력 필드에 적절한 `autocomplete` 값 지정.

```tsx
// ❌ Bad
<input type="email" name="email" />

// ✅ Good
<input type="email" name="email" autoComplete="email" />
<input type="password" autoComplete="current-password" />
<input type="text" autoComplete="name" />
```

### FM3.2: paste 차단 금지

비밀번호, 이메일 등의 입력에서 붙여넣기를 차단하지 말 것.

```tsx
// ❌ Bad
<input onPaste={(e) => e.preventDefault()} />

// ✅ Good — paste 허용
<input type="email" />
```

### FM3.3: 인라인 에러 메시지

에러는 해당 필드 바로 아래에 표시. 상단 배너만 사용 금지.

```tsx
// ❌ Bad — 페이지 상단 에러만
<div className="error-banner">입력값을 확인하세요</div>

// ✅ Good — 인라인 에러
<div>
  <label htmlFor="email">이메일</label>
  <input id="email" aria-describedby="email-error" aria-invalid={!!error} />
  {error && <p id="email-error" role="alert" className="text-red-500">{error}</p>}
</div>
```

### FM3.4: label 연결

모든 입력 필드에 `<label>` 연결. `htmlFor` 또는 감싸기.

```tsx
// ❌ Bad
<span>이메일</span>
<input type="email" />

// ✅ Good
<label htmlFor="email">이메일</label>
<input id="email" type="email" />
```

### FM3.5: 필수 필드 표시

`required` 속성 + 시각적 표시.

```tsx
<label htmlFor="name">
  이름 <span aria-hidden="true" className="text-red-500">*</span>
</label>
<input id="name" required aria-required="true" />
```

### FM3.6: 제출 중 비활성화

폼 제출 중 중복 제출 방지.

```tsx
<button type="submit" disabled={isSubmitting}>
  {isSubmitting ? '처리 중...' : '제출'}
</button>
```

---

## 4. 애니메이션 (Animation)

### AN4.1: prefers-reduced-motion 존중

모션 감소 설정 사용자를 위한 대체.

```css
/* ✅ Good */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

```tsx
// ✅ Good — JS에서 확인
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
```

### AN4.2: transform/opacity만 사용

레이아웃 트리거(width, height, top, left) 애니메이션 금지.

```css
/* ❌ Bad — 레이아웃 트리거 */
.slide {
  transition: left 0.3s ease;
}

/* ✅ Good — 합성 레이어만 */
.slide {
  transition: transform 0.3s ease;
}
```

### AN4.3: transition: all 금지

명시적 속성만 전환.

```css
/* ❌ Bad */
.card {
  transition: all 0.3s ease;
}

/* ✅ Good */
.card {
  transition: opacity 0.3s ease, transform 0.3s ease;
}
```

### AN4.4: will-change 남용 금지

실제로 성능 문제가 있는 경우에만 사용. 항상 켜두지 말 것.

```css
/* ❌ Bad — 항상 적용 */
.element {
  will-change: transform;
}

/* ✅ Good — 호버 시에만 */
.element:hover {
  will-change: transform;
}
```

### AN4.5: 진입/퇴장 애니메이션

요소 추가/제거 시 부드러운 전환.

```css
/* ✅ Good — CSS @starting-style (최신 브라우저) */
dialog[open] {
  opacity: 1;
  transition: opacity 0.3s ease;

  @starting-style {
    opacity: 0;
  }
}
```

---

## 5. 타이포그래피 (Typography)

### T5.1: 말줄임표 처리

넘치는 텍스트에 `text-overflow: ellipsis`.

```css
/* ✅ Good */
.truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ✅ Good — 여러 줄 말줄임 */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

### T5.2: 곱슬 따옴표 (Smart Quotes)

HTML 엔티티 또는 유니코드 사용.

```tsx
// ❌ Bad
<p>"Hello World"</p>

// ✅ Good
<p>&ldquo;Hello World&rdquo;</p>
<p>&lsquo;Hello&rsquo;</p>
```

### T5.3: tabular-nums

숫자 열 정렬에 고정 폭 숫자.

```css
/* ✅ Good */
.price, .quantity, .date {
  font-variant-numeric: tabular-nums;
}
```

### T5.4: 적절한 줄 높이

본문 텍스트 1.5~1.75, 제목 1.1~1.3.

### T5.5: 최대 줄 너비

읽기 편한 줄 너비 유지 (약 65~75자).

```css
/* ✅ Good */
.prose {
  max-width: 65ch;
}
```

---

## 6. 성능 (Performance)

### PF6.1: 50개 이상 리스트 가상화

긴 리스트는 `@tanstack/react-virtual` 등으로 가상화.

```tsx
// ❌ Bad — 1000개 아이템 전부 렌더
{items.map(item => <Row key={item.id} {...item} />)}

// ✅ Good — 가상화
import { useVirtualizer } from '@tanstack/react-virtual';
```

### PF6.2: 레이아웃 읽기 배칭

`offsetHeight`, `getBoundingClientRect()` 등 레이아웃 읽기를 쓰기와 분리.

```tsx
// ❌ Bad — 강제 리플로우 (읽기-쓰기-읽기)
element.style.width = '100px';
const height = element.offsetHeight;
element.style.height = height + 'px';

// ✅ Good — 읽기를 먼저, 쓰기를 나중에
const height = element.offsetHeight;
requestAnimationFrame(() => {
  element.style.width = '100px';
  element.style.height = height + 'px';
});
```

### PF6.3: 폰트 preload

커스텀 폰트는 `<link rel="preload">`로 사전 로드.

```html
<!-- ✅ Good -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin />
```

### PF6.4: 이미지 lazy loading

뷰포트 밖 이미지는 `loading="lazy"`.

```tsx
// ❌ Bad — 모든 이미지 즉시 로드
<img src="/photo.jpg" alt="photo" />

// ✅ Good — Above the fold 이미지만 즉시 로드
<img src="/hero.jpg" alt="hero" loading="eager" />
<img src="/below-fold.jpg" alt="content" loading="lazy" />
```

### PF6.5: 디바운스/스로틀

빈번한 이벤트(scroll, resize, input)에 디바운스 적용.

```tsx
// ✅ Good
import { useDebouncedCallback } from 'use-debounce';

const handleSearch = useDebouncedCallback((value: string) => {
  search(value);
}, 300);
```

### PF6.6: CSS Containment

독립적 섹션에 `contain: layout style paint` 적용.

---

## 7. 내비게이션 (Navigation)

### N7.1: URL 상태 반영

필터, 검색어, 페이지 등 UI 상태를 URL 쿼리 파라미터에 반영.

```tsx
// ❌ Bad — URL에 상태 없음
const [filter, setFilter] = useState('all');

// ✅ Good — URL 쿼리 파라미터
import { useSearchParams } from 'next/navigation';
const searchParams = useSearchParams();
const filter = searchParams.get('filter') ?? 'all';
```

### N7.2: 파괴적 액션 확인

삭제, 초기화 등 되돌릴 수 없는 액션에 확인 모달.

```tsx
// ❌ Bad — 즉시 삭제
<button onClick={handleDelete}>삭제</button>

// ✅ Good — 확인 단계
<AlertDialog>
  <AlertDialogTrigger asChild>
    <button>삭제</button>
  </AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogTitle>정말 삭제하시겠습니까?</AlertDialogTitle>
    <AlertDialogDescription>이 작업은 되돌릴 수 없습니다.</AlertDialogDescription>
    <AlertDialogAction onClick={handleDelete}>삭제</AlertDialogAction>
    <AlertDialogCancel>취소</AlertDialogCancel>
  </AlertDialogContent>
</AlertDialog>
```

### N7.3: 브라우저 뒤로가기 지원

모달, 드로어 등은 뒤로가기로 닫을 수 있어야 함.

### N7.4: 현재 위치 표시

내비게이션에서 현재 페이지/탭을 시각적으로 + `aria-current="page"`로 표시.

```tsx
<nav>
  <a href="/dashboard" aria-current={pathname === '/dashboard' ? 'page' : undefined}>
    대시보드
  </a>
</nav>
```

### N7.5: 외부 링크 표시

외부 링크에 아이콘 + `target="_blank"` + `rel="noopener noreferrer"`.

```tsx
<a href="https://external.com" target="_blank" rel="noopener noreferrer">
  외부 사이트 <ExternalLinkIcon aria-hidden="true" />
</a>
```

---

## 8. 다크모드 (Dark Mode)

### D8.1: color-scheme 선언

```css
/* ✅ Good */
:root {
  color-scheme: light dark;
}

/* 또는 강제 다크 */
:root[data-theme="dark"] {
  color-scheme: dark;
}
```

### D8.2: theme-color 메타 태그

모바일 브라우저 상태바 색상 매칭.

```html
<!-- ✅ Good -->
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
<meta name="theme-color" content="#0a0a0a" media="(prefers-color-scheme: dark)" />
```

### D8.3: CSS 변수 기반 테마

하드코딩된 색상 대신 CSS 변수 사용.

```css
/* ❌ Bad */
.card { background: white; color: black; }

/* ✅ Good */
:root {
  --bg-primary: #ffffff;
  --text-primary: #171717;
}
[data-theme="dark"] {
  --bg-primary: #0a0a0a;
  --text-primary: #ededed;
}
.card { background: var(--bg-primary); color: var(--text-primary); }
```

### D8.4: 이미지/아이콘 다크모드 대응

다크모드에서 이미지 밝기 조정 또는 대체 이미지.

```css
/* ✅ Good */
@media (prefers-color-scheme: dark) {
  img.invertible {
    filter: invert(1) hue-rotate(180deg);
  }
}
```

### D8.5: 시스템 설정 + 수동 전환

기본값은 시스템 설정 따르되, 수동 전환 옵션 제공.

---

## 9. 안티패턴 플래그

아래 패턴 발견 시 즉시 수정 권고:

| 안티패턴 | 이유 | 대안 |
|---------|------|------|
| `user-scalable=no` | 접근성 위반 — 확대 차단 | 제거 |
| `transition: all` | 의도하지 않은 속성까지 전환 | 명시적 속성 지정 |
| `<div onClick>` | 키보드/스크린리더 미지원 | `<button>` 사용 |
| `outline: none` (without alternative) | 포커스 표시 제거 | `focus-visible` 사용 |
| `onPaste={e => e.preventDefault()}` | 붙여넣기 차단 | 제거 |
| `tabIndex` > 0 | 탭 순서 혼란 | 0 또는 -1 사용 |
| `<a>` without `href` | 시맨틱 위반 | `<button>` 사용 |
| `role="button"` on `<div>` | 키보드 지원 누락 | `<button>` 사용 |
| `autoFocus` on non-modal | 페이지 스크롤 점프 | 제거 |
| `* { outline: none }` | 전역 포커스 표시 제거 | focus-visible 사용 |

---

## 리뷰 체크리스트

```
[ ] 시맨틱 HTML 사용 (div/span 남용 없음)
[ ] 모든 인터랙티브 요소에 키보드 접근 가능
[ ] aria-label / alt 텍스트 적절
[ ] focus-visible 스타일 적용
[ ] 폼에 autocomplete, label, 인라인 에러
[ ] prefers-reduced-motion 대응
[ ] transition: all 없음
[ ] URL에 UI 상태 반영
[ ] 다크모드 CSS 변수 기반
[ ] 안티패턴 플래그 해당 없음
```
