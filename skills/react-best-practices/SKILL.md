---
name: react-best-practices
description: |
  Use when React/Next.js 코드 리뷰, 성능 최적화, 새 컴포넌트 작성 시.
  NOT for 백엔드 전용 로직, 순수 CSS 디자인 작업.
---

# React / Next.js 성능 최적화 가이드

> Vercel Engineering 기반 React/Next.js 성능 최적화 규칙 모음.
> 모든 규칙은 우선순위(P0~P8)로 분류되며, 높을수록 먼저 적용.

---

## P0: 패키지 매니저

### R0.1: pnpm 필수

npm/yarn 사용 금지. pnpm만 허용.

```bash
# ❌ Bad
npm install
yarn add react

# ✅ Good
pnpm install
pnpm add react
```

### R0.2: lockfile 일관성

`pnpm-lock.yaml`만 커밋. `package-lock.json`, `yarn.lock` 존재 시 삭제.

---

## P1: Waterfall 제거

### R1.1: 병렬 데이터 패칭 — Promise.all

순차 await는 워터폴을 만든다. 독립적인 요청은 `Promise.all`로 병렬화.

```tsx
// ❌ Bad — 순차 워터폴
const user = await getUser(id);
const posts = await getPosts(id);
const comments = await getComments(id);

// ✅ Good — 병렬 패칭
const [user, posts, comments] = await Promise.all([
  getUser(id),
  getPosts(id),
  getComments(id),
]);
```

### R1.2: defer await 패턴

빠른 데이터 먼저 표시, 느린 데이터는 Suspense로 스트리밍.

```tsx
// ❌ Bad — 모든 데이터 대기 후 렌더
async function Page() {
  const data = await slowFetch();
  return <Component data={data} />;
}

// ✅ Good — defer await + Suspense
async function Page() {
  const dataPromise = slowFetch(); // await 하지 않음
  const fastData = await fastFetch();
  return (
    <>
      <FastComponent data={fastData} />
      <Suspense fallback={<Skeleton />}>
        <SlowComponent dataPromise={dataPromise} />
      </Suspense>
    </>
  );
}
```

### R1.3: Suspense 경계 세분화

페이지 전체가 아닌 느린 부분만 Suspense로 감싸기.

```tsx
// ❌ Bad — 페이지 전체 로딩
<Suspense fallback={<PageSkeleton />}>
  <EntirePage />
</Suspense>

// ✅ Good — 부분 Suspense
<Header />
<Suspense fallback={<FeedSkeleton />}>
  <Feed />
</Suspense>
<Suspense fallback={<SidebarSkeleton />}>
  <Sidebar />
</Suspense>
```

### R1.4: loading.tsx 활용

Next.js App Router에서 `loading.tsx`는 자동 Suspense 경계.

```
app/
  dashboard/
    page.tsx
    loading.tsx  ← 자동 Suspense 경계
```

### R1.5: 라우트 프리패칭

`<Link>` 컴포넌트 사용으로 자동 프리패칭 활성화. `router.push` 남용 금지.

```tsx
// ❌ Bad
<button onClick={() => router.push('/dashboard')}>Go</button>

// ✅ Good
<Link href="/dashboard">Go</Link>
```

---

## P2: 번들 크기

### R2.1: 배럴 파일 금지

`export * from` 패턴은 tree-shaking을 방해한다.

```tsx
// ❌ Bad — 배럴 파일 (index.ts)
export * from './Button';
export * from './Modal';
export * from './Table';

// 사용측에서 하나만 써도 전부 번들링됨
import { Button } from '@/components';

// ✅ Good — 직접 임포트
import { Button } from '@/components/Button';
```

### R2.2: dynamic import로 코드 스플릿

초기 로드에 불필요한 컴포넌트는 `next/dynamic` 사용.

```tsx
// ❌ Bad — 무조건 번들 포함
import { HeavyEditor } from '@/components/HeavyEditor';

// ✅ Good — 필요 시 로드
import dynamic from 'next/dynamic';
const HeavyEditor = dynamic(() => import('@/components/HeavyEditor'), {
  loading: () => <EditorSkeleton />,
});
```

### R2.3: 'use client' 경계 최소화

클라이언트 컴포넌트는 필요한 리프 노드에만 적용. 부모에 `'use client'` 금지.

```tsx
// ❌ Bad — 페이지 전체가 클라이언트
'use client';
export default function Page() {
  const [count, setCount] = useState(0);
  return (
    <Layout>
      <Header />
      <Counter count={count} setCount={setCount} />
      <Footer />
    </Layout>
  );
}

// ✅ Good — 인터랙티브 부분만 클라이언트
// Counter.tsx
'use client';
export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// Page.tsx (서버 컴포넌트)
export default function Page() {
  return (
    <Layout>
      <Header />
      <Counter />
      <Footer />
    </Layout>
  );
}
```

### R2.4: 이미지 최적화

`next/image` 필수. `<img>` 태그 직접 사용 금지.

```tsx
// ❌ Bad
<img src="/hero.png" alt="hero" />

// ✅ Good
import Image from 'next/image';
<Image src="/hero.png" alt="hero" width={800} height={400} priority />
```

### R2.5: 패키지 크기 의식

무거운 라이브러리 도입 전 번들 크기 확인. `date-fns` > `moment`, `clsx` > `classnames`.

---

## P3: 서버 사이드

### R3.1: React.cache로 요청 중복 제거

동일 렌더 트리에서 같은 데이터를 여러 곳에서 필요로 할 때.

```tsx
// ❌ Bad — 중복 패칭
// Header.tsx
const user = await getUser(id);
// Sidebar.tsx
const user = await getUser(id);

// ✅ Good — React.cache로 자동 중복 제거
import { cache } from 'react';
export const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } });
});
```

### R3.2: RSC 직렬화 최소화

서버 컴포넌트에서 클라이언트로 넘기는 props를 최소화. 전체 객체 대신 필요한 필드만.

```tsx
// ❌ Bad — 전체 객체 직렬화
<ClientComponent user={fullUserObject} />

// ✅ Good — 필요한 필드만
<ClientComponent userName={user.name} userAvatar={user.avatar} />
```

### R3.3: Server Actions 활용

폼 제출과 뮤테이션에 Server Actions 사용. API 라우트 불필요.

```tsx
// ❌ Bad — 클라이언트에서 API 호출
'use client';
async function handleSubmit(data: FormData) {
  await fetch('/api/submit', { method: 'POST', body: data });
}

// ✅ Good — Server Action
async function submitForm(formData: FormData) {
  'use server';
  await db.insert(formData.get('email'));
  revalidatePath('/');
}

export default function Form() {
  return <form action={submitForm}><input name="email" /><button>Submit</button></form>;
}
```

### R3.4: unstable_cache / revalidateTag 조합

세밀한 캐시 무효화 전략 수립.

```tsx
import { unstable_cache, revalidateTag } from 'next/cache';

const getCachedPosts = unstable_cache(
  async () => db.post.findMany(),
  ['posts'],
  { tags: ['posts'], revalidate: 60 }
);

// 뮤테이션 후
revalidateTag('posts');
```

---

## P4: 클라이언트 데이터

### R4.1: SWR로 클라이언트 데이터 패칭

클라이언트 컴포넌트에서의 데이터 패칭은 SWR 사용.

```tsx
// ❌ Bad — useEffect + useState
const [data, setData] = useState(null);
const [loading, setLoading] = useState(true);
useEffect(() => {
  fetch('/api/data').then(r => r.json()).then(setData).finally(() => setLoading(false));
}, []);

// ✅ Good — SWR
import useSWR from 'swr';
const { data, error, isLoading } = useSWR('/api/data', fetcher);
```

### R4.2: SWR 글로벌 설정

`SWRConfig`로 공통 설정 관리.

```tsx
<SWRConfig value={{
  fetcher: (url: string) => fetch(url).then(r => r.json()),
  revalidateOnFocus: false,
  dedupingInterval: 2000,
}}>
  {children}
</SWRConfig>
```

### R4.3: useSWRSubscription으로 실시간 데이터

WebSocket/SSE 등 실시간 데이터 스트림 구독.

```tsx
import useSWRSubscription from 'swr/subscription';

const { data } = useSWRSubscription('/api/stream', (key, { next }) => {
  const source = new EventSource(key);
  source.onmessage = (e) => next(null, JSON.parse(e.data));
  source.onerror = (e) => next(e);
  return () => source.close();
});
```

### R4.4: Optimistic UI

뮤테이션 시 서버 응답 전에 UI 먼저 업데이트.

```tsx
const { trigger } = useSWRMutation('/api/todos', addTodo, {
  optimisticData: (current) => [...current, newTodo],
  rollbackOnError: true,
});
```

---

## P5: 리렌더링 방지

### R5.1: 상태 읽기 지연

상태를 사용하지 않는 컴포넌트에서 읽지 말 것.

```tsx
// ❌ Bad — 부모가 불필요하게 상태 보유
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <>
      <ExpensiveTree />
      <Counter count={count} setCount={setCount} />
    </>
  );
}

// ✅ Good — 상태를 사용하는 곳으로 내리기
function Parent() {
  return (
    <>
      <ExpensiveTree />
      <Counter />
    </>
  );
}

function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

### R5.2: React.memo 적절히 사용

비용이 큰 순수 컴포넌트에 memo 적용. 남용 금지.

```tsx
// ✅ Good — 비싼 리스트 아이템
const ListItem = React.memo(function ListItem({ item }: { item: Item }) {
  return <div>{expensiveFormat(item)}</div>;
});
```

### R5.3: functional setState

이전 상태 기반 업데이트 시 함수형 업데이터 사용.

```tsx
// ❌ Bad — 클로저 stale 가능
setCount(count + 1);

// ✅ Good — 함수형 업데이터
setCount(prev => prev + 1);
```

### R5.4: useMemo / useCallback 적절 사용

참조 안정성이 필요한 경우에만. 원시값에는 불필요.

```tsx
// ❌ Bad — 불필요한 memo
const name = useMemo(() => user.name, [user.name]);

// ✅ Good — 비싼 계산 또는 참조 안정성
const sortedItems = useMemo(
  () => items.toSorted((a, b) => a.date - b.date),
  [items]
);

const handleClick = useCallback(
  (id: string) => dispatch({ type: 'SELECT', id }),
  [dispatch]
);
```

### R5.5: children을 활용한 리렌더링 격리

상태 변경이 children에 전파되지 않도록 구성.

```tsx
// ✅ Good — ScrollTracker가 리렌더되어도 children은 유지
function ScrollTracker({ children }: { children: React.ReactNode }) {
  const [scrollY, setScrollY] = useState(0);
  useEffect(() => {
    const handler = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handler);
    return () => window.removeEventListener('scroll', handler);
  }, []);
  return <div data-scroll={scrollY}>{children}</div>;
}
```

---

## P6: 렌더링 성능

### R6.1: 정적 JSX 호이스팅

변하지 않는 JSX를 컴포넌트 밖으로 추출.

```tsx
// ❌ Bad — 매 렌더마다 재생성
function Component() {
  const icon = <Icon size={24} />;
  return <div>{icon}</div>;
}

// ✅ Good — 컴포넌트 밖에서 한 번만 생성
const icon = <Icon size={24} />;
function Component() {
  return <div>{icon}</div>;
}
```

### R6.2: content-visibility: auto

뷰포트 밖 콘텐츠 렌더링 지연.

```css
/* ✅ Good */
.offscreen-section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px;
}
```

### R6.3: 조건부 렌더링 최적화

early return 활용으로 불필요한 렌더 트리 방지.

```tsx
// ❌ Bad
function Component({ isVisible }: { isVisible: boolean }) {
  const expensiveData = useExpensiveHook();
  if (!isVisible) return null;
  return <div>{expensiveData}</div>;
}

// ✅ Good — 조건 충족 시에만 마운트
function Wrapper({ isVisible }: { isVisible: boolean }) {
  if (!isVisible) return null;
  return <Component />;
}

function Component() {
  const expensiveData = useExpensiveHook();
  return <div>{expensiveData}</div>;
}
```

### R6.4: 긴 리스트 가상화

50개 이상 아이템 리스트는 가상화 필수.

```tsx
// ❌ Bad — 1000개 DOM 노드
{items.map(item => <ListItem key={item.id} item={item} />)}

// ✅ Good — 가상화
import { useVirtualizer } from '@tanstack/react-virtual';
```

---

## P7: JS 성능

### R7.1: Map/Set 활용

빈번한 조회/존재 확인에는 Object 대신 Map/Set 사용.

```tsx
// ❌ Bad — O(n) 조회
const isSelected = selectedIds.includes(id);

// ✅ Good — O(1) 조회
const selectedSet = new Set(selectedIds);
const isSelected = selectedSet.has(id);
```

### R7.2: RegExp 호이스팅

반복 호출되는 함수 안에서 RegExp 재생성 금지.

```tsx
// ❌ Bad — 매 호출마다 RegExp 생성
function validate(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// ✅ Good — 한 번만 생성
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function validate(email: string) {
  return EMAIL_RE.test(email);
}
```

### R7.3: 비파괴 배열 메서드

`.toSorted()`, `.toReversed()`, `.toSpliced()` 사용으로 불변성 유지.

```tsx
// ❌ Bad — 원본 변경
const sorted = items.sort((a, b) => a.name.localeCompare(b.name));

// ✅ Good — 새 배열 반환
const sorted = items.toSorted((a, b) => a.name.localeCompare(b.name));
```

### R7.4: structuredClone 활용

깊은 복사에 JSON.parse(JSON.stringify()) 대신 `structuredClone` 사용.

```tsx
// ❌ Bad
const copy = JSON.parse(JSON.stringify(original));

// ✅ Good
const copy = structuredClone(original);
```

---

## P8: 고급

### R8.1: useRef로 이벤트 핸들러 안정화

콜백이 최신 값을 참조하되 참조 안정성 유지.

```tsx
// ❌ Bad — 매 렌더마다 새 함수 → 자식 리렌더
function Parent({ onClick }: { onClick: (id: string) => void }) {
  return <Child onClick={(id) => onClick(id)} />;
}

// ✅ Good — ref로 최신 값 유지 + 안정적 참조
function useStableCallback<T extends (...args: any[]) => any>(callback: T): T {
  const ref = useRef(callback);
  ref.current = callback;
  return useCallback((...args: any[]) => ref.current(...args), []) as T;
}
```

### R8.2: useEffectEvent (React 19+)

Effect 내에서 최신 props/state를 읽되 Effect 의존성에 포함시키지 않기.

```tsx
// ❌ Bad — onTick이 변할 때마다 Effect 재실행
useEffect(() => {
  const id = setInterval(() => onTick(), 1000);
  return () => clearInterval(id);
}, [onTick]);

// ✅ Good — useEffectEvent (React 19+)
const stableOnTick = useEffectEvent(onTick);
useEffect(() => {
  const id = setInterval(() => stableOnTick(), 1000);
  return () => clearInterval(id);
}, []);
```

### R8.3: Transition API 활용

비긴급 업데이트를 `startTransition`으로 표시하여 UI 반응성 유지.

```tsx
import { useTransition } from 'react';

const [isPending, startTransition] = useTransition();

function handleSearch(query: string) {
  // 긴급: 입력 필드 업데이트
  setInputValue(query);
  // 비긴급: 결과 필터링
  startTransition(() => {
    setFilteredResults(filterResults(query));
  });
}
```

---

## 체크리스트 요약

| 우선순위 | 핵심 규칙 | 확인 |
|---------|----------|------|
| P0 | pnpm 사용 여부 | [ ] |
| P1 | 순차 await → Promise.all 전환 | [ ] |
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
