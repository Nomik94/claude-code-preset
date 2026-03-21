# MCP Servers & Plugins 가이드

claude-code-preset에서 사용하는 MCP 서버와 플러그인 목록입니다.
`mcp-setup.sh`로 한번에 설치할 수 있습니다.

## 빠른 설치

```bash
# 전체 설치 (MCP + Plugin)
./mcp-setup.sh --all

# Core만 설치 (context7 + sequential-thinking)
./mcp-setup.sh --core

# 대화형 선택 모드
./mcp-setup.sh
```

---

## MCP Servers

### Core (필수)

| 서버 | 패키지 | 용도 |
|------|--------|------|
| **context7** | `@upstash/context7-mcp` | 라이브러리 최신 문서·코드 예제 조회. FastAPI, SQLAlchemy, Pydantic, React, Next.js 등 |
| **sequential-thinking** | `@modelcontextprotocol/server-sequential-thinking` | 복잡한 문제 단계별 분석, 아키텍처 설계, 디버깅 추론 |

### Recommended (권장)

| 서버 | 패키지 | 용도 |
|------|--------|------|
| **playwright** | `@playwright/mcp` | 브라우저 자동화, E2E 테스트, 스크린샷, DOM 스냅샷 |
| **github** | `@modelcontextprotocol/server-github` | GitHub PR/Issue/Review 관리, 코드 검색. `GITHUB_PERSONAL_ACCESS_TOKEN` 필요 |
| **taskmaster** | `task-master-ai` | AI 기반 프로젝트 플래닝, PRD → 태스크 분해, 의존성 관리 |

### Built-in (claude.ai 연동)

| 서버 | 용도 | 비고 |
|------|------|------|
| **mermaid-chart** | Mermaid 다이어그램 렌더링·검증 | claude.ai 내장, 별도 설치 불필요 |

---

## Plugin

| 플러그인 | 마켓플레이스 | 용도 |
|----------|-------------|------|
| **superpowers** | `obra/superpowers-marketplace` | TDD, 브레인스토밍, 디버깅, 플래닝, 코드 리뷰 등 고급 워크플로우 스킬 모음 |

설치 방법:
```bash
# settings.json에 마켓플레이스 등록 + 플러그인 활성화 (mcp-setup.sh --all 시 자동)
```

---

## CLAUDE.md Auto-MCP Triggers

CLAUDE.md에 정의된 자동 트리거 규칙:

| 조건 | 사용되는 MCP |
|------|-------------|
| FastAPI/SQLAlchemy/Pydantic + 구현 | Context7 |
| React/Next.js + 구현 | Context7 |
| 왜/원인/복잡한 분석 | Sequential Thinking |
| E2E/브라우저 테스트 | Playwright |
| PR/Issue 관리 | GitHub |
| 프로젝트 플래닝 | Taskmaster |

**조합 패턴**:
- 복잡한 버그 → Sequential + Context7
- 아키텍처 설계 → Sequential + Context7
- 대규모 리팩토링 → Sequential

---

## 환경변수 설정

GitHub MCP를 사용하려면 토큰이 필요합니다:

```bash
# GitHub CLI가 설치되어 있으면 자동으로 토큰을 가져옵니다
gh auth token

# 또는 직접 PAT 생성: https://github.com/settings/tokens
# 필요 권한: repo, read:org, read:user
```

---

## 문제 해결

```bash
# MCP 서버 상태 확인
claude mcp list

# 특정 서버 상세 정보
claude mcp get <서버이름>

# 서버 제거 후 재설치
claude mcp remove <서버이름> -s user
./mcp-setup.sh
```
