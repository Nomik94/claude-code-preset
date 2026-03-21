# React Best Practices Gotchas

## 자주 발생하는 실수

### 1. 불필요한 'use client' 선언
❌ 데이터 페칭이나 상태가 없는 컴포넌트에 `'use client'` 추가
→ ✅ 이벤트 핸들러, useState, useEffect 등 클라이언트 기능이 필요한 경우에만 선언

Server Component가 기본이다. 불필요한 'use client'는 번들 크기를 늘리고 서버 사이드 이점을 잃는다.

### 2. useEffect로 데이터 페칭
❌ `useEffect(() => { fetch('/api/...').then(...) }, [])` — Client Component에서 페칭
→ ✅ Server Component에서 직접 async/await로 데이터 페칭. 필요 시 React Query/SWR 사용

useEffect 데이터 페칭은 워터폴, 레이아웃 시프트, 로딩 상태 관리 복잡성을 유발한다.

### 3. barrel file (export * from)
❌ `index.ts`에서 `export * from './ComponentA'` — 트리 쉐이킹 방해
→ ✅ 직접 import: `import { ComponentA } from '@/components/ComponentA'`

barrel file은 하나의 컴포넌트를 import할 때 전체 모듈을 로드하게 만들어 번들 크기가 증가한다.

### 4. key={index} 사용
❌ `list.map((item, index) => <Item key={index} />)` — 인덱스를 key로 사용
→ ✅ `list.map((item) => <Item key={item.id} />)` — 고유하고 안정적인 식별자 사용

인덱스 key는 리스트 순서 변경, 삽입, 삭제 시 잘못된 DOM 재사용을 유발한다.

### 5. 렌더링 중 상태 변경
❌ 컴포넌트 본문에서 `setState`를 직접 호출 → 무한 렌더 루프
→ ✅ 이벤트 핸들러, useEffect, 또는 조건부 로직 안에서만 상태 변경

렌더링 중 상태 변경은 React의 렌더링 사이클을 깨뜨린다.

### 6. Props drilling 방치
❌ 3단계 이상 깊이로 props를 전달하면서 중간 컴포넌트는 사용하지 않음
→ ✅ Context, Compound Component 패턴, 또는 컴포넌트 합성으로 해결

props drilling은 중간 컴포넌트의 불필요한 리렌더와 유지보수 어려움을 만든다.

### 7. useCallback/useMemo 과다 사용
❌ 모든 함수에 useCallback, 모든 값에 useMemo 적용
→ ✅ 실제 성능 문제가 측정된 경우에만 메모이제이션 적용

불필요한 메모이제이션은 코드 복잡도만 높이고 오히려 메모리를 낭비한다.
