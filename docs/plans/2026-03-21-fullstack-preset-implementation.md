# 풀스택 프리셋 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Python(FastAPI) + React/Next.js 풀스택 범용 프리셋의 모든 파일을 생성한다.

**Architecture:** 페이즈 기반 구성 (기획→설계→구현→검증→배포). 7개 에이전트 + 21개 스킬 + 10개 hooks + CLAUDE.md. 기존 BE 전용 프리셋의 장점을 유지하면서 FE/기획/배포 지원을 추가.

**Tech Stack:** Python 3.13+ / FastAPI / SQLAlchemy 2.0 / Poetry (BE) + React / Next.js / TypeScript / pnpm (FE)

**설계 문서:** `docs/plans/2026-03-21-fullstack-preset-redesign.md`

---

## Task 1: CLAUDE.md 작성

**Files:**
- Create: `CLAUDE.md`

**Step 1: CLAUDE.md 파일 생성**

기존 CLAUDE.md를 기반으로 다음 구조로 재작성:

```markdown
# Fullstack Development Configuration

## Language
- **ALWAYS respond in Korean (한글)**
- Code comments: Korean
- Variables/identifiers: English
- Technical terms: English when common

## Difficulty Assessment (Step 0)

모든 작업 시작 전 난이도 판정. 이 판정이 프로토콜 깊이를 결정한다.

| Level | 기준 | 에이전트 흐름 | 스킬 |
|-------|------|-------------|------|
| Simple | 1-2 파일, 명확한 변경 | engineer 직접 | verify만 |
| Medium | 3-5 파일, 설계 필요 | architect(선택) → engineer | confidence-check + verify + audit |
| Complex | 6+ 파일, 아키텍처 영향 | planner → architect → engineer | 전체 프로토콜 + checkpoint |

## Stack Detection

프로젝트 파일로 모드 자동 결정:
- `pyproject.toml` → BE 모드 (Python 규칙 활성)
- `package.json` → FE 모드 (TypeScript 규칙 활성)
- 둘 다 → 풀스택 모드
- 둘 다 없음 → 범용 모드

## Backend Rules (BE 모드 활성 시)

### Stack
- Python 3.13+ / FastAPI (async) / SQLAlchemy 2.0 (async)
- Alembic / Pydantic v2 / pydantic-settings
- PyJWT + pwdlib (argon2)
- **Poetry** (mandatory, no pip/uv/requirements.txt)
- Ruff + mypy --strict / pytest + pytest-asyncio + httpx
- structlog (JSON prod, console dev) / cashews or redis.asyncio
- Docker + docker-compose

### Architecture
- **Layered**: controllers → service → repository
- **Folder-First**: controllers/, dto/, exceptions/, constants/는 처음부터 폴더
- **DI**: Depends (small) | Manual Container (medium) | Dishka (large)
- **API Versioning**: /{client}/v{version}/{domain}/{action} via EndpointPath
- lazy="raise" — relationship 기본값

### Modern Python Syntax (3.13+ 필수)
| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K,V]` | `list[X]`, `dict[K,V]` |
| `-> "ClassName"` | `-> Self` |
| `class Status(str, Enum)` | `class Status(StrEnum)` |
| `@dataclass` | `@dataclass(slots=True)` |

### Pydantic v2 필수
- `model_config = ConfigDict(...)` (not `class Config:`)
- `model_dump()` / `model_validate()` / `field_validator`

## Frontend Rules (FE 모드 활성 시)

### Stack
- React 18+ / Next.js 14+ (App Router)
- TypeScript strict mode
- **pnpm** (mandatory, no npm/yarn)
- Tailwind CSS / shadcn/ui
- ESLint + Prettier

### Core Rules
1. Server Components 기본, 'use client' 최소화
2. `loading.tsx` / `error.tsx` / `not-found.tsx` 필수
3. Image → next/image, Link → next/link
4. 상태관리: URL state > Context > Zustand (순서대로 검토)
5. API 호출: Server Actions > Route Handlers > 외부 fetch
6. CSS: Tailwind 유틸리티 우선, 커스텀 CSS 최소화

## Naming Conventions

| Area | Convention | Example |
|------|-----------|---------|
| Python variable/function | snake_case | `get_user_data()` |
| Python class | PascalCase | `UserService` |
| Python constant | SCREAMING_SNAKE | `MAX_PAGE_SIZE` |
| TS variable/function | camelCase | `getUserData()` |
| React component | PascalCase | `UserProfile` |
| TS constant | SCREAMING_SNAKE | `MAX_PAGE_SIZE` |
| DB column/table | snake_case | `created_at` |
| API JSON | camelCase | `createdAt` |
| URL path | kebab-case | `/api/v1/user-stats` |
| CSS class | kebab-case | `user-profile-card` |

## Agent Orchestration

### Orchestrator vs Worker
| Orchestrator (you) | Worker (spawned) |
|---|---|
| 작업 분해, Task 생성, 결과 합성 | 구체적 작업 실행, 도구 직접 사용 |
| AskUserQuestion 사용 | 결과를 절대 경로로 보고 |
| 직접 코드 작성 금지 | 서브에이전트 스폰 금지 |

Worker prompt 필수: `CONTEXT: WORKER agent. STACK: {detected_stack}`

### Model Selection
| Task | Model | Count |
|------|-------|-------|
| 탐색, 간단한 검색 | haiku | 5-10 병렬 |
| 구현, 리뷰 | opus | 1-3 |
| 아키텍처, 복잡한 추론 | opus | 1-2 |

## Routing Priority (NON-NEGOTIABLE)

### ① Agent Selection (1순위)

| Agent | Phase | Keywords | 강제 |
|-------|-------|----------|------|
| planner | 기획 | 기획, PRD, 요구사항, 사업성, 비즈니스 | MUST |
| architect | 설계 | 설계, 아키텍처, 스키마, ERD, 구조 | MUST |
| engineer | 구현 | 구현, 만들어, 추가해, implement, create | MUST |
| reviewer | 검증 | 리뷰, 코드 품질, 리팩토링, 기술 부채 | MUST |
| debugger | 검증 | 버그, 디버깅, 왜 안 돼, 에러, 이상 현상 | MUST |
| devops | 배포 | Docker, 배포, CI/CD, 인프라, 모니터링 | MUST |
| writer | 공통 | 문서, README, API 문서, ADR | SHOULD |

### ② Skill Triggers (2순위)

| Trigger | Skill | Keywords | 강제 |
|---------|-------|----------|------|
| 구현 전 | /confidence-check | 구현, implement | MUST |
| 완료 후 | /verify | 완료, done, PR | MUST |
| 빌드 에러 | /build-fix | error, Build failed | MUST |
| 위험 작업 | /checkpoint | 리팩토링, 삭제, 마이그레이션 | MUST |
| 커밋/PR 전 | /audit | 커밋, PR, 배포 | MUST |
| 해결 후 | /learn | 해결, solved | SHOULD |
| 3+ 파일 | /feature-planner | 기능 구현, 여러 파일 | SHOULD |

## Phase Gate

기획 → 설계 → 구현 → 검증 → 배포. Complex 작업은 이 순서 강제.

| Phase | Agent | Input | Output |
|-------|-------|-------|--------|
| 기획 | planner | 아이디어/요구 | PRD, 요구사항 명세 |
| 설계 | architect | PRD | 아키텍처 문서, API 설계, DB 스키마 |
| 구현 | engineer | 설계 문서 | 코드 + 테스트 |
| 검증 | reviewer + debugger | 코드 | 리뷰 리포트, 버그 수정 |
| 배포 | devops | 검증된 코드 | Docker, CI/CD, 배포 |

## Safety Rules

### 3+ Fix Rule
같은 버그 3번 수정 시도 실패 → 즉시 중단. 아키텍처 재검토.

### Verification Gate
"완료/수정됨/통과" 선언 전 반드시 실제 명령어 실행 + 전체 출력 확인.

### Two-Stage Review (커밋/PR 전)
1. Spec Compliance: 요구사항 대비 확인. Missing AND Excess 체크.
2. Code Quality: Stage 1 통과 후에만. SOLID, 에러 핸들링, 테스트, 보안.

## Git Rules
- Feature branch only, never main/master
- **Conventional Commits**: feat:, fix:, refactor:, docs:, test:, chore:
- git diff before staging
- No Co-Authored-By

## Context Preservation

5단계 자동화 파이프라인:
1. SessionStart: session-lessons.sh
2. PreToolUse: suggest-compact.sh (50회)
3. UserPromptSubmit: pre-compact-note.sh
4. PreCompact: pre-compact-save.sh
5. SessionEnd: session-summary.py

### Notepad (/note)
/note <content> → Working Memory
/note --priority <content> → Priority Context (500자)
/note --manual <content> → MANUAL (영구)

## Auto-MCP Triggers
| Condition | MCP |
|-----------|-----|
| FastAPI/SQLAlchemy/Pydantic + 구현 | Context7 |
| React/Next.js + 구현 | Context7 |
| 왜/원인/복잡한 분석 | Sequential |
| E2E/브라우저 테스트 | Playwright |

## Flags
| Flag | Effect |
|------|--------|
| --think | ~4K 분석, Sequential |
| --think-hard | ~10K, Sequential + Context7 |
| --ultrathink | ~32K, 전체 MCP |
| --brainstorm | 협업적 요구사항 탐색 |
| --orchestrate | 도구 최적화, 병렬 실행 |
| --no-mcp | 네이티브만 |
```

**Step 2: 커밋**

```bash
git add CLAUDE.md
git commit -m "feat: 풀스택 범용 CLAUDE.md 재작성"
```

---

## Task 2: 에이전트 — planner.md (신규)

**Files:**
- Create: `agents/planner.md`

**Step 1: planner.md 생성**

superclaude++의 requirements-analyst + business-panel-experts를 합친 기획 에이전트.

핵심 내용:
- **트리거**: 기획, PRD, 요구사항, 사업성, 비즈니스
- **Phase 1**: 요구사항 발견 — 소크라테스식 질문으로 "왜"를 먼저 파악
- **Phase 2**: 비즈니스 검증 — 9명 전문가 패널 토론 (Christensen, Porter, Drucker, Godin, Kim & Mauborgne, Collins, Taleb, Meadows, Doumont). Sequential/Debate/Socratic 모드
- **Phase 3**: PRD 작성 — 목표, 타겟 유저, 핵심 기능, 성공 지표, 스코프 정의
- **Phase 4**: 스코프 잠금 — 의존성 매핑, 우선순위 정렬, MVP 정의
- **산출물**: PRD, 비즈니스 분석 리포트, 기능 백로그
- **내부 호출 스킬**: /feature-planner, /gap-analysis

**Step 2: 커밋**

```bash
git add agents/planner.md
git commit -m "feat: planner 에이전트 추가 (기획/비즈니스 검증)"
```

---

## Task 3: 에이전트 — architect.md (신규)

**Files:**
- Create: `agents/architect.md`

**Step 1: architect.md 생성**

기존 engineer에서 설계 부분 분리 + FE 아키텍처 추가.

핵심 내용:
- **트리거**: 설계, 아키텍처, 스키마, ERD, 구조
- **Stack Detection 기반 분기**: BE 모드 / FE 모드 / 풀스택 모드
- **Phase 1**: 요구사항 분석 — 도메인 모델 변환, 영향 범위 분석
- **Phase 2**: BE 아키텍처 (Stack Detection 시) — DB 스키마, API 설계, 도메인 모델, 레이어 구조, DI 패턴 선택 (Depends/Container/Dishka)
- **Phase 3**: FE 아키텍처 (Stack Detection 시) — 컴포넌트 트리, 라우팅 구조, 상태관리 전략, API 통합 방식
- **Phase 4**: 통합 설계 (풀스택 시) — FE-BE 인터페이스, 데이터 흐름, 인증/인가 구조
- **설계 판단 기준**: 도메인 레이어 도입 여부, 캐싱 전략, 실시간 통신 필요 여부
- **산출물**: 아키텍처 문서, ERD, API 명세, 컴포넌트 구조도
- **내부 호출 스킬**: /confidence-check

**Step 2: 커밋**

```bash
git add agents/architect.md
git commit -m "feat: architect 에이전트 추가 (BE/FE 통합 설계)"
```

---

## Task 4: 에이전트 — engineer.md (확장)

**Files:**
- Create: `agents/engineer.md`

**Step 1: engineer.md 생성**

기존 BE 전용 engineer를 BE+FE 통합으로 확장.

핵심 내용:
- **트리거**: 구현, 만들어, 추가해, implement, create
- **Stack Detection 기반 분기**
- **BE 구현 (Python)**:
  - Phase 1: 도메인 유닛 테스트 작성
  - Phase 2: 도메인 모델 구현
  - Phase 3: Repository/Service 구현
  - Phase 4: Controller/API 구현
  - Phase 5: 통합 테스트
  - 레이어 책임: Controllers(HTTP 변환) → Service(비즈니스 로직) → Repository(데이터 접근)
  - 성능: N+1 방지 (lazy="raise"), 인덱스 전략, 커넥션 풀 관리
  - 보안: SQL injection 방지, 입력 검증, 인증/인가 체크
- **FE 구현 (React/Next.js)**:
  - Phase 1: 컴포넌트 테스트 작성
  - Phase 2: 컴포넌트 구현 (Server Component 우선)
  - Phase 3: 상태관리 & API 통합
  - Phase 4: 스타일링 & 접근성
  - Phase 5: E2E 테스트
  - React 규칙: RSC 우선, 'use client' 최소화, Compound Component 패턴
  - Next.js 규칙: App Router, Server Actions, ISR/SSG 활용
- **TDD 필수**: 테스트 먼저, 구현 나중
- **내부 호출 스킬**: /fastapi, /sqlalchemy, /react-best-practices, /testing

**Step 2: 커밋**

```bash
git add agents/engineer.md
git commit -m "feat: engineer 에이전트 BE+FE 통합으로 확장"
```

---

## Task 5: 에이전트 — reviewer.md, debugger.md, devops.md, writer.md

**Files:**
- Create: `agents/reviewer.md`
- Create: `agents/debugger.md`
- Create: `agents/devops.md`
- Create: `agents/writer.md`

**Step 1: reviewer.md 생성**

기존 code-reviewer를 FE 리뷰 추가하여 확장.

핵심 내용:
- **트리거**: 리뷰, 코드 품질, 리팩토링, 기술 부채
- Phase 1-5: 컨텍스트 → 비즈니스 로직 분석 → 체계적 리뷰 → 자동 검증 → 결과 작성
- BE 리뷰: SOLID, 타입 힌트, 테스트, 보안, 의존성 (각 20%)
- FE 리뷰 추가: 접근성, 성능(Core Web Vitals), 컴포넌트 패턴, 상태관리, 번들 크기
- 심각도: 🔴 CRITICAL ~ 👍 PRAISE
- 5개 카테고리 등급 A-F
- **내부 호출 스킬**: /python-best-practices, /web-design-guidelines, /audit

**Step 2: debugger.md 생성**

기존 root-cause-analyst를 리네이밍 + 강화.

핵심 내용:
- **트리거**: 버그, 디버깅, 왜 안 돼, 에러, 이상 현상
- Phase 1-5: 증상 수집 → 가설 수립 → 증거 검증 → 근본 원인 확정 → 재발 방지
- BE 빈출 패턴: N+1, 트랜잭션 누수, 비동기 데드락, 순환 import
- FE 빈출 패턴 추가: hydration mismatch, 무한 리렌더, 메모리 누수, CORS 에러
- 3+ Fix Rule 강제
- **내부 호출 스킬**: /build-fix, /learn

**Step 3: devops.md 생성**

기존 유지 + 풀스택 배포 추가.

핵심 내용:
- **트리거**: Docker, 배포, CI/CD, 인프라, 모니터링
- Phase 1-4: 현황 분석 → 설계 → 구현 → 운영 검증
- Docker: Multi-stage, non-root, HEALTHCHECK
- CI/CD: lint → type-check → test → security-scan → build → deploy
- 풀스택 추가: FE 빌드 파이프라인, Next.js standalone output, Vercel/Cloudflare Pages 배포
- 모니터링: 3 Pillars (Metrics, Logging, Tracing)
- **내부 호출 스킬**: /docker, /cicd, /production-checklist

**Step 4: writer.md 생성**

기존 유지.

핵심 내용:
- **트리거**: 문서, README, API 문서, ADR
- 8가지 문서 유형: README, ADR, 시스템 설계, API, 인프라, 런북, CHANGELOG, 온보딩
- Mermaid 다이어그램 가이드
- DRY Docs 원칙

**Step 5: 커밋**

```bash
git add agents/reviewer.md agents/debugger.md agents/devops.md agents/writer.md
git commit -m "feat: reviewer, debugger, devops, writer 에이전트 추가"
```

---

## Task 6: 공통 워크플로우 스킬 (9개)

**Files:**
- Create: `skills/confidence-check/SKILL.md`
- Create: `skills/verify/SKILL.md`
- Create: `skills/checkpoint/SKILL.md`
- Create: `skills/audit/SKILL.md`
- Create: `skills/build-fix/SKILL.md`
- Create: `skills/feature-planner/SKILL.md`
- Create: `skills/gap-analysis/SKILL.md`
- Create: `skills/learn/SKILL.md`
- Create: `skills/note/SKILL.md`

**Step 1: 각 스킬 YAML frontmatter + 본문 작성**

기존 스킬을 기반으로 재작성. 핵심 형식:

```yaml
---
name: skill-name
description: |
  Use when [트리거 조건].
  NOT for [미해당 조건].
---
```

각 스킬의 핵심 내용은 기존과 동일하되 Stack Detection을 반영하여 BE/FE 양쪽 모두 지원하도록 조정.

- **confidence-check**: 구현 전 4 카테고리 신뢰도 평가, ≥90% 통과선. BE/FE 양쪽 체크항목.
- **verify**: 7단계 검증 루프 (lint → type → architecture → test → security → deps → quality). BE=ruff+mypy+pytest, FE=eslint+tsc+jest/vitest.
- **checkpoint**: git stash/commit 기반 복원 지점. 위험 작업 전 자동 실행.
- **audit**: 커밋 전 프로젝트 규칙 검증. 내장 검사 10개 + 커스텀 규칙 (.claude/audit-rules/).
- **build-fix**: 빌드/린트 에러 최소 변경 수정. BE=ruff/mypy/pytest, FE=tsc/eslint/next build.
- **feature-planner**: 3+ 파일 기능 계획. Phase 기반 + 품질 게이트 + 의존성 매핑.
- **gap-analysis**: 설계 문서 vs 구현 코드 비교. Match Rate ≥90% 통과.
- **learn**: 디버깅 인사이트 영구 저장. 4개 조건 충족 시 memory/에 기록.
- **note**: 세션 메모 시스템. Working Memory / Priority Context / MANUAL 3단계.

**Step 2: 커밋**

```bash
git add skills/confidence-check/ skills/verify/ skills/checkpoint/ skills/audit/ skills/build-fix/ skills/feature-planner/ skills/gap-analysis/ skills/learn/ skills/note/
git commit -m "feat: 공통 워크플로우 스킬 9개 추가"
```

---

## Task 7: 백엔드 스킬 (5개)

**Files:**
- Create: `skills/fastapi/SKILL.md`
- Create: `skills/sqlalchemy/SKILL.md`
- Create: `skills/testing/SKILL.md`
- Create: `skills/python-best-practices/SKILL.md`
- Create: `skills/security-audit/SKILL.md`

**Step 1: 각 스킬 작성**

기존 스킬 + 제거된 스킬 내용을 통합:

- **fastapi**: 기존 + pydantic-schema(DTO, camelCase alias, 검증, 페이지네이션) + middleware(CORS, Auth, Rate Limit, 순서) + environment(pydantic-settings, .env, 멀티환경)
- **sqlalchemy**: 기존 + alembic(마이그레이션 생성, 관리, 롤백) 통합
- **testing**: 기존 유지. conftest, 도메인 유닛/통합 테스트 전략
- **python-best-practices**: 기존 + error-handling(예외 계층, 핸들러, 에러 코드) 통합
- **security-audit**: 기존 유지. JWT, RBAC, OWASP Top 10

**Step 2: 커밋**

```bash
git add skills/fastapi/ skills/sqlalchemy/ skills/testing/ skills/python-best-practices/ skills/security-audit/
git commit -m "feat: 백엔드 스킬 5개 추가 (통합 버전)"
```

---

## Task 8: 프론트엔드 스킬 (4개)

**Files:**
- Create: `skills/react-best-practices/SKILL.md`
- Create: `skills/web-design-guidelines/SKILL.md`
- Create: `skills/composition-patterns/SKILL.md`
- Create: `skills/webapp-testing/SKILL.md`

**Step 1: 각 스킬 작성**

superclaude++의 FE 스킬을 참고하되, 프리셋 형식에 맞게 재작성:

- **react-best-practices**: Vercel Engineering 기반 React/Next.js 40+ 규칙. Priority 0~8 카테고리. pnpm 필수, waterfall 제거, 번들 최적화, RSC, SWR, 리렌더링 최적화 등.
- **web-design-guidelines**: Vercel Web Interface Guidelines 기반 100+ 규칙. 접근성, 포커스, 폼, 애니메이션, 타이포, 성능, 내비게이션, 다크모드, 안티패턴 플래그.
- **composition-patterns**: boolean prop 폭발 방지, Compound Component, Provider 패턴, variant 컴포넌트, React 19 변경사항 (forwardRef 제거, use()).
- **webapp-testing**: Python Playwright 기반 로컬 웹앱 테스트. with_server.py 헬퍼, 정찰-후-행동 패턴, sync_playwright 사용.

**Step 2: 커밋**

```bash
git add skills/react-best-practices/ skills/web-design-guidelines/ skills/composition-patterns/ skills/webapp-testing/
git commit -m "feat: 프론트엔드 스킬 4개 추가 (superclaude++ 참고)"
```

---

## Task 9: 인프라 스킬 (3개)

**Files:**
- Create: `skills/docker/SKILL.md`
- Create: `skills/cicd/SKILL.md`
- Create: `skills/production-checklist/SKILL.md`

**Step 1: 각 스킬 작성**

기존 스킬 기반 + 풀스택 배포 내용 추가:

- **docker**: Multi-stage Dockerfile, docker-compose. 풀스택 추가: Next.js standalone output, nginx 리버스 프록시, multi-service compose.
- **cicd**: GitHub Actions, Quality Gates. 풀스택 추가: FE 빌드 파이프라인, Vercel/Cloudflare 배포 연동.
- **production-checklist**: 배포 전 필수 체크리스트. + monitoring 통합 (Health check, structlog, APM). FE 추가: Core Web Vitals, Lighthouse CI, 에러 트래킹 (Sentry).

**Step 2: 커밋**

```bash
git add skills/docker/ skills/cicd/ skills/production-checklist/
git commit -m "feat: 인프라 스킬 3개 추가 (풀스택 지원)"
```

---

## Task 10: 신규 Hooks (5개)

**Files:**
- Create: `hooks/type-check.sh`
- Create: `hooks/auto-format.sh`
- Create: `hooks/console-log-check.sh`
- Create: `hooks/convention-check.sh`
- Create: `hooks/todo-continuation.sh`

**Step 1: type-check.sh**

PostToolUse (Edit/Write) — .ts/.tsx 수정 시 tsc 자동 실행.
- CLAUDE_FILE_PATH에서 확장자 확인
- tsconfig.json을 디렉토리 트리 상향 탐색으로 찾기
- `npx tsc --noEmit --pretty false` 실행, 해당 파일 에러만 필터링
- 최대 5개 에러 출력

**Step 2: auto-format.sh**

PostToolUse (Edit/Write) — 자동 포맷팅.
- .py → `ruff format` + `ruff check --fix`
- .ts/.tsx/.js/.jsx/.json/.css/.md → Prettier (설정 존재 시에만)
- 변경 시 `✨ Auto-formatted` 메시지

**Step 3: console-log-check.sh**

PostToolUse (Edit/Write) — 디버그 코드 감지.
- .py → `print()`, `breakpoint()`, `pdb.set_trace()` 감지
- .ts/.tsx/.js/.jsx → `console.log/debug/info/warn/error` 감지
- 테스트 파일, config 스킵
- eslint-disable/noqa 주석 줄 제외
- 최대 3개 매칭 출력

**Step 4: convention-check.sh**

PostToolUse (Edit/Write) — 네이밍 컨벤션 검사.
- Python: snake_case 함수/변수, Test prefix 클래스
- TS/JS: camelCase 변수/함수, PascalCase interface/type, use prefix 훅
- CSS/SCSS: kebab-case 클래스, --kebab-case 변수

**Step 5: todo-continuation.sh**

Stop — 미완료 TODO 있으면 작업 중단 방지.
- todos/*.json에서 미완료 항목 집계
- 세션 입력에서 pending/in_progress 태스크 집계
- iteration-count.json으로 반복 횟수 추적
- MAX_ITERATIONS(10) 초과 시 정지 허용

**Step 6: 모든 hook 실행 권한 부여 후 커밋**

```bash
chmod +x hooks/type-check.sh hooks/auto-format.sh hooks/console-log-check.sh hooks/convention-check.sh hooks/todo-continuation.sh
git add hooks/type-check.sh hooks/auto-format.sh hooks/console-log-check.sh hooks/convention-check.sh hooks/todo-continuation.sh
git commit -m "feat: 신규 hooks 5개 추가 (FE 품질 + todo 연속)"
```

---

## Task 11: 템플릿 + install.sh 업데이트

**Files:**
- Create: `templates/notepad.md`
- Modify: `install.sh` — 에이전트/스킬 목록 업데이트
- Modify: `uninstall.sh` — 에이전트/스킬 목록 업데이트

**Step 1: notepad.md 복원**

```markdown
# Notepad

## Priority Context (500자 제한, 항상 로드)

## Working Memory (타임스탬프 포함, 7일 후 정리)

## MANUAL (영구 저장)
```

**Step 2: install.sh에서 에이전트/스킬 목록 업데이트**

기존 5 에이전트 → 7 에이전트, 33 스킬 → 21 스킬, 5 hooks → 10 hooks로 목록 변경.

**Step 3: uninstall.sh도 동일하게 업데이트**

**Step 4: 커밋**

```bash
git add templates/notepad.md install.sh uninstall.sh
git commit -m "chore: 템플릿 복원 및 설치 스크립트 업데이트"
```

---

## Task 12: settings.local.json 업데이트

**Files:**
- Modify: `.claude/settings.local.json`

**Step 1: 신규 hooks에 대한 권한 설정 추가**

PostToolUse, Stop 이벤트에 대한 hook 설정이 install.sh에서 처리되므로, settings.local.json에는 추가 Bash 권한만 필요하면 추가.

**Step 2: 커밋**

```bash
git add .claude/settings.local.json
git commit -m "chore: settings.local.json 권한 업데이트"
```

---

## Task 13: 최종 검증

**Step 1: 파일 구조 확인**

```bash
find . -name "*.md" -not -path "./.git/*" | sort
find . -name "*.sh" -not -path "./.git/*" | sort
find . -name "*.py" -not -path "./.git/*" | sort
```

예상 결과: CLAUDE.md + 7 agents/*.md + 21 skills/*/SKILL.md + 10 hooks/* + 1 templates/notepad.md + docs/plans/*.md

**Step 2: 각 파일이 비어있지 않은지 확인**

```bash
find . -name "*.md" -not -path "./.git/*" -empty
```

예상: 빈 결과 (모든 파일에 내용 있음)

**Step 3: Hook 실행 권한 확인**

```bash
ls -la hooks/
```

예상: 모든 .sh 파일이 -rwxr-xr-x

**Step 4: 최종 커밋 (필요 시)**

```bash
git status
```

---

## 실행 순서 요약

| Task | 내용 | 의존성 | 파일 수 |
|------|------|--------|---------|
| 1 | CLAUDE.md | 없음 | 1 |
| 2 | planner 에이전트 | Task 1 | 1 |
| 3 | architect 에이전트 | Task 1 | 1 |
| 4 | engineer 에이전트 | Task 1 | 1 |
| 5 | reviewer/debugger/devops/writer 에이전트 | Task 1 | 4 |
| 6 | 공통 워크플로우 스킬 | Task 1 | 9 |
| 7 | 백엔드 스킬 | Task 1 | 5 |
| 8 | 프론트엔드 스킬 | Task 1 | 4 |
| 9 | 인프라 스킬 | Task 1 | 3 |
| 10 | 신규 Hooks | Task 1 | 5 |
| 11 | 템플릿 + 설치 스크립트 | Task 1~10 | 3 |
| 12 | settings.local.json | Task 10 | 1 |
| 13 | 최종 검증 | Task 1~12 | 0 |

**병렬 실행 가능**: Task 2~10은 Task 1 완료 후 모두 병렬 실행 가능.
**총 파일 수**: 38개 (CLAUDE.md 1 + agents 7 + skills 21 + hooks 5 + templates 1 + install/uninstall 2 + settings 1)
