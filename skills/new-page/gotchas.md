# New Page Gotchas

## Claude가 자주 틀리는 패턴

### 1. 'use client' 남용
- Server Component로 충분한데 'use client' 추가
- 해결: 이벤트 핸들러, hooks 사용 시에만 Client Component

### 2. layout.tsx에서 데이터 페칭
- layout은 리렌더 안 되므로 동적 데이터를 layout에서 fetch
- 해결: 동적 데이터는 page.tsx에서, 정적 데이터만 layout에서

### 3. loading.tsx 누락
- page.tsx만 생성하고 loading.tsx를 빠뜨림
- 해결: 비동기 데이터 페칭이 있는 페이지는 반드시 loading.tsx 포함

### 4. error.tsx를 Server Component로 생성
- error.tsx는 반드시 Client Component ('use client' 필수)
- 해결: 템플릿에서 자동으로 'use client' 포함
