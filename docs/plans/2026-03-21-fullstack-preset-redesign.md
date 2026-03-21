# 풀스택 프리셋 재설계

> 날짜: 2026-03-21
> 상태: 승인됨
> 목적: Python(FastAPI) + React/Next.js 풀스택 범용 프리셋으로 재설계

## 배경

기존 claude-code-preset은 Python/FastAPI 백엔드 전용이었음.
부업으로 풀스택을 하면서 기획~배포 풀사이클을 지원하는 범용 프리셋이 필요.
excatt/superclaude-plusplus의 프론트엔드/기획 관련 기능을 참고하여 두 프로젝트의 장점을 합침.

## 핵심 결정사항

- **접근법**: 페이즈 기반 구성 (기획→설계→구현→검증→배포)
- **적용 범위**: 범용 (BE only / FE only / 풀스택 모두 지원)
- **FE 스택**: React 또는 Next.js + TypeScript + pnpm
- **BE 스택**: 기존 유지 (Python 3.13+, Poetry, FastAPI, SQLAlchemy 2.0)
- **에이전트 스타일**: 적은 수의 강력한 에이전트 (7개)
- **Difficulty Assessment**: 도입 (Simple/Medium/Complex 자동 판정)
- **비즈니스 기능**: 포함 (planner 에이전트에 통합)

## 1. CLAUDE.md 구조

```
CLAUDE.md (~250줄, 항상 로드)
├── Language & Response Rules
├── Difficulty Assessment (Step 0)         ← 신규
├── Stack Detection                        ← 신규
│   └── pyproject.toml → BE / package.json → FE / 둘 다 → 풀스택
├── Backend Rules
│   └── Python 3.13+, Poetry, FastAPI, async first, type safety, folder-first
├── Frontend Rules                         ← 신규
│   └── TypeScript strict, pnpm, React/Next.js 컨벤션
├── Naming Conventions (기존 + FE 추가)
├── Agent Orchestration (에이전트 목록 교체)
├── Routing Priority (에이전트/스킬 매핑 교체)
├── Phase Gate                             ← 신규
│   └── 기획→설계→구현→검증→배포 흐름
├── Safety Rules (3+ Fix, Verification Gate, Two-Stage Review)
├── Git Rules (Conventional Commits, feature branch)
├── Context Preservation (5단계 자동화 파이프라인)
└── MCP Triggers
```

### Difficulty Assessment

```
Step 0: 모든 작업 시작 전 난이도 판정

Simple (1-2 파일, 명확한 변경):
  → architect 스킵, confidence-check 스킵
  → engineer 직접 구현
  → verify만 실행

Medium (3-5 파일, 설계 필요):
  → architect 권장 (사용자 선택)
  → confidence-check 실행
  → verify + audit 실행

Complex (6+ 파일, 아키텍처 영향):
  → planner → architect → engineer 순서 강제
  → 전체 프로토콜 실행
  → checkpoint 필수
```

### Stack Detection

```
프로젝트 파일 감지 → 모드 자동 결정

pyproject.toml 존재        → BE 모드 (Python 규칙 활성)
package.json 존재          → FE 모드 (TypeScript 규칙 활성)
둘 다 존재                 → 풀스택 모드 (양쪽 규칙 활성)
둘 다 없음                 → 범용 모드 (기본 규칙만)
```

## 2. 에이전트 (7개)

| # | 에이전트 | 페이즈 | 역할 | 내부 호출 스킬 | 트리거 키워드 | 강제 |
|---|---------|--------|------|---------------|-------------|------|
| 1 | planner | 기획 | 아이디어→PRD, 요구사항 발굴, 사업성 검증, 비즈니스 패널 토론 | feature-planner, gap-analysis | 기획, PRD, 요구사항, 사업성, 비즈니스 | MUST |
| 2 | architect | 설계 | BE/FE/시스템 통합 아키텍처, DB 스키마, API 설계, 컴포넌트 구조 | confidence-check | 설계, 아키텍처, 스키마, ERD, 구조 | MUST |
| 3 | engineer | 구현 | Python(FastAPI) + React/Next.js 구현, TDD | fastapi, sqlalchemy, react-best-practices, testing | 구현, 만들어, 추가해, implement, create | MUST |
| 4 | reviewer | 검증 | 코드 리뷰, 품질 분석, 리팩토링 제안 | python-best-practices, web-design-guidelines, audit | 리뷰, 코드 품질, 리팩토링, 기술 부채 | MUST |
| 5 | debugger | 검증 | 근본 원인 분석, 체계적 디버깅 | build-fix, learn | 버그, 디버깅, 왜 안 돼, 에러, 이상 현상 | MUST |
| 6 | devops | 배포 | Docker, CI/CD, 모니터링, 프로덕션 체크 | docker, cicd, production-checklist | Docker, 배포, CI/CD, 인프라, 모니터링 | MUST |
| 7 | writer | 공통 | API 문서, README, ADR, 변경 로그 | - | 문서, README, API 문서, ADR | SHOULD |

### 에이전트 출처

| 에이전트 | 출처 |
|---------|------|
| planner | **신규** (superclaude++ requirements-analyst + business-panel-experts 합체) |
| architect | **신규** (기존 engineer에서 설계 부분 분리 + FE 아키텍처 추가) |
| engineer | **기존 확장** (BE전용 → BE+FE 통합, Stack Detection 기반 분기) |
| reviewer | **기존 확장** (FE 리뷰 규칙 추가) |
| debugger | **기존 리네이밍** (root-cause-analyst → debugger + 강화) |
| devops | **기존 유지** |
| writer | **기존 유지** |

## 3. 스킬 (21개)

### 공통 워크플로우 (9개)

| 스킬 | 트리거 시점 | 출처 | 설명 |
|------|-----------|------|------|
| /confidence-check | 구현 전 | 기존 | 신뢰도 ≥90% 검증 |
| /verify | 완료 후 | 기존 | 7단계 검증 루프 |
| /checkpoint | 위험 작업 전 | 기존 | git 복원 지점 생성 |
| /audit | 커밋/PR 전 | 기존 | 프로젝트 규칙 검증 |
| /build-fix | 빌드 에러 시 | 기존 | 최소 변경 에러 수정 |
| /feature-planner | 3+ 파일 기능 | 기존 | Phase 기반 구현 계획 |
| /gap-analysis | 설계 후 | 기존 | 설계 vs 구현 Match Rate |
| /learn | 해결 후 | 기존 | 인사이트 영구 저장 |
| /note | 수시 | 기존 | 세션 메모, 컨텍스트 보존 |

### 백엔드 (5개) — pyproject.toml 감지 시 활성

| 스킬 | 출처 | 설명 | 통합 내용 |
|------|------|------|----------|
| /fastapi | 기존 확장 | 프로젝트 구조, DI, EndpointPath | +pydantic-schema, +middleware, +environment 통합 |
| /sqlalchemy | 기존 확장 | Base, Mixin, Repository 패턴 | +alembic 마이그레이션 통합 |
| /testing | 기존 | conftest, 유닛/통합 테스트 전략 | - |
| /python-best-practices | 기존 확장 | 타입 힌트, 린팅, 보안 종합 | +error-handling 통합 |
| /security-audit | 기존 | JWT, RBAC, OWASP Top 10 | - |

### 프론트엔드 (4개) — package.json 감지 시 활성 (신규)

| 스킬 | 출처 | 설명 |
|------|------|------|
| /react-best-practices | superclaude++ | React/Next.js 40+ 규칙 최적화 |
| /web-design-guidelines | superclaude++ | 접근성/성능/UX 100+ 규칙 |
| /composition-patterns | superclaude++ | Compound Components, 패턴 가이드 |
| /webapp-testing | superclaude++ | Playwright 기반 웹앱 E2E 테스트 |

### 인프라/배포 (3개)

| 스킬 | 출처 | 설명 |
|------|------|------|
| /docker | 기존 | Multi-stage Dockerfile, compose |
| /cicd | 기존 | GitHub Actions, Quality Gates |
| /production-checklist | 기존 | 배포 전 필수 체크리스트 |

### 제거된 스킬과 이유

| 제거 | 이유 |
|------|------|
| /alembic | sqlalchemy 스킬에 마이그레이션 섹션으로 통합 |
| /pydantic-schema | fastapi 스킬에 DTO 섹션으로 통합 |
| /middleware | fastapi 스킬에 미들웨어 섹션으로 통합 |
| /environment | fastapi 스킬에 설정 섹션으로 통합 |
| /error-handling | python-best-practices에 통합 |
| /debugging | debugger 에이전트가 직접 처리 |
| /monitoring | production-checklist에 통합 |
| /background-tasks, /websocket | engineer 에이전트 내부 지식으로 처리 |
| /domain-layer | architect 에이전트 내부 지식으로 처리 |
| /api-design | architect 에이전트 내부 지식으로 처리 |

## 4. Hooks (10개)

### 기존 유지 (5개)

| Hook | 이벤트 | 설명 |
|------|--------|------|
| session-lessons.sh | SessionStart | 프로젝트 교훈 안내 |
| suggest-compact.sh | PreToolUse | 도구 50회 시 /compact 제안 |
| pre-compact-note.sh | UserPromptSubmit | /compact 감지 → 저장 안내 |
| pre-compact-save.sh | PreCompact | 압축 직전 state snapshot |
| session-summary.py | SessionEnd | last-session.md 자동 생성 |

### 신규 추가 (5개)

| Hook | 이벤트 | 출처 | 설명 |
|------|--------|------|------|
| type-check.sh | PostToolUse (Edit/Write) | superclaude++ | .ts/.tsx 수정 시 tsc 자동 실행 |
| auto-format.sh | PostToolUse (Edit/Write) | superclaude++ | Prettier(FE) / Ruff(BE) 자동 포맷 |
| console-log-check.sh | PostToolUse (Edit/Write) | superclaude++ | console.log/print() 감지 경고 |
| convention-check.sh | PostToolUse (Edit/Write) | superclaude++ | snake_case(PY) / PascalCase(TSX) 검사 |
| todo-continuation.sh | Stop | superclaude++ | 미완료 TODO 있으면 작업 중단 방지 |

## 5. 파일 구조

```
claude-code-preset/
├── CLAUDE.md
├── agents/
│   ├── planner.md
│   ├── architect.md
│   ├── engineer.md
│   ├── reviewer.md
│   ├── debugger.md
│   ├── devops.md
│   └── writer.md
├── skills/
│   ├── confidence-check/SKILL.md
│   ├── verify/SKILL.md
│   ├── checkpoint/SKILL.md
│   ├── audit/SKILL.md
│   ├── build-fix/SKILL.md
│   ├── feature-planner/SKILL.md
│   ├── gap-analysis/SKILL.md
│   ├── learn/SKILL.md
│   ├── note/SKILL.md
│   ├── fastapi/SKILL.md
│   ├── sqlalchemy/SKILL.md
│   ├── testing/SKILL.md
│   ├── python-best-practices/SKILL.md
│   ├── security-audit/SKILL.md
│   ├── react-best-practices/SKILL.md
│   ├── web-design-guidelines/SKILL.md
│   ├── composition-patterns/SKILL.md
│   ├── webapp-testing/SKILL.md
│   ├── docker/SKILL.md
│   ├── cicd/SKILL.md
│   └── production-checklist/SKILL.md
├── hooks/
│   ├── session-lessons.sh
│   ├── suggest-compact.sh
│   ├── pre-compact-note.sh
│   ├── pre-compact-save.sh
│   ├── session-summary.py
│   ├── type-check.sh
│   ├── auto-format.sh
│   ├── console-log-check.sh
│   ├── convention-check.sh
│   └── todo-continuation.sh
├── templates/
│   └── notepad.md
├── install.sh
├── uninstall.sh
└── mcp-setup.sh
```

## 6. 수치 비교

| 항목 | 기존 | 신규 | 변화 |
|------|------|------|------|
| 에이전트 | 5 (BE 전용) | 7 (풀스택+기획) | +2 |
| 스킬 | 33 (BE 전용) | 21 (풀스택) | -12 (에이전트 통합) |
| Hooks | 5 (컨텍스트) | 10 (컨텍스트+품질) | +5 |
| CLAUDE.md | ~230줄 (BE) | ~250줄 (범용) | +20줄 |
| FE 지원 | 없음 | React/Next.js | 신규 |
| 기획 지원 | 없음 | PRD + 비즈니스 패널 | 신규 |
| 난이도 판정 | 없음 | Simple/Medium/Complex | 신규 |
