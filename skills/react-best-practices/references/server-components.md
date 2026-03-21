# RSC (React Server Components) 패턴 상세

## 'use client' 최소화 전략

클라이언트 컴포넌트는 필요한 리프 노드에만 적용. 부모에 `'use client'` 금지.

### Bad: 페이지 전체가 클라이언트

```tsx
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
```

### Good: 인터랙티브 부분만 클라이언트

```tsx
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

## RSC 직렬화 최소화

서버 컴포넌트에서 클라이언트로 넘기는 props를 최소화. 전체 객체 대신 필요한 필드만.

```tsx
// Bad: 전체 객체 직렬화
<ClientComponent user={fullUserObject} />

// Good: 필요한 필드만
<ClientComponent userName={user.name} userAvatar={user.avatar} />
```

## React.cache로 요청 중복 제거

동일 렌더 트리에서 같은 데이터를 여러 곳에서 필요로 할 때.

```tsx
import { cache } from 'react';

export const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } });
});

// Header.tsx — 캐시된 결과 재사용
const user = await getUser(id);
// Sidebar.tsx — 같은 요청 중복 제거
const user = await getUser(id);
```

## Server Actions 활용

폼 제출과 뮤테이션에 Server Actions 사용. API 라우트 불필요.

```tsx
// Bad: 클라이언트에서 API 호출
'use client';
async function handleSubmit(data: FormData) {
  await fetch('/api/submit', { method: 'POST', body: data });
}

// Good: Server Action
async function submitForm(formData: FormData) {
  'use server';
  await db.insert(formData.get('email'));
  revalidatePath('/');
}

export default function Form() {
  return (
    <form action={submitForm}>
      <input name="email" />
      <button>Submit</button>
    </form>
  );
}
```

## unstable_cache / revalidateTag 조합

세밀한 캐시 무효화 전략 수립.

```tsx
import { unstable_cache, revalidateTag } from 'next/cache';

const getCachedPosts = unstable_cache(
  async () => db.post.findMany(),
  ['posts'],
  { tags: ['posts'], revalidate: 60 }
);

// 뮤테이션 후 캐시 무효화
revalidateTag('posts');
```

## Suspense 경계 세분화

페이지 전체가 아닌 느린 부분만 Suspense로 감싸기.

```tsx
// Bad: 페이지 전체 로딩
<Suspense fallback={<PageSkeleton />}>
  <EntirePage />
</Suspense>

// Good: 부분 Suspense
<Header />
<Suspense fallback={<FeedSkeleton />}>
  <Feed />
</Suspense>
<Suspense fallback={<SidebarSkeleton />}>
  <Sidebar />
</Suspense>
```

## defer await 패턴

빠른 데이터 먼저 표시, 느린 데이터는 Suspense로 스트리밍.

```tsx
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
