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

> Vercel Engineering 기반 React/Next.js 성능 최적화 규칙 모음.
> 모든 규칙은 우선순위(P0~P8)로 분류되며, 높을수록 먼저 적용.

---

## P0: 패키지 매니저

- **pnpm 필수**. npm/yarn 금지
- `pnpm-lock.yaml`만 커밋. `package-lock.json`, `yarn.lock` 삭제

---

## P1: Waterfall 제거

- 순차 await -> `Promise.all`로 병렬화
- defer await 패턴: 빠른 데이터 먼저 표시, 느린 데이터는 Suspense 스트리밍
- Suspense 경계를 페이지 전체가 아닌 느린 부분만 세분화
- `loading.tsx` 활용 (Next.js 자동 Suspense)
- `<Link>` 사용 (router.push 남용 금지)

> 상세 코드 예시는 references/server-components.md, references/data-fetching.md 참조

---

## P2: 번들 크기

- **배럴 파일 금지** (`export * from`). 직접 임포트
- `next/dynamic`으로 코드 스플릿 (초기 로드 불필요 컴포넌트)
- **'use client' 리프 노드만** 적용. 부모에 금지
- `next/image` 필수 (`<img>` 금지)
- 무거운 라이브러리 도입 전 번들 크기 확인

> dynamic import, tree-shaking, 배럴 파일 대안은 references/bundle-optimization.md 참조

---

## P3: 서버 사이드

- `React.cache`로 요청 중복 제거
- RSC 직렬화 최소화 (필요 필드만 props로 전달)
- Server Actions 활용 (폼 제출/뮤테이션에 API 라우트 불필요)
- `unstable_cache` / `revalidateTag` 조합으로 캐시 무효화

> RSC 패턴, Server Actions 상세는 references/server-components.md 참조

---

## P4: 클라이언트 데이터

- SWR로 클라이언트 데이터 패칭 (`useEffect` + `useState` 금지)
- `SWRConfig`로 글로벌 설정
- `useSWRSubscription`으로 실시간 데이터 (WebSocket/SSE)
- Optimistic UI: `useSWRMutation` + `rollbackOnError`

> SWR, Server Actions, Route Handlers 비교는 references/data-fetching.md 참조

---

## P5: 리렌더링 방지

- 상태를 사용하는 곳으로 내리기 (부모 리렌더링 방지)
- `React.memo`: 비용 큰 순수 컴포넌트에만
- 함수형 setState: `setCount(prev => prev + 1)`
- `useMemo`/`useCallback`: 참조 안정성 필요 시만 (원시값 불필요)
- children 패턴으로 리렌더링 격리

---

## P6: 렌더링 성능

- 정적 JSX 호이스팅 (컴포넌트 밖으로 추출)
- `content-visibility: auto` (뷰포트 밖 렌더링 지연)
- 조건부 렌더링: early return + 조건 충족 시에만 마운트
- **50개 이상 리스트 가상화** (`@tanstack/react-virtual`)

---

## P7: JS 성능

- `Map`/`Set` 활용 (빈번한 조회에 O(1))
- RegExp 호이스팅 (함수 밖에서 한 번만 생성)
- 비파괴 배열 메서드: `.toSorted()`, `.toReversed()`, `.toSpliced()`
- `structuredClone` (JSON.parse(JSON.stringify()) 대신)

---

## P8: 고급

- `useRef`로 이벤트 핸들러 안정화 (`useStableCallback`)
- `useEffectEvent` (React 19+): Effect 내 최신 값, 의존성 미포함
- `startTransition`: 비긴급 업데이트 표시, UI 반응성 유지

---

## 체크리스트 요약

| 우선순위 | 핵심 규칙 | 확인 |
|---------|----------|------|
| P0 | pnpm 사용 여부 | [ ] |
| P1 | 순차 await -> Promise.all 전환 | [ ] |
| P1 | Suspense 경계 세분화 | [ ] |
| P2 | 배럴 파일 제거 | [ ] |
| P2 | 'use client' 리프 노드만 | [ ] |
| P3 | React.cache 적용 | [ ] |
| P3 | Server Actions 활용 | [ ] |
| P4 | SWR 사용 | [ ] |
| P5 | 상태 읽기 위치 최적화 | [ ] |
| P6 | 긴 리스트 가상화 | [ ] |
| P7 | Map/Set, 비파괴 메서드 | [ ] |
| P8 | 안정적 콜백 패턴 | [ ] |
