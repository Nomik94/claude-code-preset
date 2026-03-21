---
name: new-page
description: |
  Use when creating a new page or route in Next.js App Router.
  NOT for modifying existing pages or creating API routes.
---

# /new-page — Next.js App Router 페이지 스캐폴딩

## 목적

새로운 페이지 또는 라우트를 생성할 때 사용한다. 라우트 파일 + 컴포넌트 + 로딩/에러 경계를 한 번에 스캐폴딩하여 일관된 구조를 보장한다.

## 입력

| 파라미터 | 필수 | 설명 | 예시 |
|----------|------|------|------|
| 라우트 경로 | O | App Router 기준 경로 | `/dashboard`, `/users/[id]`, `/settings` |
| 페이지 유형 | O | 렌더링 전략 | `SSG`, `SSR`, `CSR` |
| 레이아웃 | X | 전용 레이아웃 생성 여부 | `true` (기본: `false`) |
| 404 페이지 | X | not-found 페이지 생성 여부 | `true` (기본: `false`) |

## 생성 파일 목록

```
app/
└── {route}/
    ├── page.tsx           # 메인 페이지 (Server Component 기본)
    ├── loading.tsx        # 로딩 UI (Suspense 경계)
    ├── error.tsx          # 에러 경계 (Client Component)
    ├── not-found.tsx      # 404 페이지 (선택)
    └── layout.tsx         # 레이아웃 (선택)

components/
└── {route}/
    ├── {PageName}Content.tsx    # 페이지 본문 컴포넌트
    └── {PageName}Skeleton.tsx   # 로딩 스켈레톤 컴포넌트
```

## 생성 순서

1. **page.tsx** — Server Component 기본, metadata export 포함
2. **loading.tsx** — Suspense 경계용 로딩 스켈레톤
3. **error.tsx** — 에러 경계 (반드시 `"use client"`)
4. **not-found.tsx** — 404 페이지 (선택)
5. **layout.tsx** — 레이아웃 (선택)
6. **components/** — 페이지 전용 컴포넌트

## 적용 규칙

### 필수 준수 사항
- **Server Component 우선**: 기본은 Server Component, 상호작용 필요 시에만 `"use client"`
- **TypeScript strict**: 모든 파일에 타입 명시, `any` 금지
- **Tailwind CSS**: 인라인 스타일 금지, Tailwind 유틸리티 클래스 사용
- **접근성(a11y)**: 시맨틱 HTML, `aria-label`, 키보드 내비게이션
- **metadata export**: 모든 page.tsx에 metadata 또는 generateMetadata 필수

### 페이지 유형별 패턴

#### SSG (Static Site Generation)
```tsx
// generateStaticParams로 빌드 타임에 경로 생성
export async function generateStaticParams() { ... }
```

#### SSR (Server-Side Rendering)
```tsx
// 매 요청마다 데이터 fetch
// force-dynamic 또는 revalidate = 0
export const dynamic = "force-dynamic";
```

#### CSR (Client-Side Rendering)
```tsx
"use client";
// useEffect + useState로 클라이언트에서 fetch
// 로딩 상태 직접 관리
```

### 컴포넌트 규칙
- 파일 하나에 컴포넌트 하나 (Single Responsibility)
- Props 타입은 `interface`로 정의
- 기본 export는 `export default function` 사용
- 이벤트 핸들러가 필요한 컴포넌트만 `"use client"`

### 네이밍 규칙
- 컴포넌트 파일: `PascalCase.tsx` (예: `DashboardContent.tsx`)
- 라우트 파일: Next.js 규칙 (예: `page.tsx`, `layout.tsx`)
- Props 인터페이스: `{ComponentName}Props`
- CSS 클래스: Tailwind 유틸리티

## 템플릿 참조

`skills/new-page/templates/` 디렉토리의 `.tmpl` 파일을 참조하여 보일러플레이트를 생성한다.

| 템플릿 | 용도 |
|--------|------|
| `page.tsx.tmpl` | Server Component 페이지 |
| `loading.tsx.tmpl` | 로딩 스켈레톤 |
| `error.tsx.tmpl` | 에러 경계 |
| `layout.tsx.tmpl` | 레이아웃 |

플레이스홀더:
- `{PageName}` — PascalCase (예: `UserProfile`)
- `{routePath}` — URL 경로 (예: `/users/[id]`)
- `{description}` — 페이지 설명 (예: "사용자 프로필 페이지")

## 완료 후 체크리스트

- [ ] `page.tsx`에 metadata export 존재
- [ ] `error.tsx`에 `"use client"` 지시어 존재
- [ ] `loading.tsx`에 스켈레톤 UI 존재
- [ ] 시맨틱 HTML 태그 사용 (`main`, `section`, `article`, `nav` 등)
- [ ] `aria-label` 또는 적절한 접근성 속성 존재
- [ ] 키보드 내비게이션 가능 (탭 이동, Enter 활성화)
- [ ] TypeScript 에러 없음 (`tsc --noEmit` 통과)
- [ ] ESLint 에러 없음
- [ ] 반응형 디자인 (모바일 우선)
- [ ] `<Image>` 컴포넌트 사용 (next/image)
- [ ] `<Link>` 컴포넌트 사용 (next/link)
