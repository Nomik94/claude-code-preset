---
name: feature-planner
description: |
  기능 구현 계획 수립 및 작업 분해.
  Use when: 기능 구현 계획, 구현 전 설계, 스코프 정의, 작업 분해,
  3개 이상 파일 변경, 기능 추가, feature planning, 구현 어떻게 할까,
  큰 작업, 복잡한 기능, 어디부터 시작, 작업 순서.
  NOT for: 단순 버그 수정, 1-2 파일 변경, 오타 수정.
---

# 기능 플래너

코드 작성 전 기능 설계. 3개+ 파일 영향 또는 아키텍처 결정 필요 시 실행.

## Phase 0: 스펙 확인

1. `docs/specs/constitution.md` 존재 확인
2. `docs/specs/{feature-name}.spec.md` 존재 확인
3. 스펙 있으면:
   - LOCKED 확인 (DRAFT/REVIEW면 확정 요청)
   - 시나리오/입출력/에러 → Phase 1 입력, Constitution → Phase 4 게이트
4. 스펙 없으면:
   - 3개+ 파일/새 기능 → `/spec` 먼저 작성 권장
   - 기존 확장 → Phase 1 진행 가능

## Phase 1: 요구사항 명확화

스펙 있으면 해당 섹션에서 추출:
1. **무엇**: 한 문장 설명 ← spec §1
2. **범위 밖**: 하지 않는 것 ← spec §5 OUT
3. **완료 기준**: 테스트 가능한 조건 ← spec §3
4. **제약**: 스택/성능/데드라인 ← spec §6

답할 수 없으면 사용자에게 확인.

## Phase 2: 기존 코드 분석

| 항목 | BE | FE |
|------|----|----|
| 관련 코드 | 모듈/서비스/모델 | 컴포넌트/훅/스토어 |
| 패턴 | 네이밍/에러/응답 | 구조/상태/페칭 |
| 재사용 | 기존 서비스/유틸 확장 | 기존 컴포넌트/훅 확장 |
| 영향 범위 | 읽기/수정/생성 파일 전체 나열 | 동일 |

## Phase 3: 구현 계획 + 의존성

- 순번 부여, 병렬/순차 표시
- 파일, 복잡도 (S/M/L), 의존성 매핑, 위험 요소 표시
- 10개+ 파일 → 독립 배포 가능 단계로 분할

## Phase 4: 품질 게이트

| 게이트 | 기준 |
|--------|------|
| 타입 | BE: mypy --strict / FE: tsc --noEmit |
| 테스트 | 신규 코드 80%+ |
| 린트 | ruff / eslint 통과 |
| 아키텍처 | 레이어 위반 없음 |

## Phase 5: 범위 확정

- IN/OUT 목록 출력 → 사용자 확인 후 코딩 시작
- 확정 전 코딩 금지

## 규칙

- 과잉 구현 금지, MVP 우선
- 불확실한 점 즉시 표면화
- 10개+ 파일 = 단계별 접근, 각 단계 독립 테스트/배포 가능

## 출력 형식

```
## Feature: [name]

### Requirements
- What / NOT in scope / Acceptance criteria / Constraints

### Affected Code
| File | Action | Stack | Complexity |

### Implementation Plan
| # | Task | Files | Depends On | Parallel | Risk |

### Quality Gates
| Phase | Gate | Criteria |

### Scope Lock
- IN: ... / OUT: ...
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
