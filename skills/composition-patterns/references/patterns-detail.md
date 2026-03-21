# React 컴포지션 패턴 상세 코드 예시

> SKILL.md의 규칙 요약에 대한 상세 Before/After 코드 예시.

---

## 1. Boolean Prop 폭발 방지

### 규칙 1.1: Boolean Prop 3개 이상이면 Compound Component로 전환

boolean prop이 늘어나면 조합 폭발이 발생하고 내부 조건문이 복잡해진다.

```tsx
// ❌ Before — boolean prop 폭발
<Card
  showHeader
  showFooter
  showImage
  isCompact
  isHighlighted
  hasBorder
/>

// 내부 구현이 조건문 지옥
function Card({ showHeader, showFooter, showImage, isCompact, isHighlighted, hasBorder }) {
  return (
    <div className={cn(isCompact && 'compact', isHighlighted && 'highlighted', hasBorder && 'bordered')}>
      {showHeader && <div className="header">...</div>}
      {showImage && <img src="..." />}
      <div className="body">...</div>
      {showFooter && <div className="footer">...</div>}
    </div>
  );
}
```

```tsx
// ✅ After — Compound Component
<Card highlighted bordered>
  <Card.Header>제목</Card.Header>
  <Card.Image src="/photo.jpg" alt="사진" />
  <Card.Body>내용</Card.Body>
  <Card.Footer>
    <Button>확인</Button>
  </Card.Footer>
</Card>
```

### 규칙 1.2: Compound Component + 공유 Context

하위 컴포넌트 간 상태 공유를 위한 Context 활용.

```tsx
// ✅ After — Context 기반 Compound Component

// 1. Context 정의
interface AccordionContextType {
  openItems: Set<string>;
  toggle: (id: string) => void;
}

const AccordionContext = createContext<AccordionContextType | null>(null);

function useAccordion() {
  const ctx = useContext(AccordionContext);
  if (!ctx) throw new Error('AccordionContext 내에서 사용하세요');
  return ctx;
}

// 2. Root (Provider)
function Accordion({ children }: { children: React.ReactNode }) {
  const [openItems, setOpenItems] = useState<Set<string>>(new Set());
  const toggle = useCallback((id: string) => {
    setOpenItems(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }, []);

  return (
    <AccordionContext value={{ openItems, toggle }}>
      <div role="region">{children}</div>
    </AccordionContext>
  );
}

// 3. 하위 컴포넌트
function AccordionItem({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  const { openItems, toggle } = useAccordion();
  const isOpen = openItems.has(id);

  return (
    <div>
      <button onClick={() => toggle(id)} aria-expanded={isOpen}>
        {title}
      </button>
      {isOpen && <div>{children}</div>}
    </div>
  );
}

// 4. 조합
Accordion.Item = AccordionItem;

// 사용
<Accordion>
  <Accordion.Item id="1" title="섹션 1">내용 1</Accordion.Item>
  <Accordion.Item id="2" title="섹션 2">내용 2</Accordion.Item>
</Accordion>
```

---

## 2. 상태와 UI 분리

### 규칙 2.1: Provider가 상태를 보유, UI 컴포넌트는 표현만

상태 로직을 UI에서 분리하면 테스트와 재사용이 쉬워진다.

```tsx
// ❌ Before — UI 컴포넌트에 상태 로직 혼재
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<'all' | 'active' | 'done'>('all');

  const addTodo = (text: string) => { /* ... */ };
  const toggleTodo = (id: string) => { /* ... */ };
  const filteredTodos = todos.filter(/* ... */);

  return (
    <div>
      <input onSubmit={/* ... */} />
      {filteredTodos.map(todo => <TodoItem key={todo.id} {...todo} />)}
      <FilterBar filter={filter} onChange={setFilter} />
    </div>
  );
}
```

```tsx
// ✅ After — 상태 Provider + 순수 UI

// 1. Context 인터페이스
interface TodoState {
  todos: Todo[];
  filter: 'all' | 'active' | 'done';
  filteredTodos: Todo[];
}

interface TodoActions {
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  setFilter: (filter: 'all' | 'active' | 'done') => void;
}

// 2. Provider
function TodoProvider({ children }: { children: React.ReactNode }) {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<'all' | 'active' | 'done'>('all');

  const filteredTodos = useMemo(
    () => filter === 'all' ? todos : todos.filter(t => filter === 'done' ? t.done : !t.done),
    [todos, filter]
  );

  const actions: TodoActions = useMemo(() => ({
    addTodo: (text) => setTodos(prev => [...prev, { id: crypto.randomUUID(), text, done: false }]),
    toggleTodo: (id) => setTodos(prev => prev.map(t => t.id === id ? { ...t, done: !t.done } : t)),
    setFilter,
  }), []);

  return (
    <TodoContext value={{ state: { todos, filter, filteredTodos }, actions }}>
      {children}
    </TodoContext>
  );
}

// 3. 순수 UI
function TodoList() {
  const { state, actions } = useTodoContext();
  return (
    <div>
      <TodoInput onAdd={actions.addTodo} />
      {state.filteredTodos.map(todo => (
        <TodoItem key={todo.id} todo={todo} onToggle={actions.toggleTodo} />
      ))}
      <FilterBar filter={state.filter} onChange={actions.setFilter} />
    </div>
  );
}
```

### 규칙 2.2: { state, actions, meta } 3부 Context 인터페이스

Context 값을 3개 영역으로 분리하여 구조화.

```tsx
interface ContextValue<S, A, M = undefined> {
  state: S;      // 읽기 전용 상태
  actions: A;    // 상태 변경 함수
  meta?: M;      // 파생 데이터, 로딩 상태 등
}

// 예시
interface CartContextValue {
  state: {
    items: CartItem[];
    coupon: string | null;
  };
  actions: {
    addItem: (item: CartItem) => void;
    removeItem: (id: string) => void;
    applyCoupon: (code: string) => void;
  };
  meta: {
    totalPrice: number;
    itemCount: number;
    isLoading: boolean;
  };
}
```

### 규칙 2.3: 형제 컴포넌트 접근을 위해 Provider로 상태 리프팅

형제 컴포넌트 간 상태 공유가 필요하면 가장 가까운 공통 부모에 Provider 배치.

```tsx
// ❌ Before — prop drilling
function Page() {
  const [selected, setSelected] = useState<string | null>(null);
  return (
    <>
      <Sidebar selected={selected} onSelect={setSelected} />
      <Detail selected={selected} />
    </>
  );
}

// ✅ After — Provider로 리프팅
function Page() {
  return (
    <SelectionProvider>
      <Sidebar />
      <Detail />
    </SelectionProvider>
  );
}

function Sidebar() {
  const { actions } = useSelection();
  return <nav><button onClick={() => actions.select('item-1')}>Item 1</button></nav>;
}

function Detail() {
  const { state } = useSelection();
  if (!state.selected) return <p>항목을 선택하세요</p>;
  return <div>선택됨: {state.selected}</div>;
}
```

---

## 3. Variant 패턴

### 규칙 3.1: 명시적 variant 컴포넌트 생성

조건부 렌더링이 복잡하면 별도 컴포넌트로 분리.

```tsx
// ❌ Before — 하나의 컴포넌트에서 variant 처리
function Notification({ type }: { type: 'success' | 'error' | 'warning' | 'info' }) {
  if (type === 'success') return <div className="bg-green-50">...</div>;
  if (type === 'error') return <div className="bg-red-50">...</div>;
  if (type === 'warning') return <div className="bg-yellow-50">...</div>;
  return <div className="bg-blue-50">...</div>;
}
```

```tsx
// ✅ After — variant별 컴포넌트 + 팩토리

// 공통 인터페이스
interface NotificationProps {
  title: string;
  message: string;
  onDismiss?: () => void;
}

// 기본 레이아웃
function NotificationBase({
  icon,
  className,
  title,
  message,
  onDismiss,
}: NotificationProps & { icon: React.ReactNode; className: string }) {
  return (
    <div className={cn('rounded-lg p-4', className)} role="alert">
      <div className="flex items-center gap-2">
        {icon}
        <strong>{title}</strong>
      </div>
      <p>{message}</p>
      {onDismiss && <button onClick={onDismiss} aria-label="닫기">×</button>}
    </div>
  );
}

// variant 컴포넌트
function SuccessNotification(props: NotificationProps) {
  return <NotificationBase {...props} icon={<CheckIcon />} className="bg-green-50 text-green-800" />;
}

function ErrorNotification(props: NotificationProps) {
  return <NotificationBase {...props} icon={<XIcon />} className="bg-red-50 text-red-800" />;
}

// 팩토리 (선택)
const NOTIFICATION_MAP = {
  success: SuccessNotification,
  error: ErrorNotification,
  warning: WarningNotification,
  info: InfoNotification,
} as const;

function Notification({ type, ...props }: NotificationProps & { type: keyof typeof NOTIFICATION_MAP }) {
  const Component = NOTIFICATION_MAP[type];
  return <Component {...props} />;
}
```

### 규칙 3.2: render props 대신 children 우선

children이 가능한 경우 render props보다 우선.

```tsx
// ❌ Before — render props
<List
  items={items}
  renderItem={(item) => <ListItem key={item.id}>{item.name}</ListItem>}
/>

// ✅ After — children
<List>
  {items.map(item => (
    <ListItem key={item.id}>{item.name}</ListItem>
  ))}
</List>
```

render props가 적합한 경우: 부모가 자식에게 **추가 데이터**를 전달해야 할 때.

```tsx
// ✅ Good — render props 적합한 케이스 (부모가 인덱스, 상태 제공)
<Virtualized
  items={items}
  renderItem={(item, index, isScrolling) => (
    <Row key={item.id} item={item} index={index} dimmed={isScrolling} />
  )}
/>
```

---

## 4. React 19 업데이트

### 규칙 4.1: forwardRef 제거

React 19에서 ref는 일반 prop으로 전달 가능.

```tsx
// ❌ Before — React 18
const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => {
  return <input ref={ref} {...props} />;
});

// ✅ After — React 19
function Input({ ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

### 규칙 4.2: use() Hook으로 Promise/Context 소비

```tsx
// ❌ Before — useEffect + useState로 Promise 처리
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => {
    userPromise.then(setUser);
  }, [userPromise]);
  if (!user) return <Skeleton />;
  return <div>{user.name}</div>;
}

// ✅ After — use()
import { use } from 'react';

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise);
  return <div>{user.name}</div>;
}

// Suspense로 감싸서 사용
<Suspense fallback={<Skeleton />}>
  <UserProfile userPromise={fetchUser(id)} />
</Suspense>
```

### 규칙 4.3: Context를 use()로 조건부 읽기

```tsx
// ❌ Before — useContext는 조건부 호출 불가
function Component({ showExtra }: { showExtra: boolean }) {
  const theme = useContext(ThemeContext); // 항상 호출해야 함
  return showExtra ? <div style={{ color: theme.primary }}>Extra</div> : null;
}

// ✅ After — use()는 조건부 호출 가능
function Component({ showExtra }: { showExtra: boolean }) {
  if (!showExtra) return null;
  const theme = use(ThemeContext);
  return <div style={{ color: theme.primary }}>Extra</div>;
}
```

### 규칙 4.4: Context Provider 간소화

```tsx
// ❌ Before — React 18
<ThemeContext.Provider value={theme}>
  {children}
</ThemeContext.Provider>

// ✅ After — React 19
<ThemeContext value={theme}>
  {children}
</ThemeContext>
```
