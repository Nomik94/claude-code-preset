# claude-code-preset

Claude Code를 위한 FastAPI 백엔드 인프라 프리셋.
clone → install.sh 실행만으로 33개 skill, 5개 agent, 8개 hook이 설정됩니다.

## What is this?

Claude Code가 FastAPI 프로젝트에서 일관된 아키텍처, 코딩 컨벤션, 도구 사용 패턴을 따르도록 하는 설정 파일 모음입니다.

**핵심 아이디어**: CLAUDE.md (~230줄)만 항상 로드되고, 나머지는 **Skill 시스템**으로 필요할 때만 로드됩니다.

## Quick Start

```bash
# 1. 저장소 clone
git clone https://github.com/Nomik94/claude-code-preset.git

# 2. 설치 (기존 설정 자동 백업)
cd claude-code-preset && ./install.sh

# 3. Claude Code 재시작
# (새 터미널에서 claude 실행)

# 4. 설치 확인 — 아무 프로젝트에서 테스트
claude
> /fastapi    # → FastAPI skill 로드 확인
> /engineer   # → Engineer 에이전트 스폰 확인
```

### 프로젝트별 오버라이드

글로벌 skill을 프로젝트에 맞게 오버라이드하려면 프로젝트 루트에 `.claude/skills/`를 만듭니다:

```
my-project/
├── .claude/
│   └── skills/
│       └── fastapi/
│           └── SKILL.md    # 이 프로젝트만의 FastAPI 설정 (글로벌 오버라이드)
└── src/
```

프로젝트 레벨 skill이 글로벌 skill보다 우선 적용됩니다.

## Stack

- Python 3.13+ / FastAPI (async) / SQLAlchemy 2.0 (async)
- Alembic / Pydantic v2 / pydantic-settings
- PyJWT + passlib (bcrypt)
- Poetry (mandatory) / Ruff + mypy --strict
- pytest + pytest-asyncio + httpx
- structlog (JSON prod, console dev) / cashews or redis.asyncio
- Docker + docker-compose

## Architecture

```
controllers → application/service → domain/entity → infrastructure/repository
```

- **Folder-First**: controllers/, dto/, exceptions/, constants/는 처음부터 폴더로 생성
- **Domain Purity**: domain/에 프레임워크 import 금지
- **Protocol Ports**: Repository 인터페이스는 `typing.Protocol`
- **API Versioning**: `/{client}/v{version}/{domain}/{action}` via EndpointPath helper
- **DI**: Depends (small) | Manual Container (medium) | Dishka (large)
- **Sub-Application**: admin/app/web 분리, 클라이언트별 미들웨어/Swagger
- **lazy="raise"**: relationship 기본값, N+1 컴파일타임 방지
- **Mapping Table**: 도메인 예외→HTTP 변환은 mappings.py 한 곳에서 관리

## Installation

### Quick Install (권장)

```bash
git clone https://github.com/Nomik94/claude-code-preset.git
cd claude-code-preset && ./install.sh
```

### curl One-liner (선택)

```bash
curl -fsSL https://raw.githubusercontent.com/Nomik94/claude-code-preset/main/install.sh | bash
```

### Install Modes

| Mode | Description |
|------|-------------|
| **Full install** | CLAUDE.md 교체 + skills + agents + hooks 설치 |
| **Skills only** | 기존 CLAUDE.md 유지, skills + agents + hooks만 추가 |

기존 설정은 `~/.claude/backup-{timestamp}/`에 자동 백업됩니다.
settings.json의 기존 설정(statusLine, alwaysThinkingEnabled 등)은 보존됩니다.

### 설치 확인

```bash
# MCP 서버 확인
claude mcp list

# Skill 로드 확인 (아무 프로젝트에서)
claude
> /fastapi          # FastAPI 프로젝트 구조 skill 로드
> /python-best-practices  # Python 베스트 프랙티스 분석
```

## Structure

```
~/.claude/
├── CLAUDE.md                  # Core config (항상 로드, ~230줄)
│
├── skills/ (33개 — on-demand, 키워드 매칭 시 로드)
│   │
│   │  # Core FastAPI
│   ├── fastapi/               # 프로젝트 구조, DI, Ruff/mypy 설정
│   ├── domain-layer/          # Entity, VO, Aggregate, Repository Protocol
│   ├── api-design/            # REST API 설계, 파라미터 클래스, CRUD 패턴, EndpointPath
│   ├── middleware/             # CORS, Auth, Rate Limit, 미들웨어 순서
│   ├── environment/           # pydantic-settings, .env, 멀티환경
│   ├── websocket/             # ConnectionManager, 룸, Redis Pub/Sub
│   ├── background-tasks/      # BackgroundTasks vs Celery 판단 기준
│   │
│   │  # Data Layer
│   ├── sqlalchemy/            # Base, Mixin, Session, Repository 패턴
│   ├── alembic/               # 마이그레이션 생성/관리/롤백
│   ├── pydantic-schema/       # DTO, camelCase alias, 검증, 페이지네이션
│   │
│   │  # Quality & Safety
│   ├── testing/               # conftest, 도메인 유닛/통합 테스트
│   ├── debugging/             # pytest 플래그, SQL 트레이싱, 에러 매핑
│   ├── error-handling/        # 예외 계층, 핸들러, 에러 코드 체계
│   ├── security-audit/        # JWT, RBAC, OWASP Top 10 검증
│   │
│   │  # Infrastructure
│   ├── docker/                # Multi-stage Dockerfile, docker-compose
│   ├── cicd/                  # GitHub Actions, Quality Gates
│   ├── monitoring/            # Health check, structlog, Datadog APM
│   ├── production-checklist/  # 배포 전 필수 체크리스트
│   │
│   │  # Workflow (자동/수동 실행)
│   ├── confidence-check/      # 구현 전 신뢰도 평가 (≥90% 필요)
│   ├── verify/                # 완료 후 7단계 검증
│   ├── build-fix/             # 빌드/린트 에러 자동 수정
│   ├── feature-planner/       # 기능 계획, 스코프 잠금, 의존성 매핑
│   ├── gap-analysis/          # 설계 vs 구현 비교, Match Rate 산출
│   ├── learn/                 # 디버깅 인사이트 영구 저장
│   ├── checkpoint/            # 위험 작업 전 안전 체크포인트
│   ├── audit/                 # 커밋/PR 전 프로젝트 규칙 검증
│   ├── note/                  # 세션 메모, 컨텍스트 보존 (/note 명령)
│   │
│   │  # Python Quality
│   ├── python-best-practices/ # 타입 힌트, 린팅, 테스트, 보안, 의존성 종합 분석
│   │
│   │  # Agent Wrappers (/명령으로 에이전트 스폰)
│   ├── engineer/              # → engineer 에이전트 (설계+구현)
│   ├── code-review/           # → code-reviewer 에이전트 (리뷰)
│   ├── root-cause/            # → root-cause-analyst 에이전트 (디버깅)
│   ├── devops/                # → devops-architect 에이전트 (인프라)
│   └── docs/                  # → technical-writer 에이전트 (문서)
│
├── agents/ (5개 — Task tool로 스폰)
│   ├── engineer                # 설계+구현 (API, DB, 아키텍처, 성능, 보안, 테스트)
│   ├── code-reviewer           # 코드/PR 리뷰, 5-카테고리 스코어링
│   ├── root-cause-analyst      # 버그 원인 추적, 가설 검증
│   ├── devops-architect        # Docker, CI/CD, 인프라, 배포
│   └── technical-writer        # README, ADR, API 문서, 변경 로그
│
├── hooks/ (8개 — 6개 hook 이벤트)
│   │
│   │  # PostToolUse (Edit/Write 시 자동 실행)
│   ├── python-lint-check.sh    # ruff check --fix + ruff format 자동 수정
│   ├── python-type-check.sh    # mypy 타입 검사
│   ├── python-debug-check.sh   # print()/breakpoint()/pdb 감지
│   │
│   │  # Session Lifecycle
│   ├── session-lessons.sh      # [SessionStart] 프로젝트 교훈 존재 시 안내
│   ├── session-summary.py      # [SessionEnd] 세션 종료 시 memory/last-session.md 생성
│   │
│   │  # Context Preservation (3단계 자동화 파이프라인)
│   ├── suggest-compact.sh      # [PreToolUse] 도구 50회 시 /compact 제안
│   ├── pre-compact-note.sh     # [UserPromptSubmit] /compact 입력 시 저장 안내
│   └── pre-compact-save.sh     # [PreCompact] 압축 직전 state snapshot 저장
│
├── templates/
│   └── notepad.md              # Notepad 초기 템플릿 (설치 시 복사)
│
├── install.sh                  # 설치 스크립트
├── uninstall.sh                # 제거 스크립트 (백업 + 복원)
└── mcp-setup.sh                # MCP 서버 설치 (5종, 대화형)
```

## How It Works

### Context Budget

| Component | Tokens | When |
|-----------|--------|------|
| CLAUDE.md | ~2,000 | 항상 |
| Skill descriptions (33개) | ~560 | 항상 (1줄 요약) |
| Skill body | 1,000-2,000 | 키워드 매칭 시 |
| Agent prompt | 500-1,000 | Task 스폰 시 |

CLAUDE.md (~230줄)만 상시 로드되고, 나머지는 키워드 매칭 시 on-demand로 로드됩니다.

### Skill Auto-Trigger

Skills는 SKILL.md의 `description` 필드에 `Use when:` 패턴으로 트리거 키워드를 정의합니다.
Claude가 사용자 메시지와 키워드를 매칭하여 관련 skill을 자동으로 로드합니다.

```
"프로젝트 구조 잡아줘"     → /fastapi skill 로드
"엔티티 만들어줘"          → /domain-layer skill 로드
"테스트 코드 짜줘"         → /testing skill 로드
"Docker로 배포하고 싶어"   → /docker skill 로드
"기능 구현해줘"            → /confidence-check 자동 실행 → /feature-planner 제안
"메모해줘"                → /note skill 로드
```

### Auto-Invoke Skills

확인 없이 자동으로 실행되는 workflow 스킬:

| Trigger | Skill | 동작 |
|---------|-------|------|
| 구현 시작 전 | `/confidence-check` | 신뢰도 ≥90% 확인 후 진행 |
| 기능 완료 후 | `/verify` | 7단계 검증 (테스트, 린트, 타입, 보안, 품질 등) |
| 빌드 에러 | `/build-fix` | ruff/mypy 에러 자동 수정 |
| 위험 작업 전 | `/checkpoint` | git commit으로 롤백 포인트 생성 |
| 커밋/PR 전 | `/audit` | 프로젝트 규칙 위반 검사 |
| 문제 해결 후 | `/learn` | 디버깅 인사이트 저장 제안 |
| 3+ 파일 기능 | `/feature-planner` | 기능 계획 수립 제안 |

### Routing Priority

코드 관련 요청은 다음 우선순위로 처리됩니다:

```
사용자 요청 → ① Agent 매칭? → YES → 에이전트 스폰 (에이전트가 내부에서 스킬 호출)
                              → NO  → ② Skill 직접 매칭? → YES → 스킬 호출
                                                          → NO  → 직접 처리
```

#### ① Agent (1순위)

| 호출 | Agent | 키워드 |
|------|-------|--------|
| `/engineer` | engineer | 설계, 구현, API, DB 스키마, 아키텍처, TDD, 성능, 보안 |
| `/code-review` | code-reviewer | 코드 리뷰, PR 리뷰, 리팩토링, 코드 품질, 기술 부채 |
| `/root-cause` | root-cause-analyst | 버그 원인, 디버깅, 간헐적 에러, 이상 현상 |
| `/devops` | devops-architect | Docker, CI/CD, 배포, 모니터링, 인프라 |
| `/docs` | technical-writer | README, API 문서, ADR, 변경 로그 |

각 에이전트는 필수 스킬(`/confidence-check`, `/verify`, `/build-fix` 등)과 도메인 참조 스킬을 내부에서 자동 호출합니다.

#### ② Skill (2순위 — 에이전트 미매칭 시)

| Trigger | Skill | 키워드 |
|---------|-------|--------|
| 구현 전 | `/confidence-check` | 구현, 만들어, implement |
| 완료 후 | `/verify` | 완료, done, PR |
| 빌드 에러 | `/build-fix` | error, Build failed |
| 위험 작업 | `/checkpoint` | 리팩토링, 삭제, 마이그레이션 |
| 커밋/PR 전 | `/audit` | 커밋, PR, 배포 |

### Hooks

#### PostToolUse (Edit/Write 시 자동 실행)

| Hook | 동작 |
|------|------|
| `python-lint-check.sh` | ruff로 auto-fix + format 후 unfixable 이슈만 보고 |
| `python-type-check.sh` | mypy 타입 에러 검출 |
| `python-debug-check.sh` | 소스 코드 내 `print()`, `breakpoint()`, `pdb` 감지 |

#### Session Lifecycle

| Hook 타입 | 파일 | 동작 |
|----------|------|------|
| SessionStart | `session-lessons.sh` | 프로젝트에 `/learn`으로 저장된 교훈이 있으면 안내 |
| SessionEnd | `session-summary.py` | 세션 종료 시 `memory/last-session.md` 자동 생성 |

#### Context Preservation (3단계 자동화 파이프라인)

컨텍스트 한계 도달 전 능동적으로 관리하는 자동화 파이프라인:

| 단계 | Hook 타입 | 파일 | 동작 |
|------|----------|------|------|
| 1 | PreToolUse | `suggest-compact.sh` | 도구 50회 사용 시 `/compact` 제안 (이후 25회마다) |
| 2 | UserPromptSubmit | `pre-compact-note.sh` | `/compact` 입력 감지 → 저장 안내 표시 |
| 3 | PreCompact | `pre-compact-save.sh` | 압축 직전 state snapshot 자동 저장 |

### Notepad (`/note`)

컴팩션에서 살아남는 세션 메모 시스템:

```
/note <content>                → Working Memory (타임스탬프 포함)
/note --priority <content>     → Priority Context (항상 로드, 500자)
/note --manual <content>       → MANUAL 섹션 (영구 저장)
/note --show                   → 전체 내용 표시
/note --prune                  → 7일+ 항목 자동 정리
```

### Safety Rules

CLAUDE.md에 내장된 3가지 안전 장치:

| Rule | 설명 |
|------|------|
| **3+ Fix Rule** | 같은 버그 3번 수정 실패 시 즉시 중단, 아키텍처 재검토 |
| **Verification Gate** | "완료" 선언 전 반드시 실제 명령어 출력 확인 필수 |
| **Two-Stage Review** | 커밋 전 1) Spec Compliance → 2) Code Quality 순서 검증 |

### MCP Auto-Triggers

| Condition | MCP Server |
|-----------|------------|
| FastAPI/SQLAlchemy + 구현/사용법 | Context7 |
| 왜/원인/이상하게 + 복잡한 분석 | Sequential |
| 리네임/참조 찾기/프로젝트 전체 변경 | Serena |
| E2E/브라우저 테스트/스크린샷 | Playwright |
| 로그 조회/메트릭/모니터 | Datadog |

## Flags

| Flag | Effect |
|------|--------|
| `--think` | ~4K 분석, Sequential |
| `--think-hard` | ~10K, Sequential + Context7 |
| `--ultrathink` | ~32K, 전체 MCP |
| `--brainstorm` | 협업적 요구사항 탐색 |
| `--orchestrate` | 도구 최적화, 병렬 실행 |
| `--uc` | 심볼 커뮤니케이션, 토큰 30-50% 감소 |
| `--no-mcp` | 네이티브만 |

## Skills Reference

### Auto-Invoke (확인 없이 자동 실행)
- `/confidence-check` — 구현 전 신뢰도 평가
- `/verify` — 완료 후 7단계 검증
- `/build-fix` — 빌드 에러 자동 수정
- `/checkpoint` — 위험 작업 전 롤백 포인트 생성
- `/audit` — 커밋/PR 전 규칙 위반 검사

### By Domain
- **FastAPI**: `/fastapi`, `/domain-layer`, `/api-design`, `/middleware`, `/environment`
- **Data**: `/sqlalchemy`, `/alembic`, `/pydantic-schema`
- **Async**: `/background-tasks`, `/websocket`
- **Quality**: `/testing`, `/debugging`, `/error-handling`, `/security-audit`, `/python-best-practices`
- **Infra**: `/docker`, `/cicd`, `/monitoring`, `/production-checklist`
- **Workflow**: `/feature-planner`, `/gap-analysis`, `/learn`, `/checkpoint`, `/audit`, `/note`

### Agent (에이전트 스폰)
- `/engineer` — 설계 + 구현
- `/code-review` — 코드/PR 리뷰
- `/root-cause` — 버그 원인 분석
- `/devops` — 인프라/배포
- `/docs` — 문서 작성

## MCP Servers Setup

CLAUDE.md의 Auto-MCP Triggers가 작동하려면 MCP 서버가 설치되어 있어야 합니다.

### 자동 설치 (권장)

```bash
# 대화형 선택
./mcp-setup.sh

# 전체 설치
./mcp-setup.sh --all

# 핵심만 설치 (context7 + sequential-thinking)
./mcp-setup.sh --core
```

### 개별 설치

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add sequential-thinking -- npx -y @anthropics/sequential-thinking-mcp@latest
claude mcp add playwright -- npx -y @anthropic/mcp-playwright@latest
claude mcp add serena -- uvx serena-mcp
claude mcp add datadog-mcp -- npx -y @anthropic/mcp-datadog@latest
```

### MCP Server 목록

| Server | Purpose | 필수 여부 | 환경변수 |
|--------|---------|----------|----------|
| **context7** | 공식 라이브러리 문서 조회 | 권장 | - |
| **sequential-thinking** | 복잡한 분석, 다단계 추론 | 권장 | - |
| **playwright** | 브라우저 자동화, E2E 테스트 | 선택 | - |
| **serena** | 시맨틱 코드 이해, 심볼 작업 | 선택 | - |
| **datadog-mcp** | 로그/메트릭/모니터 조회 | 선택 | `DD_API_KEY`, `DD_APP_KEY` |

### 환경변수 설정 (필요 시)

```bash
# Datadog (사용하는 경우만)
export DD_API_KEY="your-api-key"
export DD_APP_KEY="your-app-key"

# ~/.zshrc 또는 ~/.bashrc에 추가
echo 'export DD_API_KEY="your-api-key"' >> ~/.zshrc
echo 'export DD_APP_KEY="your-app-key"' >> ~/.zshrc
```

### 설치 확인

```bash
claude mcp list
```

## Uninstall

```bash
# 자동 제거 (백업 생성 + 이전 설정 복원 옵션)
./uninstall.sh

# 또는 수동 복원
cp -r ~/.claude/backup-{timestamp}/* ~/.claude/
```

## Summary

| 항목 | 수량 |
|------|------|
| 총 파일 | 52개 |
| Skills | 33개 (도메인 28 + 에이전트 wrapper 5) |
| Agents | 5개 (engineer, reviewer, analyst, devops, writer) |
| Hooks | 8개 (PostToolUse 3 + Session 2 + Context 3) |
| Templates | 1개 (notepad.md) |
| Scripts | 3개 (install/uninstall/mcp-setup) |
| CLAUDE.md | ~230줄 (항상 로드) |
