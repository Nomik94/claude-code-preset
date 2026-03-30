---
name: react-best-practices
description: |
  Use when React/Next.js 코드 리뷰, 성능 최적화, 새 컴포넌트 작성 시.
  NOT for 백엔드 전용 로직, 순수 CSS 디자인 작업.
files:
  - references/server-components.md
  - references/bundle-optimization.md
  - references/data-fetching.md
---

# React / Next.js 성능 최적화 가이드

> 우선순위(P0~P8) 순 적용.

## P0: 패키지 매니저
- **pnpm 필수**. npm/yarn 금지
- `pnpm-lock.yaml`만 커밋

## P1: Waterfall 제거
- 순차 await → `Promise.all` 병렬화
- defer await: 빠른 데이터 먼저, 느린 데이터 Suspense 스트리밍
- Suspense 경계 세분화 (느린 부분만)
- `loading.tsx` 활용, `<Link>` 사용 (router.push 남용 금지)

> 코드 예시 → references/server-components.md, references/data-fetching.md

## P2: 번들 크기
- **배럴 파일 금지** (`export * from`). 직접 임포트
- `next/dynamic` 코드 스플릿
- **'use client' 리프 노드만**. 부모 금지
- `next/image` 필수 (`<img>` 금지)

> dynamic import, tree-shaking → references/bundle-optimization.md

## P3: 서버 사이드
- `React.cache` 요청 중복 제거
- RSC 직렬화 최소화 (필요 필드만 props)
- Server Actions (폼/뮤테이션에 API 라우트 불필요)
- `unstable_cache`/`revalidateTag` 캐시 무효화

> RSC, Server Actions 상세 → references/server-components.md

## P4: 클라이언트 데이터
- SWR 사용 (`useEffect`+`useState` 금지)
- `SWRConfig` 글로벌 설정
- `useSWRSubscription` 실시간 (WebSocket/SSE)
- Optimistic UI: `useSWRMutation` + `rollbackOnError`

> SWR vs Server Actions vs Route Handlers → references/data-fetching.md

## P5: 리렌더링 방지
- 상태를 사용처로 내리기
- `React.memo`: 비용 큰 순수 컴포넌트에만
- 함수형 setState: `setCount(prev => prev + 1)`
- `useMemo`/`useCallback`: 참조 안정성 필요 시만
- children 패턴으로 리렌더링 격리

## P6: 렌더링 성능
- 정적 JSX 호이스팅
- `content-visibility: auto`
- 조건부 렌더링: early return
- **50개 이상 리스트 가상화** (`@tanstack/react-virtual`)

## P7: JS 성능
- `Map`/`Set` (빈번 조회 O(1))
- RegExp 호이스팅
- `.toSorted()`, `.toReversed()`, `.toSpliced()`
- `structuredClone`

## P8: 고급
- `useRef`로 이벤트 핸들러 안정화
- `useEffectEvent` (React 19+)
- `startTransition`: 비긴급 업데이트

## 체크리스트

| 우선순위 | 핵심 규칙 | 확인 |
|---------|----------|------|
| P0 | pnpm 사용 | [ ] |
| P1 | Promise.all 전환, Suspense 세분화 | [ ] |
| P2 | 배럴 파일 제거, 'use client' 리프만 | [ ] |
| P3 | React.cache, Server Actions | [ ] |
| P4 | SWR 사용 | [ ] |
| P5 | 상태 위치 최적화 | [ ] |
| P6 | 긴 리스트 가상화 | [ ] |
| P7 | Map/Set, 비파괴 메서드 | [ ] |
| P8 | 안정적 콜백 패턴 | [ ] |
