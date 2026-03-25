---
name: spec
description: |
  Spec-Driven Development. 구현 전 스펙 문서 작성 및 관리.
  Use when: 스펙, spec, 명세, 요구사항 정의, 기능 정의, constitution,
  새 프로젝트 시작, 기능 명세 작성, 스펙 기반 개발, SDD.
  NOT for: 단순 버그 수정, 1-2줄 변경, 이미 스펙이 완성된 구현 작업.
---

# Spec-Driven Development

코드 한 줄 쓰기 전에 **스펙이 진실의 출처(source of truth)**가 되도록 한다.
GitHub Spec Kit의 SDD 방법론을 현재 프리셋 워크플로우에 통합.

## 스펙 문서 위치

```
{project_root}/docs/specs/
├── constitution.md          # 프로젝트 헌법 (불변 원칙)
├── {feature-name}.spec.md   # 기능별 스펙 문서
└── ...
```

- `constitution.md`는 프로젝트당 1개. 모든 기능 스펙의 상위 규칙.
- 기능 스펙은 `{kebab-case}.spec.md` 네이밍.
- git 추적 대상 — 스펙 변경 이력이 코드와 함께 버전 관리됨.

## Phase 1: Constitution (프로젝트 헌법)

프로젝트 시작 시 1회 작성. 모든 기능 구현의 불변 규칙.

`docs/specs/constitution.md`에 아래 항목 정의:

### 필수 섹션

```markdown
# Constitution

## 품질 원칙
- [ ] 테스트 기준 (예: 커버리지 80% 이상, 유닛 + 통합 필수)
- [ ] 타입 안전 기준 (예: mypy --strict / tsc --noEmit 통과)
- [ ] 린트 기준 (예: ruff / eslint 0 error)

## UX 원칙
- [ ] 접근성 기준 (예: WCAG AA)
- [ ] 성능 기준 (예: LCP < 2.5s, API p99 < 500ms)
- [ ] 에러 UX (예: 모든 실패에 사용자 친화적 메시지)

## 보안 원칙
- [ ] 인증/인가 방식
- [ ] 입력 검증 정책
- [ ] 데이터 보호 정책

## 아키텍처 원칙
- [ ] 레이어 규칙 (예: domain에 framework import 금지)
- [ ] 의존성 방향 (예: 안쪽 → 바깥쪽만 허용)
- [ ] API 버전 정책
```

### 규칙
- 이미 CLAUDE.md에 정의된 스택/컨벤션 규칙은 **중복하지 않는다**
- Constitution은 CLAUDE.md의 **프로젝트별 확장** — 프로젝트 고유 원칙만 기록
- 한 번 잠긴 원칙은 팀 합의 없이 변경 금지

## Phase 2: Specify (기능 명세)

기능 구현 요청 시, 코드 작성 전에 스펙 문서를 먼저 작성한다.

### 스펙 문서 구조

`docs/specs/{feature-name}.spec.md`:

```markdown
# {Feature Name} Spec

## Status: DRAFT | REVIEW | LOCKED | IMPLEMENTED
<!-- DRAFT: 작성 중 / REVIEW: 검토 중 / LOCKED: 확정 / IMPLEMENTED: 구현 완료 -->

## 1. 무엇 (What)
한 문장으로 이 기능이 하는 일.

## 2. 왜 (Why)
이 기능이 필요한 이유. 해결하는 문제.

## 3. 사용자 시나리오
| # | 사용자 행동 | 시스템 응답 | 성공 기준 |
|---|-----------|-----------|----------|

## 4. 입출력 정의
### 입력
| 필드 | 타입 | 필수 | 설명 | 제약 |
|------|------|------|------|------|

### 출력
| 필드 | 타입 | 설명 |
|------|------|------|

### 에러 케이스
| 조건 | 상태 코드 | 메시지 |
|------|----------|--------|

## 5. 스코프
### IN (포함)
- ...

### OUT (미포함)
- ...

## 6. 비기능 요구사항
- 성능:
- 보안:
- 접근성:

## 7. Constitution 체크
<!-- constitution.md의 원칙 중 이 기능에 적용되는 항목 -->
- [ ] {원칙1}: 충족 방안
- [ ] {원칙2}: 충족 방안

## 8. 의존성
- 선행 기능:
- 외부 서비스:
- 라이브러리:
```

### Specify 규칙

1. **What/Why 먼저** — How(기술 구현)는 이 단계에서 다루지 않는다
2. **사용자 시나리오 필수** — 시나리오 없는 스펙은 불완전
3. **에러 케이스 필수** — 해피 패스만 있는 스펙은 불완전
4. **Constitution 체크 필수** — 프로젝트 원칙 위반 여부 사전 확인
5. **Status 관리** — DRAFT → REVIEW → LOCKED 순서. LOCKED 전 구현 시작 금지

## Phase 3: Spec Lock (확정)

스펙 작성 후 사용자 확인을 거쳐 LOCKED 상태로 전환.

**Lock 체크리스트**:
- [ ] 모든 사용자 시나리오에 성공 기준이 있는가?
- [ ] 입출력 타입이 모두 정의되었는가?
- [ ] 에러 케이스가 누락 없는가?
- [ ] Constitution 원칙이 모두 체크되었는가?
- [ ] IN/OUT 스코프가 명시적인가?

**Lock 후**:
- 스펙 변경 시 반드시 사유 기록 + Status를 REVIEW로 되돌림
- feature-planner는 LOCKED 스펙을 입력으로 사용
- gap-analysis는 LOCKED 스펙을 기준 문서로 사용

## 기존 워크플로우와의 연결

```
[planner] PRD 작성
    ↓
[spec] constitution 확인 → 기능 스펙 작성 → LOCK    ← 이 스킬
    ↓
[feature-planner] 스펙 기반 구현 계획
    ↓
[architect] 기술 설계
    ↓
[engineer] 구현 (스펙 참조)
    ↓
[gap-analysis] 스펙 vs 구현 비교
```

## 출력 형식

```
Spec Status: {feature-name}
- Constitution: {있음/없음 — 없으면 먼저 생성}
- Spec File: docs/specs/{feature-name}.spec.md
- Status: {DRAFT/REVIEW/LOCKED/IMPLEMENTED}
- Scenarios: {N}개
- Error Cases: {N}개
- Constitution Checks: {N}/{total}
→ {다음 단계 안내}
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
