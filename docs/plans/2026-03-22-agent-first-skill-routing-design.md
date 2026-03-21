# Agent-First Skill Routing 설계

## 개요

스킬 호출의 진입점을 Agent로 통합하여, CLAUDE.md의 25개 스킬 테이블을 Agent 매핑 요약으로 대체한다.
각 agent.md가 스킬의 source of truth가 되며, 유틸리티 스킬만 직접 호출을 유지한다.

## 배경

### 현재 구조 (2단계 라우팅)
```
요청 → ① Agent 매칭? → Agent 스폰 (내부에서 스킬 호출)
     → ② Skill 매칭? → 스킬 직접 호출 (CLAUDE.md 테이블 기반)
     → ③ 직접 처리
```

### 문제점
1. CLAUDE.md에 25개 스킬 테이블이 ~35줄 차지 (항상 로드됨)
2. CLAUDE.md 스킬 테이블과 agent.md "내부 호출 스킬"이 같은 내용을 중복 관리
3. 스킬 추가/변경 시 CLAUDE.md + agent.md 양쪽 동기화 필요

### 목표 구조 (Agent-First)
```
요청 → ① Agent 매칭? → Agent 스폰 → Agent가 자동/판단으로 스킬 호출
     → ② 유틸리티 스킬? → 직접 호출
     → ③ 직접 처리
```

## 설계

### 1. 스킬 호출 방식 — 하이브리드 (자동 + 판단)

| 방식 | 대상 | 동작 |
|------|------|------|
| **자동 호출** | 코어 스킬 (verify, audit, checkpoint 등) | Agent의 Phase에 고정. 빼먹으면 안 되는 것들 |
| **판단 호출** | 기술 스킬 (fastapi, react, testing 등) | Agent가 Stack Detection 등 상황을 보고 필요시 호출 |
| **직접 호출** | 유틸리티 (note, careful, freeze) | Agent 거치지 않고 사용자가 직접 호출 |

### 2. 공유 스킬 — 주 담당 Agent 지정

여러 Agent가 사용할 수 있는 스킬은 1개의 주 담당 Agent를 지정한다.
다른 Agent도 필요시 호출 가능하지만, 자동 호출은 주 담당만.

| 공유 스킬 | 주 담당 | 이유 |
|----------|---------|------|
| `/verify` | engineer | 구현 완료 시점이 검증의 자연스러운 타이밍 |
| `/checkpoint` | engineer | 위험 작업(리팩토링, 삭제)의 실행 주체 |
| `/confidence-check` | engineer | 구현 시작 전 게이트 (architect도 설계 완료 후 호출) |
| `/audit` | reviewer | 커밋/PR 전 규칙 검증은 리뷰의 마지막 단계 |
| `/learn` | debugger | 문제 해결 후 인사이트 저장 (사용자 직접 호출도 가능) |

### 3. 에이전트별 스킬 매핑 (전체)

#### Engineer (구현)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 자동 | confidence-check | 구현 시작 전 |
| 자동 | verify | 구현 완료 후 |
| 자동 | checkpoint | 리팩토링/삭제/마이그레이션 전 |
| 판단 | fastapi | pyproject.toml 감지 시 |
| 판단 | sqlalchemy | pyproject.toml + DB 작업 시 |
| 판단 | react-best-practices | package.json 감지 시 |
| 판단 | web-design-guidelines | UI 컴포넌트 구현 시 |
| 판단 | composition-patterns | 복합 컴포넌트 설계 시 |
| 판단 | testing | 테스트 작성 시 |
| 판단 | security-audit | 인증/인가 구현 시 |
| 판단 | new-api | FastAPI 엔드포인트 신규 생성 시 |
| 판단 | new-page | Next.js 페이지 신규 생성 시 |

#### Reviewer (검증)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 자동 | audit | 리뷰 완료 후 (커밋/PR 전) |
| 판단 | python-best-practices | Python 코드 리뷰 시 |
| 판단 | react-best-practices | React/Next.js 코드 리뷰 시 |
| 판단 | security-audit | 보안 관련 코드 리뷰 시 |
| 판단 | web-design-guidelines | UI 접근성 리뷰 시 |

#### Debugger (버그 분석)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 자동 | build-fix | 빌드/린트 에러 발생 시 |
| 자동 | learn | 문제 해결 완료 후 |

#### Planner (기획)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 자동 | feature-planner | Phase 4, 기능 3개 이상 시 |
| 자동 | gap-analysis | 스코프 잠금 후 |

#### Architect (설계)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 자동 | confidence-check | 설계 완료 후, engineer 전달 전 |

#### DevOps (배포)
| 구분 | 스킬 | 호출 시점 |
|------|------|---------|
| 판단 | docker | Docker 관련 작업 시 |
| 판단 | cicd | CI/CD 파이프라인 구성 시 |
| 판단 | production-checklist | 배포 전 최종 점검 시 |

#### Writer (문서)
내부 스킬 없음. 코드베이스 직접 분석하여 문서 작성.

#### 유틸리티 (직접 호출)
| 스킬 | 용도 |
|------|------|
| /note | 세션 메모 시스템 |
| /learn | 디버깅 인사이트 저장 (debugger 자동 + 직접 호출 겸용) |
| /careful | 위험 명령 차단 (on-demand hook) |
| /freeze | 디렉토리 수정 제한 (on-demand hook) |

### 4. CLAUDE.md 변경

`② Skill Triggers` 섹션(~35줄)을 `② Skill Routing` 섹션(~15줄)으로 대체.

```markdown
### ② Skill Routing (2순위)

각 Agent가 Phase에 따라 스킬을 자동/판단 호출. 상세는 각 agent.md의 "내부 호출 스킬" 참조.

| Agent | 자동 호출 | 판단 호출 |
|-------|----------|----------|
| engineer | confidence-check, verify, checkpoint | fastapi, sqlalchemy, react, testing, security-audit, new-api, new-page 등 |
| reviewer | audit | python-best-practices, react, security-audit, web-design-guidelines |
| debugger | build-fix, learn | — |
| planner | feature-planner, gap-analysis | — |
| architect | confidence-check | — |
| devops | — | docker, cicd, production-checklist |

**유틸리티** (Agent 거치지 않고 직접 호출):
`/note` · `/learn` · `/careful` · `/freeze`

**스캐폴딩** (직접 호출 겸용):
`/new-api` · `/new-page`
```

### 5. Agent.md 변경

각 agent.md의 "내부 호출 스킬" 섹션을 자동/판단으로 재구성.

**변경 대상**: engineer.md, reviewer.md, debugger.md, planner.md, architect.md, devops.md (6개)
**변경 없음**: writer.md

### 6. README.md 변경

"Skills (25개)" 섹션의 3개 테이블을 Agent 매핑 요약 테이블 + 유틸리티/스캐폴딩으로 대체.

## 변경 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| CLAUDE.md | Skill Triggers → Skill Routing 테이블 대체 |
| agents/engineer.md | 내부 호출 스킬 → 자동 3개 + 판단 9개 |
| agents/reviewer.md | 내부 호출 스킬 → 자동 1개 + 판단 4개 |
| agents/debugger.md | 내부 호출 스킬 → 자동 2개 |
| agents/planner.md | 내부 호출 스킬 → 자동 2개 |
| agents/architect.md | 내부 호출 스킬 → 자동 1개 |
| agents/devops.md | 내부 호출 스킬 → 판단 3개 |
| README.md | Skills 섹션 Agent 매핑으로 대체 |

**총 8개 파일 수정, 신규 파일 없음.**
