# Backend Infrastructure Configuration

## Language
- **ALWAYS respond in Korean (한글)**
- Code comments/variables: English
- Technical terms: English when common (WebSocket, API, etc.)

## Stack
- Python 3.13+ / FastAPI (async) / SQLAlchemy 2.0 (async)
- Alembic / Pydantic v2 / pydantic-settings
- PyJWT + passlib (bcrypt)
- **Poetry** (mandatory, no pip/uv/requirements.txt)
- Ruff + mypy --strict / pytest + pytest-asyncio + httpx
- structlog (JSON prod, console dev) / cashews or redis.asyncio
- Docker + docker-compose

## Architecture
- **Domain Layer**: `controllers → application/service → domain/entity → infrastructure/repository`
- **Folder-First**: controllers/, dto/, exceptions/, constants/는 처음부터 폴더로 생성
- **DI**: Depends (small) | Manual Container (medium) | Dishka (large)
- **API Versioning**: `/{client}/v{version}/{domain}/{action}` via EndpointPath helper
- **Sub-Application**: admin/app/web 분리, 클라이언트별 미들웨어/Swagger

## Core Rules
1. **Poetry only** — no pip, uv, requirements.txt
2. **Async first** — all DB operations use AsyncSession
3. **Domain purity** — domain/ has zero framework imports (no FastAPI, SQLAlchemy, Pydantic)
4. **Protocol ports** — Repository interfaces use `typing.Protocol`
5. **Type safety** — mypy strict mode, Ruff comprehensive rules
6. **Test pyramid** — Unit (domain, no DB) > Integration (API) > E2E
7. **EndpointPath** — no hardcoded path strings in controllers
8. **Python 3.13+ 문법 필수** — 아래 Modern Syntax 섹션 준수
9. **Folder-first** — controllers/, dto/, exceptions/, constants/는 처음부터 폴더
10. **lazy="raise"** — relationship 기본값, N+1 컴파일타임 방지
11. **Mapping table** — 도메인 예외→HTTP 변환은 mappings.py 한 곳에서 관리

## Modern Python Syntax (3.13+)

**반드시 최신 문법만 사용. 레거시 패턴 금지.**

| Legacy (금지) | Modern (필수) |
|--------------|--------------|
| `Optional[X]` | `X \| None` |
| `Union[X, Y]` | `X \| Y` |
| `List[X]`, `Dict[K,V]`, `Tuple[X,...]`, `Set[X]` | `list[X]`, `dict[K,V]`, `tuple[X,...]`, `set[X]` |
| `from typing import List, Dict, Tuple, Set, Optional, Union` | builtin 제네릭 사용 |
| `from typing import Sequence` | `from collections.abc import Sequence` |
| `-> "ClassName"` (self 반환) | `-> Self` (`from typing import Self`) |
| `class Status(str, Enum)` | `class Status(StrEnum)` |
| `@dataclass` | `@dataclass(slots=True)` |
| `@dataclass(frozen=True)` | `@dataclass(frozen=True, slots=True)` |

**유지되는 `typing` imports** (builtin 대체 없음):
`Generic`, `TypeVar`, `Protocol`, `runtime_checkable`, `Literal`, `Self`, `ClassVar`, `TypeAlias`, `overload`

**Pydantic v2 필수**:
- `model_config = ConfigDict(...)` (not `class Config:`)
- `model_dump()` (not `.dict()`)
- `model_validate()` (not `.parse_obj()`)
- `field_validator` / `model_validator` (not `@validator`)

## Naming
| Area | Convention | Example |
|------|-----------|---------|
| Variable/Function | snake_case | `get_user_data()` |
| Class | PascalCase | `UserService` |
| Constant | SCREAMING_SNAKE | `MAX_PAGE_SIZE` |
| File | snake_case | `user_service.py` |
| DB Column/Table | snake_case | `created_at` |
| API JSON | camelCase | `createdAt` |
| URL Path | kebab-case | `/api/v1/user-stats` |
| Env Variable | SCREAMING_SNAKE | `POSTGRES_HOST` |

## Agent Orchestration

### Orchestrator vs Worker
| Orchestrator (you) | Worker (spawned) |
|---|---|
| 작업 분해, Task 생성, 결과 합성 | 구체적 작업 실행, 도구 직접 사용 |
| AskUserQuestion 사용 | 결과를 절대 경로로 보고 |
| 직접 코드 작성 금지 | 서브에이전트 스폰 금지 |

Worker prompt 필수: `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`

### 서브에이전트 전략
- 메인 컨텍스트 보호: 조사, 탐색, 병렬 분석은 서브에이전트에 위임
- 서브에이전트 1개 = 1개 작업 (집중 실행)
- 복잡한 문제일수록 서브에이전트 적극 투입

### Agent Selection
| Agent | Triggers |
|-------|----------|
| engineer | 설계, 구현, API, DB 스키마, 아키텍처, TDD, 성능, 보안, 테스트 |
| code-reviewer | 코드 리뷰, PR 리뷰, 리팩토링, 코드 품질, 기술 부채 |
| root-cause-analyst | 버그 원인, 디버깅, 간헐적 에러, 왜 안 돼, 이상 현상 |
| devops-architect | Docker, CI/CD, 배포, 모니터링, 인프라 |
| technical-writer | README, API 문서, ADR, 변경 로그 |

### Model Selection
| Task | Model | Count |
|------|-------|-------|
| 탐색, 간단한 검색 | haiku | 5-10 병렬 |
| 구현, 리뷰 | opus | 1-3 |
| 아키텍처, 복잡한 추론 | opus | 1-2 |

## Auto-MCP Triggers
| Condition | MCP |
|-----------|-----|
| FastAPI/SQLAlchemy/Pydantic + 구현/사용법 | Context7 |
| 왜/원인/이상하게/간헐적 + 복잡한 분석 | Sequential |
| 리네임/참조 찾기/프로젝트 전체 변경 | Serena |
| E2E/브라우저 테스트/스크린샷 | Playwright |
| 로그 조회/메트릭/모니터/prod 이슈 | Datadog |

조합: 복잡한 버그 → Sequential+Context7 | 아키텍처 설계 → Sequential+Context7 | 대규모 리팩토링 → Serena+Sequential
예외: `--no-mcp` 시 전체 비활성화, 단순 1줄 변경 → Native

## Auto-Skill Triggers
| Trigger | Skill | Keywords |
|---------|-------|----------|
| 구현 전 | `/confidence-check` | 구현, 만들어, implement |
| 완료 후 | `/verify` | 완료, done, PR |
| 빌드 에러 | `/build-fix` | error, Build failed |
| Python 리뷰 | `/python-best-practices` | .py + 리뷰 |
| 위험 작업 | `/checkpoint` | 리팩토링, 삭제 |
| 해결 후 | `/learn` (제안) | 해결, solved |
| 3+ 파일 기능 | `/feature-planner` (제안) | 기능 구현, 큰 작업 |
| 커밋/PR 전 | `/audit` | 커밋, PR, 배포 |

Skip: 단순 오타, 주석, 포맷팅, `--no-check`

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

## Git Rules
- 세션 시작: `git status` + `git branch`
- Feature branch only, never main/master
- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- `git diff` before staging
- No Co-Authored-By

## Context Preservation

컨텍스트 한계 도달 전 능동적 관리. 4단계 자동화 파이프라인.

### 자동화 파이프라인
1. **SessionStart** `session-lessons.sh`: 세션 시작 시 프로젝트 교훈(memory/) 존재 여부 안내
2. **PreToolUse** `suggest-compact.sh`: 도구 50회 사용 시 → "/note 저장 후 /compact" 제안 (이후 25회마다 반복)
3. **UserPromptSubmit** `pre-compact-note.sh`: `/compact` 입력 감지 → 저장 안내 표시
4. **PreCompact** `pre-compact-save.sh`: 압축 직전 state snapshot 자동 저장
5. **SessionEnd** `session-summary.py`: 세션 종료 시 `memory/last-session.md` 자동 생성

### Notepad (`/note`)
```
/note <content>                → Working Memory (타임스탬프 포함)
/note --priority <content>     → Priority Context (항상 로드, 500자)
/note --manual <content>       → MANUAL 섹션 (영구 저장)
/note --show                   → 전체 내용 표시
/note --prune                  → 7일+ 항목 자동 정리
```

## Safety

### 3+ Fix Rule
같은 버그 3번 수정 시도 실패 → **즉시 중단**. 아키텍처 재검토. 사용자에게 에스컬레이션.
- 매 수정이 새 문제를 만들면 → 패턴 자체가 잘못됨
- "한 번만 더" 금지 → STOP 후 근본 원인 재분석

### Verification Gate
"완료/수정됨/통과" 선언 전 **반드시** 실제 명령어 실행 + 전체 출력 확인.
- ❌ "should pass", "probably works", "looks correct"
- ✅ 실제 `pytest` 출력, 실제 `ruff check` 결과, 실제 exit code

### Two-Stage Review (커밋/PR 전)
1. **Spec Compliance**: 코드 직접 읽고 요구사항 대비 확인. Missing AND Excess 모두 체크.
2. **Code Quality**: Stage 1 통과 후에만 실행. SOLID, 에러 핸들링, 테스트, 보안.

### Base Rules
- Read before Write/Edit
- No hardcoded credentials
- Framework respect: check deps before using libraries
- Never skip tests/validation to make things work
- Root cause analysis, not workarounds

## Skills Reference

### Auto-Invoke
`/confidence-check`, `/verify`, `/build-fix`, `/checkpoint`, `/audit`

### By Domain
- **FastAPI**: `/fastapi`, `/domain-layer`, `/api-design`, `/middleware`, `/environment`
- **Data**: `/sqlalchemy`, `/alembic`, `/pydantic-schema`
- **Quality**: `/testing`, `/error-handling`, `/debugging`, `/production-checklist`, `/audit`
- **Workflow**: `/feature-planner`, `/gap-analysis`, `/learn`, `/checkpoint`
- **Security**: `/security-audit`
- **Infra**: `/docker`, `/cicd`, `/monitoring`
- **Async**: `/background-tasks`, `/websocket`
