# 데이터 페칭 패턴 비교

## 패턴 선택 기준

| 패턴 | 사용 시점 | 위치 |
|------|---------|------|
| Server Component fetch | 서버에서 직접 데이터 로드 | RSC |
| Server Actions | 폼 제출, 뮤테이션 | RSC / Client |
| SWR | 클라이언트 실시간/인터랙티브 데이터 | Client |
| Route Handlers | 외부 서비스 프록시, 웹훅 | API |

## SWR 클라이언트 데이터 패칭

### 기본 사용

```tsx
// Bad: useEffect + useState
const [data, setData] = useState(null);
const [loading, setLoading] = useState(true);
useEffect(() => {
  fetch('/api/data').then(r => r.json()).then(setData).finally(() => setLoading(false));
}, []);

// Good: SWR
import useSWR from 'swr';
const { data, error, isLoading } = useSWR('/api/data', fetcher);
```

### SWR 글로벌 설정

```tsx
<SWRConfig value={{
  fetcher: (url: string) => fetch(url).then(r => r.json()),
  revalidateOnFocus: false,
  dedupingInterval: 2000,
}}>
  {children}
</SWRConfig>
```

### 실시간 데이터 (useSWRSubscription)

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

### Optimistic UI

뮤테이션 시 서버 응답 전에 UI 먼저 업데이트.

```tsx
const { trigger } = useSWRMutation('/api/todos', addTodo, {
  optimisticData: (current) => [...current, newTodo],
  rollbackOnError: true,
});
```

## Server Actions

### 폼 제출

```tsx
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

### useActionState (React 19+)

```tsx
'use client';
import { useActionState } from 'react';

function Form({ action }) {
  const [state, formAction, isPending] = useActionState(action, null);
  return (
    <form action={formAction}>
      <input name="email" />
      <button disabled={isPending}>
        {isPending ? '처리 중...' : '제출'}
      </button>
      {state?.error && <p>{state.error}</p>}
    </form>
  );
}
```

## Route Handlers

API 라우트가 필요한 경우 (외부 서비스 프록시, 웹훅 수신 등).

```tsx
// app/api/webhook/route.ts
export async function POST(request: Request) {
  const body = await request.json();
  // 외부 서비스 웹훅 처리
  return Response.json({ received: true });
}
```

### Route Handler vs Server Action

| 기준 | Route Handler | Server Action |
|------|-------------|---------------|
| 외부 API 프록시 | O | X |
| 웹훅 수신 | O | X |
| 폼 제출 | X (불필요) | O |
| CRUD 뮤테이션 | X (불필요) | O |
| 파일 업로드 | O (스트리밍) | O (FormData) |

## 병렬 데이터 패칭

### Promise.all

```tsx
// Bad: 순차 워터폴
const user = await getUser(id);
const posts = await getPosts(id);
const comments = await getComments(id);

// Good: 병렬 패칭
const [user, posts, comments] = await Promise.all([
  getUser(id),
  getPosts(id),
  getComments(id),
]);
```

### defer await + Suspense

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
