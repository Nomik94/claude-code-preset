---
name: spec
description: |
  Spec-Driven Development. 구현 전 스펙 문서 작성 및 관리.
  Use when: 스펙, spec, 명세, 요구사항 정의, 기능 정의, constitution,
  새 프로젝트 시작, 기능 명세 작성, 스펙 기반 개발, SDD.
  NOT for: 단순 버그 수정, 1-2줄 변경, 이미 스펙이 완성된 구현 작업.
---

# Spec-Driven Development

코드 전에 **스펙이 source of truth**. GitHub Spec Kit SDD를 프리셋에 통합.

## 스펙 문서 위치

```
{project_root}/docs/specs/
├── constitution.md          # 프로젝트 헌법 (불변 원칙, 1개)
├── {feature-name}.spec.md   # 기능별 스펙 (kebab-case)
└── ...
```

git 추적 대상 — 스펙 변경 이력이 코드와 함께 버전 관리.

## Phase 1: Constitution

프로젝트 시작 시 1회 작성. `docs/specs/constitution.md`:

```markdown
# Constitution

## 품질 원칙
- [ ] 테스트 기준 (커버리지, 유닛+통합)
- [ ] 타입 안전 (mypy --strict / tsc --noEmit)
- [ ] 린트 (ruff / eslint 0 error)

## UX 원칙
- [ ] 접근성 (WCAG AA)
- [ ] 성능 (LCP < 2.5s, API p99 < 500ms)
- [ ] 에러 UX (사용자 친화적 메시지)

## 보안 원칙
- [ ] 인증/인가, 입력 검증, 데이터 보호

## 아키텍처 원칙
- [ ] 레이어 규칙, 의존성 방향, API 버전 정책
```

- CLAUDE.md 규칙과 **중복 금지** — 프로젝트 고유 원칙만 기록
- 잠긴 원칙은 팀 합의 없이 변경 금지

## Phase 2: Specify

코드 작성 전 스펙 문서 먼저 작성. `docs/specs/{feature-name}.spec.md`:

```markdown
# {Feature Name} Spec

## Status: DRAFT | REVIEW | LOCKED | IMPLEMENTED

## 1. 무엇 (What)
## 2. 왜 (Why)
## 3. 사용자 시나리오
| # | 사용자 행동 | 시스템 응답 | 성공 기준 |
## 4. 입출력 정의
### 입력 / 출력 / 에러 케이스
## 5. 스코프 (IN / OUT)
## 6. 비기능 요구사항 (성능, 보안, 접근성)
## 7. Constitution 체크
## 8. 의존성 (선행 기능, 외부 서비스, 라이브러리)
```

### 규칙
- What/Why 먼저 — How는 이 단계에서 다루지 않을 것
- 사용자 시나리오 + 에러 케이스 필수 (없으면 불완전)
- Constitution 체크 필수
- Status: DRAFT → REVIEW → LOCKED. **LOCKED 전 구현 시작 금지**

## Phase 3: Spec Lock

**Lock 체크리스트**:
- [ ] 모든 시나리오에 성공 기준
- [ ] 입출력 타입 모두 정의
- [ ] 에러 케이스 누락 없음
- [ ] Constitution 원칙 모두 체크
- [ ] IN/OUT 스코프 명시

**Lock 후**:
- 변경 시 사유 기록 + REVIEW로 되돌림
- feature-planner: LOCKED 스펙 입력으로 사용
- gap-analysis: LOCKED 스펙 기준 문서로 사용

## 워크플로우 연결

```
[planner] PRD → [spec] constitution → 기능 스펙 → LOCK
→ [feature-planner] 구현 계획 → [architect] 기술 설계
→ [engineer] 구현 → [gap-analysis] 스펙 vs 구현 비교
```

## 출력 형식

```
Spec Status: {feature-name}
- Constitution: {있음/없음}
- Spec File: docs/specs/{feature-name}.spec.md
- Status: {DRAFT/REVIEW/LOCKED/IMPLEMENTED}
- Scenarios: {N}개 / Error Cases: {N}개
- Constitution Checks: {N}/{total}
→ {다음 단계}
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
