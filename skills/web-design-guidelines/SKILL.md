---
name: web-design-guidelines
description: |
  Use when UI 컴포넌트 코드 리뷰, 접근성 검수, 디자인 시스템 준수 여부 확인 시.
  NOT for 백엔드 API 로직, 순수 비즈니스 로직 리뷰.
files:
  - references/accessibility-checklist.md
  - references/performance-rules.md
---

# Web Interface Guidelines

> Vercel Web Interface Guidelines 기반 UI 코드 리뷰 스킬.
> 접근성, 포커스, 폼, 애니메이션, 타이포그래피, 성능, 내비게이션, 다크모드 전반을 다룸.

---

## 1. 접근성 (Accessibility) 핵심 규칙

- 시맨틱 HTML 사용 (`<button>`, `<a>`, `<nav>`). `<div onClick>` 금지
- 아이콘 전용 버튼에 `aria-label` 필수
- 헤딩 계층구조 준수 (h1 -> h2 -> h3, 건너뛰기 금지)
- 모든 `<img>`에 alt 텍스트 (장식은 `alt=""`)
- 동적 콘텐츠에 `aria-live` 적용
- 색상 대비: 일반 텍스트 4.5:1, 큰 텍스트 3:1

> 상세 체크리스트 및 코드 예시는 references/accessibility-checklist.md 참조

---

## 2. 포커스 (Focus) 핵심 규칙

- `focus-visible` 사용 (마우스 클릭 시 포커스 링 숨기기)
- Tailwind: `focus-visible:ring-2` (focus:ring-2 아님)
- 모달: 포커스 트래핑 + 닫힐 때 포커스 복원
- `tabIndex` > 0 사용 금지 (0 또는 -1만)

---

## 3. 폼 (Forms) 핵심 규칙

- 모든 입력에 `autocomplete` 속성
- paste 차단 금지
- 인라인 에러 메시지 (필드 바로 아래, `aria-describedby` + `aria-invalid`)
- 모든 입력에 `<label>` 연결 (`htmlFor`)
- 제출 중 `disabled` + "처리 중..." 표시

---

## 4. 애니메이션 (Animation) 핵심 규칙

- `prefers-reduced-motion` 존중
- `transform`/`opacity`만 애니메이션 (레이아웃 트리거 금지)
- `transition: all` 금지 (명시적 속성만)
- `will-change` 남용 금지 (호버 시에만)

---

## 5. 타이포그래피 (Typography)

- 말줄임표: `text-overflow: ellipsis` + `overflow: hidden`
- 숫자 열: `font-variant-numeric: tabular-nums`
- 줄 높이: 본문 1.5~1.75, 제목 1.1~1.3
- 최대 줄 너비: `max-width: 65ch`

---

## 6. 성능 (Performance) 핵심 규칙

- **50개 이상 리스트 가상화** (`@tanstack/react-virtual`)
- 레이아웃 읽기 배칭 (읽기 먼저, 쓰기 나중에)
- 폰트 `<link rel="preload">` + `font-display: swap`
- 뷰포트 밖 이미지 `loading="lazy"`
- 빈번한 이벤트에 디바운스/스로틀
- `contain: layout style paint` (독립적 섹션)

> Core Web Vitals 목표, 가상화 코드, CSS Containment 상세는 references/performance-rules.md 참조

---

## 7. 내비게이션 (Navigation)

- 필터/검색/페이지 등 UI 상태를 URL 쿼리 파라미터에 반영
- 파괴적 액션(삭제) 확인 모달 필수
- 모달/드로어는 뒤로가기로 닫을 수 있어야 함
- 현재 위치 `aria-current="page"` 표시
- 외부 링크: `target="_blank"` + `rel="noopener noreferrer"` + 아이콘

---

## 8. 다크모드 (Dark Mode)

- `color-scheme: light dark` 선언
- `<meta name="theme-color">` 라이트/다크 분리
- CSS 변수 기반 테마 (하드코딩 색상 금지)
- 다크모드 이미지 대응 (밝기 조정 또는 대체)
- 기본값: 시스템 설정 + 수동 전환 옵션

---

## 9. 안티패턴 플래그

| 안티패턴 | 대안 |
|---------|------|
| `user-scalable=no` | 제거 |
| `transition: all` | 명시적 속성 |
| `<div onClick>` | `<button>` |
| `outline: none` (대안 없이) | `focus-visible` |
| `onPaste={e => e.preventDefault()}` | 제거 |
| `tabIndex` > 0 | 0 또는 -1 |
| `<a>` without `href` | `<button>` |
| `* { outline: none }` | `focus-visible` |

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
