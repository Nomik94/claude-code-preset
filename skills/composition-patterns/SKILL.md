---
name: composition-patterns
description: |
  Use when React 컴포넌트 설계, props 복잡도 증가, 컴포넌트 간 상태 공유 패턴 결정 시.
  NOT for 스타일링, 성능 최적화, 테스트 작성.
files:
  - references/patterns-detail.md
---

# React 컴포지션 패턴 가이드

> 상세 코드 예시는 `references/patterns-detail.md` 참조.

## 핵심 규칙

| # | 규칙 | 패턴 |
|---|------|------|
| 1.1 | Boolean prop 3개 이상 → Compound Component | Compound Component |
| 1.2 | 하위 컴포넌트 간 상태 공유 → Context 연결 | Compound + Context |
| 2.1 | 상태 로직과 UI 분리 | Provider |
| 2.2 | Context 값은 { state, actions, meta } | 3부 Context |
| 2.3 | 형제 컴포넌트 접근 → Provider로 리프팅 | Provider 리프팅 |
| 3.1 | variant 3개 이상 → 별도 컴포넌트 + 팩토리 | Variant |
| 3.2 | children 우선, render props는 데이터 주입 시에만 | children/render |
| 4.1 | React 19: forwardRef 제거 | ref as prop |
| 4.2 | React 19: use() Hook으로 Promise/Context 소비 | use() |
| 4.3 | React 19: Context를 use()로 조건부 읽기 | use() |
| 4.4 | React 19: Context Provider 간소화 | direct value |

## 패턴 선택 의사결정 트리

```
컴포넌트 설계 시작
  ├── boolean prop 3개 이상? → Compound Component (1.1~1.2)
  ├── 형제 간 상태 공유? → Provider 패턴 (2.1~2.3)
  ├── variant 3개 이상? → Variant + 팩토리 (3.1)
  ├── 부모→자식 데이터 주입? → render props (3.2)
  └── 단순 구조 → children 패턴 (3.2)
```

## 체크리스트

```
[ ] boolean prop 3개 미만 유지
[ ] Compound Component에 Context 연결
[ ] 상태 로직과 UI 분리 (Provider 패턴)
[ ] Context는 { state, actions, meta } 구조
[ ] variant 3개 이상 시 별도 컴포넌트
[ ] children 우선, render props는 데이터 주입 시에만
[ ] React 19: forwardRef 제거, use() 활용
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
