---
name: new-page
description: |
  Use when creating a new page or route in Next.js App Router.
  NOT for modifying existing pages or creating API routes.
---

# /new-page -- Next.js App Router 페이지 스캐폴딩

라우트 파일 + 컴포넌트 + 로딩/에러 경계를 한 번에 스캐폴딩.

## 입력

| 파라미터 | 필수 | 설명 | 예시 |
|----------|------|------|------|
| 라우트 경로 | O | App Router 경로 | `/dashboard`, `/users/[id]` |
| 페이지 유형 | O | 렌더링 전략 | `SSG`, `SSR`, `CSR` |
| 레이아웃 | X | 전용 레이아웃 (기본: false) | `true` |
| 404 페이지 | X | not-found (기본: false) | `true` |

## 생성 파일

```
app/{route}/
├── page.tsx, loading.tsx, error.tsx
├── not-found.tsx (선택), layout.tsx (선택)
components/{route}/
├── {PageName}Content.tsx, {PageName}Skeleton.tsx
```

## 생성 순서

1. **page.tsx** -- Server Component, metadata export
2. **loading.tsx** -- Suspense 로딩 스켈레톤
3. **error.tsx** -- 에러 경계 (`"use client"` 필수)
4. **not-found.tsx** / **layout.tsx** (선택)
5. **components/** -- 페이지 전용 컴포넌트

## 필수 규칙

- **Server Component 우선**: 상호작용 필요 시에만 `"use client"`
- **TypeScript strict**: `any` 금지
- **Tailwind CSS**: 인라인 스타일 금지
- **접근성**: 시맨틱 HTML, aria-label, 키보드 내비게이션
- **metadata**: 모든 page.tsx에 필수

### 페이지 유형별 패턴

- **SSG**: `generateStaticParams()`로 빌드 타임 경로
- **SSR**: `export const dynamic = "force-dynamic"`
- **CSR**: `"use client"` + useEffect/useState 페칭

### 컴포넌트 규칙
- 파일 1개 = 컴포넌트 1개
- Props는 `interface`로 정의, `export default function`
- 이벤트 핸들러 필요 시에만 `"use client"`

### 네이밍
- 컴포넌트: PascalCase.tsx / 라우트: Next.js 규칙 / Props: `{ComponentName}Props`

## 템플릿

`skills/new-page/templates/`의 `.tmpl` 파일 참조.

플레이스홀더: `{PageName}` Pascal / `{routePath}` URL / `{description}` 설명

## 체크리스트

- [ ] page.tsx metadata export
- [ ] error.tsx `"use client"`
- [ ] loading.tsx 스켈레톤 UI
- [ ] 시맨틱 HTML + aria 속성
- [ ] 키보드 내비게이션
- [ ] tsc --noEmit + ESLint 통과
- [ ] 반응형 (모바일 우선)
- [ ] next/image, next/link 사용
