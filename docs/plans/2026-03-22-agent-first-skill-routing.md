# Agent-First Skill Routing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 스킬 호출의 진입점을 Agent로 통합하여 CLAUDE.md를 간결하게 만들고, 각 agent.md가 스킬의 source of truth가 되도록 한다.

**Architecture:** CLAUDE.md의 ~35줄 Skill Triggers 테이블을 ~15줄 Agent 매핑 요약으로 대체. 각 agent.md의 "내부 호출 스킬" 섹션을 자동/판단 구분으로 재구성. 유틸리티 스킬(note, learn, careful, freeze)과 스캐폴딩(new-api, new-page)은 직접 호출 유지.

**Tech Stack:** Markdown 파일 편집 (8개 파일)

---

### Task 1: CLAUDE.md — Skill Triggers → Skill Routing 대체

**Files:**
- Modify: `CLAUDE.md:135-175` (② Skill Triggers 섹션 전체)

**Step 1: CLAUDE.md의 Skill Triggers 섹션을 Skill Routing으로 교체**

줄 135-175의 기존 내용:
```markdown
### ② Skill Triggers (2순위)

**코어 워크플로우** (자동 트리거):
... (9줄 테이블)
**기술 스킬** ... (9줄 테이블)
**인프라/스캐폴딩** ... (7줄 테이블)
```

교체할 내용:
```markdown
### ② Skill Routing (2순위)

각 Agent가 Phase에 따라 스킬을 자동/판단 호출. 상세는 각 agent.md의 "내부 호출 스킬" 참조.

| Agent | 자동 호출 | 판단 호출 |
|-------|----------|----------|
| engineer | confidence-check, verify, checkpoint | fastapi, sqlalchemy, react-best-practices, web-design-guidelines, composition-patterns, testing, security-audit, new-api, new-page |
| reviewer | audit | python-best-practices, react-best-practices, security-audit, web-design-guidelines |
| debugger | build-fix, learn | — |
| planner | feature-planner, gap-analysis | — |
| architect | confidence-check | — |
| devops | — | docker, cicd, production-checklist |

**유틸리티** (Agent 거치지 않고 직접 호출):
`/note` · `/learn` · `/careful` · `/freeze`

**스캐폴딩** (직접 호출 겸용):
`/new-api` · `/new-page`
```

**Step 2: 커밋**

```bash
git add CLAUDE.md
git commit -m "refactor: Skill Triggers → Skill Routing 테이블 대체"
```

---

### Task 2: agents/engineer.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/engineer.md:189-193` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 189-193):
```markdown
## 내부 호출 스킬
- `/fastapi` — FastAPI 패턴, DTO, 미들웨어, 환경 설정
- `/sqlalchemy` — ORM, Alembic 마이그레이션
- `/react-best-practices` — React/Next.js 패턴
- `/testing` — 테스트 전략, conftest, 픽스처
```

교체:
```markdown
## 내부 호출 스킬

### 자동 호출 (Phase 고정)
| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/confidence-check` | 구현 시작 전 | 신뢰도 ≥90% 확인 후 진행 |
| `/verify` | 구현 완료 후 | 7단계 품질 검증 (lint, type, test, security) |
| `/checkpoint` | 리팩토링/삭제/마이그레이션 전 | git 롤백 포인트 생성 |

### 판단 호출 (상황 기반)
| 스킬 | 조건 | 용도 |
|------|------|------|
| `/fastapi` | pyproject.toml 존재 | FastAPI 패턴, DI, DTO, 미들웨어 |
| `/sqlalchemy` | pyproject.toml + DB 작업 | ORM, Alembic 마이그레이션 |
| `/react-best-practices` | package.json 존재 | React/Next.js 성능, Server Components |
| `/web-design-guidelines` | UI 컴포넌트 구현 시 | 접근성, 성능, UX 규칙 |
| `/composition-patterns` | 복합 컴포넌트 설계 시 | Compound Components, Provider 패턴 |
| `/testing` | 테스트 작성 시 | conftest, 유닛/통합 테스트 전략 |
| `/security-audit` | 인증/인가 구현 시 | JWT, RBAC, OWASP Top 10 |
| `/new-api` | FastAPI 엔드포인트 신규 생성 시 | CRUD 보일러플레이트 |
| `/new-page` | Next.js 페이지 신규 생성 시 | 페이지 보일러플레이트 |
```

**Step 2: 커밋**

```bash
git add agents/engineer.md
git commit -m "refactor: engineer 내부 호출 스킬 자동/판단 분리"
```

---

### Task 3: agents/reviewer.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/reviewer.md:215-218` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 215-218):
```markdown
## 내부 호출 스킬
- `/python-best-practices` — Python 코드 품질, 에러 핸들링
- `/react-best-practices` — React/Next.js 패턴, 접근성
- `/audit` — 커밋 전 프로젝트 규칙 검증
```

교체:
```markdown
## 내부 호출 스킬

### 자동 호출 (Phase 고정)
| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/audit` | 리뷰 완료 후 (커밋/PR 전) | 프로젝트 규칙 위반 검사 |

### 판단 호출 (상황 기반)
| 스킬 | 조건 | 용도 |
|------|------|------|
| `/python-best-practices` | Python 코드 리뷰 시 | 타입 힌트, 에러 핸들링, 코드 품질 |
| `/react-best-practices` | React/Next.js 코드 리뷰 시 | 성능, Server Components, 패턴 |
| `/security-audit` | 보안 관련 코드 리뷰 시 | JWT, RBAC, OWASP Top 10 |
| `/web-design-guidelines` | UI 접근성 리뷰 시 | WCAG, 포커스 관리, 성능 |
```

**Step 2: 커밋**

```bash
git add agents/reviewer.md
git commit -m "refactor: reviewer 내부 호출 스킬 자동/판단 분리"
```

---

### Task 4: agents/debugger.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/debugger.md:198-200` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 198-200):
```markdown
## 내부 호출 스킬
- `/build-fix` — 빌드/린트 에러 최소 변경 수정
- `/learn` — 디버깅 인사이트 영구 저장
```

교체:
```markdown
## 내부 호출 스킬

### 자동 호출 (Phase 고정)
| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/build-fix` | 빌드/린트 에러 발생 시 | 최소 변경으로 에러 자동 수정 |
| `/learn` | 문제 해결 완료 후 | 디버깅 인사이트 영구 저장 |
```

**Step 2: 커밋**

```bash
git add agents/debugger.md
git commit -m "refactor: debugger 내부 호출 스킬 자동 호출로 명시"
```

---

### Task 5: agents/planner.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/planner.md:187-192` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 187-192):
```markdown
## 내부 호출 스킬

| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/feature-planner` | Phase 4 (기능 3개+) | Phase 기반 구현 계획 수립 |
| `/gap-analysis` | Phase 4 완료 후 | 요구사항 대비 설계 커버리지 확인 |
```

교체:
```markdown
## 내부 호출 스킬

### 자동 호출 (Phase 고정)
| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/feature-planner` | Phase 4, 기능 3개 이상 시 | Phase 기반 구현 계획 수립 |
| `/gap-analysis` | Phase 4 스코프 잠금 후 | 요구사항 대비 설계 커버리지 확인 |
```

**Step 2: 커밋**

```bash
git add agents/planner.md
git commit -m "refactor: planner 내부 호출 스킬 자동 호출로 명시"
```

---

### Task 6: agents/architect.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/architect.md:254-258` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 254-258):
```markdown
## 내부 호출 스킬

| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/confidence-check` | 설계 완료 후, engineer 전달 전 | 설계 신뢰도 ≥90% 검증 |
```

교체:
```markdown
## 내부 호출 스킬

### 자동 호출 (Phase 고정)
| 스킬 | 호출 시점 | 용도 |
|------|----------|------|
| `/confidence-check` | 설계 완료 후, engineer 전달 전 | 설계 신뢰도 ≥90% 검증 |
```

**Step 2: 커밋**

```bash
git add agents/architect.md
git commit -m "refactor: architect 내부 호출 스킬 자동 호출로 명시"
```

---

### Task 7: agents/devops.md — 내부 호출 스킬 재구성

**Files:**
- Modify: `agents/devops.md:228-231` (내부 호출 스킬 섹션)

**Step 1: 기존 섹션 교체**

기존 (줄 228-231):
```markdown
## 내부 호출 스킬
- `/docker` — Dockerfile, docker-compose 코드
- `/cicd` — GitHub Actions YAML
- `/production-checklist` — 배포 전 최종 점검
```

교체:
```markdown
## 내부 호출 스킬

### 판단 호출 (상황 기반)
| 스킬 | 조건 | 용도 |
|------|------|------|
| `/docker` | Docker 관련 작업 시 | Dockerfile, docker-compose 구성 |
| `/cicd` | CI/CD 파이프라인 구성 시 | GitHub Actions YAML |
| `/production-checklist` | 배포 전 최종 점검 시 | 모니터링, 알림, 헬스체크 |
```

**Step 2: 커밋**

```bash
git add agents/devops.md
git commit -m "refactor: devops 내부 호출 스킬 판단 호출로 명시"
```

---

### Task 8: README.md — Skills 섹션 Agent 매핑으로 대체

**Files:**
- Modify: `README.md:175-215` (Skills 섹션 전체)

**Step 1: 기존 Skills 섹션 교체**

기존 (줄 175-215): 3개 테이블 (코어/기술/인프라)

교체:
```markdown
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
```

**Step 2: 커밋**

```bash
git add README.md
git commit -m "docs: README Skills 섹션 Agent 매핑으로 대체"
```

---

### Task 9: 글로벌 CLAUDE.md 동기화 및 최종 검증

**Files:**
- Verify: `~/.claude/CLAUDE.md` (글로벌 설정과 프로젝트 CLAUDE.md 일치 확인)

**Step 1: 프로젝트 CLAUDE.md와 글로벌 CLAUDE.md 비교**

```bash
diff CLAUDE.md ~/.claude/CLAUDE.md
```

**Step 2: 차이가 있으면 글로벌도 동기화**

```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
```

**Step 3: 최종 커밋 및 푸시**

```bash
git push
```
