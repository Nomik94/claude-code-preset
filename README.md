# claude-code-preset

Claude Code를 위한 **풀스택 개발 프리셋**.
Python(FastAPI) 백엔드 + React/Next.js 프론트엔드를 기획부터 배포까지 지원합니다.

clone → `install.sh` 실행만으로 25개 skill, 7개 agent, 7개 hook이 설정됩니다.

## What is this?

Claude Code가 풀스택 프로젝트에서 일관된 아키텍처, 코딩 컨벤션, 워크플로우를 따르도록 하는 설정 파일 모음입니다.

**핵심 아이디어**:
- CLAUDE.md (~250줄)만 항상 로드, 나머지는 **on-demand**
- **Stack Detection**: `pyproject.toml` / `package.json` 감지로 BE/FE/풀스택 모드 자동 전환
- **Difficulty Assessment**: Simple/Medium/Complex 자동 판정 → 프로토콜 깊이 조절
- **Phase Gate**: 기획 → 설계 → 구현 → 검증 → 배포 풀사이클

## Quick Start

```bash
# 1. 저장소 clone
git clone https://github.com/Nomik94/claude-code-preset.git

# 2. 설치 (기존 설정 자동 백업)
cd claude-code-preset && ./install.sh

# 3. Claude Code 재시작 후 테스트
claude
> /fastapi              # BE 스킬 로드 확인
> /react-best-practices # FE 스킬 로드 확인
> /engineer             # 에이전트 스폰 확인
```

## Stack

**Backend (BE 모드)**
- Python 3.13+ / FastAPI (async) / SQLAlchemy 2.0 (async)
- Alembic / Pydantic v2 / pydantic-settings
- PyJWT + pwdlib (argon2) / **Poetry** (mandatory)
- Ruff + mypy --strict / pytest + pytest-asyncio + httpx

**Frontend (FE 모드)**
- React 18+ / Next.js 14+ (App Router)
- TypeScript strict mode / **pnpm** (mandatory)
- Tailwind CSS / shadcn/ui / ESLint + Prettier

## Architecture

**Backend**: `controllers → service → repository` (Layered, Folder-First)
**Frontend**: Server Components 기본, App Router, URL state 우선

## Structure

```
~/.claude/
├── CLAUDE.md                          # Core config (~250줄, 항상 로드)
│
├── agents/ (7개)
│   ├── planner                        # 기획: 요구사항 발굴, 비즈니스 패널 토론, PRD
│   ├── architect                      # 설계: BE/FE/풀스택 통합 아키텍처
│   ├── engineer                       # 구현: Python + React/Next.js TDD
│   ├── reviewer                       # 검증: 코드 리뷰, 품질 분석
│   ├── debugger                       # 검증: 근본 원인 분석, 체계적 디버깅
│   ├── devops                         # 배포: Docker, CI/CD, 모니터링
│   └── writer                         # 공통: API 문서, README, ADR
│
├── skills/ (25개 — on-demand, 키워드 매칭 시 로드)
│   │
│   │  # 공통 워크플로우
│   ├── confidence-check/              # 구현 전 신뢰도 평가 (≥90%)
│   ├── verify/                        # 완료 후 7단계 검증
│   ├── checkpoint/                    # 위험 작업 전 롤백 포인트
│   ├── audit/                         # 커밋/PR 전 규칙 검증
│   ├── build-fix/                     # 빌드 에러 자동 수정
│   ├── feature-planner/               # Phase 기반 기능 계획
│   ├── gap-analysis/                  # 설계 vs 구현 Match Rate
│   ├── learn/                         # 디버깅 인사이트 영구 저장
│   ├── note/                          # 세션 메모 시스템
│   │
│   │  # 백엔드 (pyproject.toml 감지 시)
│   ├── fastapi/                       # 프로젝트 구조, DI, DTO, 미들웨어, 환경 설정
│   │   └── references/                # EndpointPath, DI 패턴, DTO 예시, 미들웨어 순서
│   ├── sqlalchemy/                    # ORM, Repository 패턴, Alembic 마이그레이션
│   │   └── references/                # BaseRepository, 마이그레이션 가이드, 쿼리 패턴
│   ├── testing/                       # conftest, 유닛/통합 테스트 전략
│   │   └── scripts/                   # conftest_template.py
│   ├── python-best-practices/         # 타입 힌트, 린팅, 에러 핸들링, 보안
│   ├── security-audit/                # JWT, RBAC, OWASP Top 10
│   │   └── references/                # JWT 구현, OWASP 체크리스트
│   │
│   │  # 프론트엔드 (package.json 감지 시)
│   ├── react-best-practices/          # Vercel Engineering 40+ 규칙
│   │   └── references/                # Server Components, 번들 최적화, 데이터 페칭
│   ├── web-design-guidelines/         # 접근성/성능/UX 100+ 규칙
│   │   └── references/                # WCAG 체크리스트, Core Web Vitals
│   ├── composition-patterns/          # Compound Components, Provider 패턴
│   ├── webapp-testing/                # Playwright E2E 테스트
│   │   └── scripts/                   # with_server.py (서버 라이프사이클 헬퍼)
│   │
│   │  # 인프라/배포
│   ├── docker/                        # Multi-stage Dockerfile, compose
│   │   └── templates/                 # Dockerfile.be, Dockerfile.fe, docker-compose.yml
│   ├── cicd/                          # GitHub Actions, Quality Gates
│   ├── production-checklist/          # 배포 전 체크리스트 + 모니터링
│   │   └── references/                # 모니터링 설정, 알림 정책
│   │
│   │  # 스캐폴딩
│   ├── new-api/                       # FastAPI CRUD 보일러플레이트 생성
│   │   └── templates/                 # controller, dto, service, repository, test
│   ├── new-page/                      # Next.js 페이지 보일러플레이트 생성
│   │   └── templates/                 # page, loading, error, layout
│   │
│   │  # On-demand Hooks (호출 시에만 활성화)
│   ├── careful/                       # 위험 명령 차단 (rm -rf, DROP TABLE, force-push)
│   └── freeze/                        # 특정 디렉토리만 수정 허용
│
├── hooks/ (7개)
│   │  # PostToolUse (Edit/Write 시 자동)
│   ├── auto-format.sh                 # Ruff(PY) / Prettier(FE) 자동 포맷
│   ├── type-check.sh                  # tsc --noEmit (.ts/.tsx)
│   ├── console-log-check.sh           # print()/console.log() 감지
│   ├── convention-check.sh            # snake_case(PY) / camelCase(TS) 검사
│   │  # Session Lifecycle
│   ├── session-lessons.sh             # [SessionStart] memory/ 교훈 안내
│   ├── session-summary.py             # [SessionEnd] last-session.md 생성
│   │  # Stop
│   └── todo-continuation.sh           # 미완료 TODO 시 작업 중단 방지
│
├── templates/
│   └── notepad.md                     # Notepad 초기 템플릿
│
├── install.sh                         # 설치 (백업 + 모드 선택)
├── uninstall.sh                       # 제거 (백업 + 복원)
└── mcp-setup.sh                       # MCP 서버 설치 (대화형)
```

## Difficulty Assessment

모든 작업 시작 전 자동으로 난이도를 판정하고, 프로토콜 깊이를 조절합니다.

| Level | 기준 | 에이전트 흐름 | 스킬 |
|-------|------|-------------|------|
| **Simple** | 1-2 파일 | engineer 직접 | verify만 |
| **Medium** | 3-5 파일 | architect(선택) → engineer | confidence-check + verify + audit |
| **Complex** | 6+ 파일 | planner → architect → engineer | 전체 프로토콜 + checkpoint |

## Phase Gate

Complex 작업은 이 순서가 강제됩니다:

```
기획(planner) → 설계(architect) → 구현(engineer) → 검증(reviewer/debugger) → 배포(devops)
```

## Routing Priority

```
사용자 요청 → ① Agent 매칭? → YES → 에이전트 스폰
                              → NO  → ② Skill 매칭? → YES → 스킬 호출
                                                      → NO  → 직접 처리
```

### Agents

| Agent | Phase | 키워드 |
|-------|-------|--------|
| **planner** | 기획 | 기획, PRD, 요구사항, 사업성, 비즈니스 |
| **architect** | 설계 | 설계, 아키텍처, 스키마, ERD, 구조 |
| **engineer** | 구현 | 구현, 만들어, 추가해, implement, create |
| **reviewer** | 검증 | 리뷰, 코드 품질, 리팩토링, 기술 부채 |
| **debugger** | 검증 | 버그, 디버깅, 왜 안 돼, 에러, 이상 현상 |
| **devops** | 배포 | Docker, 배포, CI/CD, 인프라, 모니터링 |
| **writer** | 공통 | 문서, README, API 문서, ADR |

### Skills (25개)

각 Agent가 Phase에 따라 내부 스킬을 자동/판단 호출합니다. 상세는 각 agent.md 참조.

| Agent | 자동 호출 | 판단 호출 |
|-------|----------|----------|
| **engineer** | confidence-check, verify, checkpoint | fastapi, sqlalchemy, react, testing, security-audit 등 |
| **reviewer** | audit | python-best-practices, react, security-audit, web-design-guidelines |
| **debugger** | build-fix, learn | — |
| **planner** | feature-planner, gap-analysis | — |
| **architect** | confidence-check | — |
| **devops** | — | docker, cicd, production-checklist |

**유틸리티** (직접 호출): `/note` · `/learn` · `/careful` · `/freeze`
**스캐폴딩** (직접 호출): `/new-api` · `/new-page`

## Progressive Disclosure

대형 스킬은 **폴더 구조**로 구성되어 있습니다. SKILL.md에 핵심 규칙만 담고, 상세 코드/가이드는 `references/`에 분리합니다. Claude가 필요할 때만 읽으므로 토큰 효율적입니다.

```
skills/fastapi/
├── SKILL.md              # 핵심 규칙 + 의사결정 표
├── references/
│   ├── endpoint-path.md  # EndpointPath 헬퍼 상세
│   ├── di-patterns.md    # DI 패턴 비교 코드
│   ├── dto-examples.md   # Pydantic DTO 예시
│   └── middleware-order.md
└── gotchas.md            # Claude가 자주 틀리는 패턴
```

모든 21개 스킬에 `gotchas.md`가 포함되어 있습니다.

## Safety Rules

| Rule | 설명 |
|------|------|
| **3+ Fix Rule** | 같은 버그 3번 실패 → 즉시 중단, 아키텍처 재검토 |
| **Verification Gate** | "완료" 선언 전 반드시 실제 명령어 출력 확인 |
| **Two-Stage Review** | 커밋 전 Spec Compliance → Code Quality 순서 검증 |

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

## Installation

### Quick Install

```bash
git clone https://github.com/Nomik94/claude-code-preset.git
cd claude-code-preset && ./install.sh
```

### Install Modes

| Mode | Description |
|------|-------------|
| **Full install** | CLAUDE.md 교체 + skills + agents + hooks 설치 |
| **Skills only** | 기존 CLAUDE.md 유지, skills + agents + hooks만 추가 |

기존 설정은 `~/.claude/backup-{timestamp}/`에 자동 백업됩니다.

### MCP 서버 & Plugin 설치

`install.sh`와 별도로 실행 가능합니다.

```bash
./mcp-setup.sh           # 대화형 선택 (현재 상태 확인 → 개별 선택)
./mcp-setup.sh --all     # MCP 전체 + Plugin 설치
./mcp-setup.sh --core    # Core만 (context7 + sequential-thinking)
./mcp-setup.sh --list    # 설치 상태만 확인
```

#### MCP Servers

| Server | 패키지 | 용도 | 분류 |
|--------|--------|------|------|
| **context7** | `@upstash/context7-mcp` | 라이브러리 최신 문서/코드 예제 조회 | Core |
| **sequential-thinking** | `@modelcontextprotocol/server-sequential-thinking` | 복잡한 문제 단계별 분석, 아키텍처 설계 | Core |
| **playwright** | `@playwright/mcp` | 브라우저 자동화, E2E 테스트, 스크린샷 | Recommended |
| **github** | `@modelcontextprotocol/server-github` | PR/Issue/Review 관리, 코드 검색 | Recommended |
| **taskmaster** | `task-master-ai` | AI 프로젝트 플래닝, PRD → 태스크 분해 | Recommended |

> `github` MCP는 `GITHUB_PERSONAL_ACCESS_TOKEN`이 필요합니다. `gh auth login` 후 자동 추출됩니다.

#### Plugin

| Plugin | 마켓플레이스 | 용도 |
|--------|-------------|------|
| **superpowers** | `obra/superpowers-marketplace` | TDD, 브레인스토밍, 디버깅, 플래닝, 코드 리뷰 등 고급 워크플로우 |

> 자세한 가이드: [docs/mcp-and-plugins.md](docs/mcp-and-plugins.md)

## Uninstall

```bash
./uninstall.sh
```

## Summary

| 항목 | 수량 |
|------|------|
| 총 파일 | 104개 |
| CLAUDE.md | ~250줄 (항상 로드) |
| Agents | 7개 (planner → architect → engineer → reviewer/debugger → devops + writer) |
| Skills | 25개 (공통 9 + BE 5 + FE 4 + 인프라 3 + 스캐폴딩 2 + on-demand 2) |
| Gotchas | 21개 (전 스킬 Claude 빈출 실수 패턴) |
| References | 16개 (6개 대형 스킬 Progressive Disclosure) |
| Scripts/Templates | 17개 (실행 가능 스크립트 + 보일러플레이트) |
| Hooks | 7개 (PostToolUse 4 + Session 2 + Stop 1) |

## 출처 및 참고

이 프리셋은 다음 프로젝트와 자료를 참고하여 제작되었습니다:

| 출처 | 참고 내용 |
|------|----------|
| [excatt/superclaude-plusplus](https://github.com/excatt/superclaude-plusplus) | 프론트엔드 스킬 (react-best-practices, web-design-guidelines, composition-patterns, webapp-testing), 비즈니스 패널 에이전트, PostToolUse hooks (type-check, auto-format, console-log-check, convention-check), todo-continuation hook |
| [SuperClaude Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) | superclaude-plusplus의 기반 프레임워크 |
| [Anthropic — Lessons from Building Claude Code: Skills](https://www.anthropic.com/engineering/claude-code-skills) | Gotchas 섹션, Progressive Disclosure (references/), On-demand Hooks (/careful, /freeze), Code Scaffolding (/new-api, /new-page), 실행 가능 스크립트 패턴 |
| [Vercel Engineering — React Best Practices](https://vercel.com/blog) | react-best-practices 스킬의 40+ 규칙 원본 |
| [Vercel — Web Interface Guidelines](https://vercel.com/geist/introduction) | web-design-guidelines 스킬의 100+ 규칙 원본 |

## License

MIT
