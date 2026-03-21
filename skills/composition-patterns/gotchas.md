# Composition Patterns Gotchas

## 자주 발생하는 실수

### 1. boolean prop 폭발 (7개 이상)
❌ `<Button primary disabled loading outline small round ghost />` — boolean prop이 7개 이상
→ ✅ variant 패턴 사용: `<Button variant="primary" size="sm" state="loading" />`

boolean prop이 많아지면 조합 폭발로 유지보수가 불가능해진다. variant/compound 패턴으로 전환하라.

### 2. Context 없는 Compound Component
❌ Compound Component 패턴에서 자식 간 상태 공유를 props drilling으로 해결
→ ✅ React Context로 부모-자식 간 암묵적 상태 공유

```
// ✅ Context 기반 Compound Component
<Tabs>
  <Tabs.List>
    <Tabs.Tab>탭1</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel>내용1</Tabs.Panel>
</Tabs>
```

Context가 없으면 Compound Component의 핵심 이점(암묵적 연결)이 사라진다.

### 3. Provider를 너무 높이 배치하여 불필요한 리렌더
❌ 앱 최상단에 모든 Provider를 배치 → Context 값 변경 시 전체 트리 리렌더
→ ✅ Provider를 실제로 필요한 가장 낮은 위치에 배치

전역 Provider는 편리하지만 성능 비용이 크다. 값이 자주 변하는 Context일수록 범위를 좁혀라.

### 4. Render Props와 Hooks 혼용
❌ 같은 로직에 Render Props 패턴과 Custom Hook을 동시에 제공
→ ✅ Custom Hook을 기본으로, Render Props는 레거시 호환이 필요한 경우에만 사용

Hooks가 도입된 이후 Render Props는 대부분의 경우 불필요하다. 하나의 패턴으로 통일하라.

### 5. 컴포넌트 합성 대신 조건부 렌더링 남발
❌ 하나의 컴포넌트에서 `if/switch`로 10가지 변형을 처리
→ ✅ 공통 로직은 Hook으로 추출, UI 변형은 별도 컴포넌트로 분리 후 합성

거대한 조건부 렌더링은 컴포넌트를 테스트/이해하기 어렵게 만든다.

### 6. children prop 타입을 any로 선언
❌ `children: any` — 아무 값이나 허용
→ ✅ `children: React.ReactNode` 또는 특정 컴포넌트 타입으로 제한

Compound Component에서 children 타입을 제한하면 잘못된 사용을 컴파일타임에 잡을 수 있다.
