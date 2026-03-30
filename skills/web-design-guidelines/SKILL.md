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

## 1. 접근성 (Accessibility)
- 시맨틱 HTML (`<button>`, `<a>`, `<nav>`). `<div onClick>` 금지
- 아이콘 버튼에 `aria-label` 필수
- 헤딩 계층 준수 (h1→h2→h3, 건너뛰기 금지)
- 모든 `<img>`에 alt (장식은 `alt=""`)
- 동적 콘텐츠에 `aria-live`
- 색상 대비: 일반 4.5:1, 큰 텍스트 3:1

> 상세 체크리스트 → references/accessibility-checklist.md

## 2. 포커스 (Focus)
- `focus-visible` 사용 (Tailwind: `focus-visible:ring-2`)
- 모달: 포커스 트래핑 + 닫힐 때 복원
- `tabIndex` > 0 금지 (0 또는 -1만)

## 3. 폼 (Forms)
- 모든 입력에 `autocomplete`, `<label>` 연결 (`htmlFor`)
- paste 차단 금지
- 인라인 에러: 필드 아래, `aria-describedby` + `aria-invalid`
- 제출 중 `disabled` + "처리 중..." 표시

## 4. 애니메이션 (Animation)
- `prefers-reduced-motion` 존중
- `transform`/`opacity`만 (레이아웃 트리거 금지)
- `transition: all` 금지, `will-change` 남용 금지

## 5. 타이포그래피
- 말줄임: `text-overflow: ellipsis` + `overflow: hidden`
- 숫자 열: `font-variant-numeric: tabular-nums`
- 줄 높이: 본문 1.5~1.75, 제목 1.1~1.3
- 최대 줄 너비: `max-width: 65ch`

## 6. 성능 (Performance)
- **50개 이상 리스트 가상화** (`@tanstack/react-virtual`)
- 레이아웃 읽기 배칭
- 폰트 `<link rel="preload">` + `font-display: swap`
- 뷰포트 밖 이미지 `loading="lazy"`
- 빈번한 이벤트 디바운스/스로틀

> Core Web Vitals, 가상화 코드 → references/performance-rules.md

## 7. 내비게이션
- UI 상태를 URL 쿼리 파라미터에 반영
- 파괴적 액션 확인 모달 필수
- 모달/드로어 뒤로가기로 닫기 가능
- 현재 위치 `aria-current="page"`
- 외부 링크: `target="_blank"` + `rel="noopener noreferrer"` + 아이콘

## 8. 다크모드
- `color-scheme: light dark` 선언
- `<meta name="theme-color">` 라이트/다크 분리
- CSS 변수 기반 테마 (하드코딩 색상 금지)
- 기본값: 시스템 설정 + 수동 전환

## 9. 안티패턴

| 안티패턴 | 대안 |
|---------|------|
| `user-scalable=no` | 제거 |
| `transition: all` | 명시적 속성 |
| `<div onClick>` | `<button>` |
| `outline: none` (대안 없이) | `focus-visible` |
| `onPaste={e => e.preventDefault()}` | 제거 |
| `tabIndex` > 0 | 0 또는 -1 |
| `<a>` without `href` | `<button>` |

## 리뷰 체크리스트

```
[ ] 시맨틱 HTML (div/span 남용 없음)
[ ] 인터랙티브 요소 키보드 접근 가능
[ ] aria-label / alt 적절
[ ] focus-visible 스타일
[ ] 폼: autocomplete, label, 인라인 에러
[ ] prefers-reduced-motion 대응
[ ] transition: all 없음
[ ] URL에 UI 상태 반영
[ ] 다크모드 CSS 변수 기반
[ ] 안티패턴 해당 없음
```
