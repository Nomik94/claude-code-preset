# Fullstack Development Configuration

## Language
- **ALWAYS respond in Korean (한글)**
- Code comments: Korean / Variables·identifiers: English / Technical terms: English when common

## Difficulty Assessment (Step 0)

모든 작업 시작 전 난이도 판정. 이 판정이 프로토콜 깊이를 결정한다.

| Level | 기준 | 에이전트 흐름 | 스킬 |
|-------|------|-------------|------|
| Simple | 1-2 파일, 명확한 변경 | engineer 직접 | verify만 |
| Medium | 3-5 파일, 설계 필요 | architect(선택) → engineer | confidence-check + verify + audit |
| Complex | 6+ 파일, 아키텍처 영향 | planner → architect → engineer | 전체 프로토콜 + checkpoint |

- Simple: 즉시 실행. 에이전트 1개.
- Medium: 설계 검토 후 실행. 에이전트 1-2개.
- Complex: Phase Gate 강제. 기획→설계→구현→검증→배포 순서 필수.

## Stack Detection

프로젝트 파일로 모드 자동 결정:
- `pyproject.toml` → **BE 모드** (Python 규칙 활성)
- `package.json` → **FE 모드** (TypeScript 규칙 활성)
- 둘 다 존재 → **풀스택 모드** (양쪽 규칙 모두 활성)
- 둘 다 없음 → **범용 모드**

## Backend Rules (BE 모드 활성 시)

### Stack
Python 3.13+ / FastAPI (async) / SQLAlchemy 2.0 (async) / Alembic / Pydantic v2 / pydantic-settings
PyJWT + pwdlib (argon2) / **Poetry** (mandatory, no pip/uv/requirements.txt)
Ruff + mypy --strict / pytest + pytest-asyncio + httpx / structlog / Docker + docker-compose

### Architecture
- **Layered**: controllers → service → repository
- **Folder-First**: controllers/, dto/, exceptions/, constants/는 처음부터 폴더로 생성
- **DI**: Depends (small) | Manual Container (medium) | Dishka (large)
- **API Versioning**: `/{client}/v{version}/{domain}/{action}` via EndpointPath
- **lazy="raise"** — relationship 기본값, N+1 컴파일타임 방지

> Python 문법 상세(Modern Syntax, Pydantic v2)는 `/python-best-practices`, `/fastapi` 스킬 참조.

## Frontend Rules (FE 모드 활성 시)

### Stack
React 18+ / Next.js 14+ (App Router) / TypeScript strict mode
**pnpm** (mandatory, no npm/yarn) / Tailwind CSS / shadcn/ui / ESLint + Prettier

> FE 상세 규칙(Server Components, 상태관리, API 호출)은 `/react-best-practices` 스킬 참조.

## Naming Conventions

| Area | Convention | Example |
|------|-----------|---------|
| Python variable/function | snake_case | `get_user_data()` |
| Python class | PascalCase | `UserService` |
| Python/TS constant | SCREAMING_SNAKE | `MAX_PAGE_SIZE` |
| TS variable/function | camelCase | `getUserData()` |
| React component | PascalCase | `UserProfile` |
| DB column/table | snake_case | `created_at` |
| API JSON | camelCase | `createdAt` |
| URL path | kebab-case | `/api/v1/user-stats` |
| CSS class | kebab-case | `user-profile-card` |
| File (Python) | snake_case | `user_service.py` |
| File (React) | PascalCase (컴포넌트) / camelCase (유틸) | `UserProfile.tsx` / `useAuth.ts` |
| Env variable | SCREAMING_SNAKE | `POSTGRES_HOST` |

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

```
사용자 요청 → ① Agent 매칭? → YES → 에이전트 스폰 (내부에서 스킬 호출)
                              → NO  → ② 유틸리티 스킬? → YES → 직접 호출
                                                        → NO  → 직접 처리
```

### Agent → Skill 통합 매핑

키워드 매칭 시 Agent 스폰. Agent가 Phase에 따라 스킬을 자동/판단 호출. 상세는 각 agent.md 참조.

| Agent | Phase | 자동 스킬 | 판단 스킬 |
|-------|-------|----------|----------|
| planner | 기획 | spec, feature-planner, gap-analysis | — |
| architect | 설계 | confidence-check | — |
| engineer | 구현 | confidence-check, verify, checkpoint | fastapi, sqlalchemy, react-best-practices, testing, security-audit 등 |
| reviewer | 검증 | audit | python-best-practices, react-best-practices, security-audit 등 |
| debugger | 검증 | build-fix, learn | — |
| devops | 배포 | — | docker, cicd, production-checklist |
| writer | 공통 | — | — |

### Agent 트리거 키워드

매칭 시 해당 에이전트 스폰 필수. 공식 용어, 구어체, 동사형, 질문형, 영어 모두 포함.

**planner** (기획):
기획, PRD, 요구사항, 비즈니스, 사업성, MVP, 스코프, 기능 백로그, 로드맵, 스프린트, 유저 스토리, 페르소나, 시장 분석, 경쟁 분석, 아이디어, 컨셉, 방향성, 뭘 만들지, 어떤 기능, 먼저 뭐부터, 우선순위, 기능 목록, 기획해줘, 정리해줘(요구사항), 검증해줘(사업성), planning, requirements, backlog, roadmap, scope

**architect** (설계):
설계, 아키텍처, 스키마, ERD, 데이터 모델, API 설계, 시스템 설계, 시스템 구조, 클래스 다이어그램, 시퀀스 다이어그램, 구조, 폴더 구조, 테이블 설계, 테이블 구조, 레이어, 모듈, 패턴, 관계(DB), 연관 관계, 어떻게 나눌지, 구조 잡아, 분리해줘, 설계해줘, 컴포넌트 구조, 라우팅 설계, architecture, schema, design, data model, DDD, system design

**engineer** (구현):
구현, 개발, 코딩, 만들어, 추가해, 넣어줘, 붙여줘, 작성해, 짜줘, 바꿔줘, 수정해, 변경해, 적용해, 연동, 통합, 기능 추가, 코드 작성, 마이그레이션(코드), 설정해줘, 세팅해줘, 설치해줘, 올려줘(기능), implement, create, build, add, develop, code, integrate, setup, configure

**reviewer** (검증):
리뷰, 코드 리뷰, PR 리뷰, 코드 품질, 리팩토링, 기술 부채, 코드 스멜, 검토, 점검, 분석(코드), 평가, 개선점, 봐줘, 확인해줘, 괜찮은지, 문제 없는지, 더 나은 방법, 이거 괜찮아, 개선할 점, 클린 코드, SOLID, 코드 정리, review, refactor, code quality, tech debt, clean code

**debugger** (검증):
버그, 디버깅, 에러, 오류, 예외, exception, traceback, stack trace, 안 돼, 안 됨, 안 되는데, 동작 안 해, 작동 안 해, 깨짐, 터짐, 뻗음, 멈춤, 느려짐, 무한 로딩, 하얀 화면, 빈 화면, 실패, 이상, 이슈, 장애, 충돌, crash, 500, 404, 400, timeout, 무한루프, 메모리 누수, 왜 안 돼, 왜 이래, 뭐가 문제, 원인이 뭐야, 어디가 잘못, bug, debug, error, fix, broken, fail, issue, incident

**devops** (배포):
Docker, 배포, CI/CD, 인프라, 컨테이너, 파이프라인, 모니터링, 로깅, 알림, 서버, nginx, Dockerfile, docker-compose, GitHub Actions, 환경변수, SSL, HTTPS, 도메인, DNS, 로드밸런서, 스케일링, 무중단, 헬스체크, 대시보드, 올려줘(서버), 배포해줘, 띄워줘, deploy, container, pipeline, monitoring, logging, alert, scaling, health check

**writer** (공통):
문서, README, API 문서, ADR, 기술 문서, 아키텍처 문서, 문서화, 가이드, 매뉴얼, 튜토리얼, 런북, 변경 로그, CHANGELOG, 온보딩, 사용법, 설치 가이드, 기여 가이드, 릴리스 노트, 정리해줘(문서), 설명해줘(구조), documentation, guide, manual, runbook, changelog, release notes

- **MUST**(planner~devops): 키워드 매칭 시 에이전트 스폰 없이 직접 응답 금지.
- **SHOULD**(writer): "writer 에이전트를 실행할까요?" 제안 후 진행.
- **Skip**: 단순 1줄 수정, `--no-agent` 명시 시에만 생략.

**유틸리티** (직접 호출): `/note` · `/learn` · `/careful` · `/freeze`
**스캐폴딩** (직접 호출 겸용): `/new-api` · `/new-page`

### Phase Gate

Complex: 기획→스펙→설계→구현→검증→배포 순서 필수. Medium: (스펙→)설계→구현→검증. Simple: 구현→검증.

## Safety Rules

### 3+ Fix Rule
같은 버그 3번 수정 시도 실패 → **즉시 중단**. 아키텍처 재검토. 사용자에게 에스컬레이션.

### Verification Gate
"완료/수정됨/통과" 선언 전 **반드시** 실제 명령어 실행 + 전체 출력 확인.
- 금지: "should pass", "probably works", "looks correct"
- 필수: 실제 pytest/ruff/tsc/eslint 출력, 실제 exit code

### Two-Stage Review (커밋/PR 전)
1. **Spec Compliance**: 요구사항 대비 확인. Missing AND Excess 모두 체크.
2. **Code Quality**: Stage 1 통과 후에만. SOLID, 에러 핸들링, 테스트, 보안.

### Base Rules
- Read before Write/Edit
- No hardcoded credentials
- Framework respect: 라이브러리 사용 전 deps 확인
- Never skip tests/validation to make things work

## Git Rules
- Feature branch only, never main/master
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- `git diff` before staging
- No Co-Authored-By

## Hooks

| 이벤트 | Hook | 동작 |
|--------|------|------|
| PreToolUse | `pre-tool-use-safety.sh` | 위험 명령 사전 차단 |
| SessionStart | `session-lessons.sh` | memory/ 교훈 안내 |
| SessionEnd | `session-summary.py` | `memory/last-session.md` 생성 |
| Stop | `todo-continuation.sh` | 미완료 태스크 시 자동 계속 |

### Notepad (/note)
영구 메모 시스템. `/note --manual <content>` → MANUAL 섹션에 영구 저장.

## Auto-MCP Triggers

| Condition | MCP |
|-----------|-----|
| FastAPI/SQLAlchemy/Pydantic + 구현 | Context7 |
| React/Next.js + 구현 | Context7 |
| 왜/원인/복잡한 분석 | Sequential |
| E2E/브라우저 테스트 | Playwright |

조합: 복잡한 버그 → Sequential+Context7 | 아키텍처 설계 → Sequential+Context7 | 대규모 리팩토링 → Sequential
예외: `--no-mcp` 시 비활성화, 단순 1줄 변경 → Native

## Flags

| Flag | Effect |
|------|--------|
| `--think` | ~4K 분석, Sequential |
| `--think-hard` | ~10K, Sequential + Context7 |
| `--ultrathink` | ~32K, 전체 MCP |
| `--brainstorm` | 협업적 요구사항 탐색 |
| `--orchestrate` | 도구 최적화, 병렬 실행 |
| `--no-mcp` | 네이티브만 |
| `--no-agent` | 에이전트 스폰 생략 |
