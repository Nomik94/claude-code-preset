# Full Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 에이전트/훅/스킬 전체에서 중복 제거, 성능 최적화, 콘텐츠 보강을 수행하여 ~1,370줄을 절약한다.

**Architecture:** 3단계로 진행: ① 에이전트 중복 제거 (스킬 위임 패턴 적용), ② 훅 dispatcher 통합 (4개→1개 + common.sh), ③ 스킬 코드 인라인→references 분리 + 중복 제거. 각 단계 끝에 커밋.

**Tech Stack:** Markdown editing, Bash scripting

---

## Phase 1: 에이전트 최적화 (~190줄 절약)

### Task 1: 6개 에이전트에서 Stack Detection 제거

CLAUDE.md Worker prompt에 `STACK: {detected_stack}`이 이미 전달되므로, 각 에이전트의 Stack Detection 섹션을 1줄 참조로 대체.

**Files:**
- Modify: `agents/architect.md:13-22`
- Modify: `agents/engineer.md:12-19`
- Modify: `agents/reviewer.md:13-19`
- Modify: `agents/debugger.md:13-20`
- Modify: `agents/devops.md:15-20`

**Step 1:** 각 에이전트의 `## Stack Detection` 또는 유사 섹션을 찾아서 다음 1줄로 대체:
```markdown
> Stack Detection은 orchestrator가 `STACK: {detected_stack}` 컨텍스트로 전달. CLAUDE.md 참조.
```

planner.md와 writer.md에는 Stack Detection이 없으므로 변경 불필요.

**Step 2:** 커밋
```bash
git add agents/*.md
git commit -m "refactor: 6개 에이전트에서 Stack Detection 중복 제거"
```

---

### Task 2: engineer.md에서 architect/스킬과 중복되는 설계 판단 섹션 제거

**Files:**
- Modify: `agents/engineer.md`

**Step 1:** 다음 섹션들을 스킬 참조 1줄로 대체:

| 제거 대상 | 대체 |
|-----------|------|
| 설계 판단 기준 > 도메인 레이어 도입 여부 (~9줄) | "도메인 레이어 도입 판단은 architect 설계를 따름" |
| 설계 판단 기준 > DI 패턴 선택 (~7줄) | "DI 패턴은 `/fastapi` 스킬 참조" |
| 설계 판단 기준 > 캐싱 전략 (~6줄) | "캐싱 전략은 architect 설계를 따름" |
| 레이어 책임 원칙 테이블 (~9줄) | "레이어 책임은 `/fastapi` 스킬 참조" |
| 품질 검증 BE/FE 섹션 (~15줄) | "구현 완료 후 `/verify` 스킬 자동 실행" |

**Step 2:** 도메인 레이어 기준 불일치 수정 — architect "3개+" vs engineer "2개+". architect의 "3개+"를 정본으로 채택.

**Step 3:** 커밋
```bash
git add agents/engineer.md
git commit -m "refactor: engineer에서 architect/스킬과 중복 제거, 도메인 레이어 기준 통일"
```

---

### Task 3: architect.md에서 스킬과 중복되는 상세 제거

**Files:**
- Modify: `agents/architect.md`

**Step 1:** 다음 섹션들을 스킬 참조로 축소:

| 제거 대상 | 대체 |
|-----------|------|
| 캐싱 전략 테이블 (~8줄) | 제거 (architect에서 설계 결정만, 상세는 구현 시 engineer/fastapi가 처리) |
| FE Phase 3의 상태관리/API통합/디자인시스템 상세 (~30줄) | 설계 결정 포인트만 유지, 상세는 "`/react-best-practices` 스킬 참조" |
| 경계 규칙 테이블 (~10줄) | Behavioral Mindset 첫 단락에 핵심만 통합 |

**Step 2:** 커밋
```bash
git add agents/architect.md
git commit -m "refactor: architect에서 스킬 중복 제거, 경계 규칙 통합"
```

---

### Task 4: reviewer.md에서 스킬과 중복되는 체크리스트 축소

**Files:**
- Modify: `agents/reviewer.md`

**Step 1:** BE/FE 리뷰 체크리스트(~28줄)를 스킬 참조로 축소:
```markdown
### BE 리뷰 체크리스트
> 상세는 `/fastapi`, `/python-best-practices` 스킬의 체크리스트 참조.
- [ ] 도메인 규칙이 Entity에 캡슐화 되었는가?
- [ ] N+1 쿼리 패턴이 없는가?
(reviewer 고유 관점 5개만 유지)
```

FE도 동일하게 `/react-best-practices` 참조 + reviewer 고유 관점만 유지.

**Step 2:** 커밋
```bash
git add agents/reviewer.md
git commit -m "refactor: reviewer 체크리스트 스킬 위임, 고유 관점만 유지"
```

---

### Task 5: planner.md 경계 규칙 축소

**Files:**
- Modify: `agents/planner.md`

**Step 1:** 경계 규칙 테이블(~12줄)에서 Behavioral Mindset에 이미 있는 내용 제거. 고유한 2-3줄만 유지.

**Step 2:** 커밋
```bash
git add agents/planner.md
git commit -m "refactor: planner 경계 규칙 축소"
```

---

## Phase 2: 훅 최적화 (~100줄 절약 + 성능)

### Task 6: PostToolUse 4개 훅 → 1개 dispatcher 통합

**Files:**
- Create: `hooks/common.sh` (공통 유틸 함수)
- Create: `hooks/post-tool-use.sh` (dispatcher)
- Delete: `hooks/auto-format.sh`
- Delete: `hooks/type-check.sh`
- Delete: `hooks/console-log-check.sh`
- Delete: `hooks/convention-check.sh`

**Step 1:** `hooks/common.sh` 작성 — 공통 유틸:
```bash
# 파일 경로 유효성 검사
validate_file_path() { ... }
# 스킵 디렉토리 판단 (통일된 목록)
should_skip_dir() { ... }
# 테스트/config 파일 판단
should_skip_test() { ... }
# 상위 디렉토리 탐색
find_up() { ... }
# 주석 줄 판단
is_comment_line() { ... }
```

**Step 2:** `hooks/post-tool-use.sh` 작성 — dispatcher:
```bash
#!/bin/bash
source "$(dirname "$0")/common.sh"

FILE_PATH="${CLAUDE_FILE_PATH:-}"
validate_file_path "$FILE_PATH" || exit 0
should_skip_dir "$FILE_PATH" && exit 0

EXT="${FILE_PATH##*.}"

# 확장자 기반으로 필요한 검사만 실행
case "$EXT" in
  py)
    run_format_python "$FILE_PATH"
    run_convention_check_python "$FILE_PATH"
    run_debug_check_python "$FILE_PATH"
    ;;
  ts|tsx)
    run_format_web "$FILE_PATH"
    run_convention_check_js "$FILE_PATH"
    run_debug_check_js "$FILE_PATH"
    run_type_check "$FILE_PATH"
    ;;
  # ...
esac
```

**Step 3:** 기존 4개 훅의 핵심 로직을 함수로 추출하여 post-tool-use.sh 내에 배치.

**Step 4:** type-check에 throttle 추가 (마지막 실행 후 10초 이내 재실행 건너뜀).

**Step 5:** `npx prettier` → `./node_modules/.bin/prettier`, `npx tsc` → `./node_modules/.bin/tsc` 직접 호출로 변경.

**Step 6:** auto-format.sh의 `cat` 전체 파일 → `md5 -q` 해시 비교로 변경.

**Step 7:** console-log-check의 2중 파일 순회를 1회로 통합.

**Step 8:** install.sh의 hooks 등록 로직 업데이트 (4개 → 1개 + common.sh).

**Step 9:** uninstall.sh의 hooks 리스트 업데이트.

**Step 10:** 커밋
```bash
git add hooks/ install.sh uninstall.sh
git commit -m "refactor: PostToolUse 4개 훅 → 1개 dispatcher 통합"
```

---

## Phase 3: 스킬 최적화 (~1,080줄 절약)

### Task 7: 스킬 전반 중복 제거 (Stack Detection, Pydantic, lazy, 보안)

**Files:**
- Modify: `skills/verify/SKILL.md`
- Modify: `skills/confidence-check/SKILL.md`
- Modify: `skills/production-checklist/SKILL.md`
- Modify: `skills/cicd/SKILL.md`
- Modify: `skills/docker/SKILL.md`
- Modify: `skills/build-fix/SKILL.md`
- Modify: `skills/fastapi/SKILL.md`
- Modify: `skills/new-api/SKILL.md`
- Modify: `skills/sqlalchemy/SKILL.md`
- Modify: `skills/audit/SKILL.md`
- Modify: `skills/python-best-practices/SKILL.md`

**Step 1:** 6개 스킬의 Stack Detection 블록을 1줄로 축소:
```markdown
> Stack Detection: CLAUDE.md 규칙에 따라 자동 결정됨.
```

**Step 2:** Pydantic v2 중복 제거 — python-best-practices를 정본으로, fastapi/new-api에서는 "Pydantic 상세는 `/python-best-practices` 참조"로.

**Step 3:** lazy="raise" 중복 제거 — sqlalchemy를 정본으로, 나머지에서 참조.

**Step 4:** 보안 체크리스트 — security-audit를 정본으로, python-best-practices/production-checklist/audit/verify에서 "보안 상세는 `/security-audit` 참조"로.

**Step 5:** 커밋
```bash
git add skills/*/SKILL.md
git commit -m "refactor: 스킬 전반 중복 제거 (Stack Detection, Pydantic, lazy, 보안)"
```

---

### Task 8: python-best-practices gotchas.md 정리

**Files:**
- Modify: `skills/python-best-practices/gotchas.md`

**Step 1:** SKILL.md Modern Python Syntax 테이블과 동일한 6개 항목(Optional, slots, List/Dict, Sequence, StrEnum, Self) 제거. SKILL.md에서 다루지 않는 런타임 함정만 유지.

**Step 2:** 커밋
```bash
git add skills/python-best-practices/gotchas.md
git commit -m "refactor: python-best-practices gotchas 중복 6개 제거"
```

---

### Task 9: webapp-testing 코드 템플릿 → references/ 분리

**Files:**
- Modify: `skills/webapp-testing/SKILL.md` (568줄 → ~150줄)
- Create: `skills/webapp-testing/references/test-templates.md`
- Create: `skills/webapp-testing/references/screenshot-testing.md`
- Modify: `skills/webapp-testing/scripts/with_server.py` (SKILL.md 인라인 코드와 통합)

**Step 1:** SKILL.md에서 4개 코드 템플릿(~200줄)과 with_server.py 인라인 구현(~80줄)을 references/로 이동.
**Step 2:** SKILL.md는 원칙 + 의사결정 트리 + 체크리스트만 유지.
**Step 3:** scripts/with_server.py와 SKILL.md 인라인 구현 불일치 해소.

**Step 4:** 커밋
```bash
git add skills/webapp-testing/
git commit -m "refactor: webapp-testing 코드 템플릿 references/ 분리 (568→~150줄)"
```

---

### Task 10: docker SKILL.md → templates/ 이동

**Files:**
- Modify: `skills/docker/SKILL.md` (428줄 → ~100줄)
- Verify: `skills/docker/templates/` (기존 Dockerfile.be, Dockerfile.fe, docker-compose.yml 확인)
- Create: `skills/docker/references/nginx-config.md`
- Create: `skills/docker/references/compose-patterns.md`

**Step 1:** SKILL.md 내 nginx 설정(~60줄)과 docker-compose override 패턴(~60줄)을 references/로 분리.
**Step 2:** templates/ 디렉토리의 기존 파일과 SKILL.md 인라인 코드 동기화 확인.
**Step 3:** SKILL.md는 핵심 원칙 + 체크리스트 + templates/references 참조만 유지.

**Step 4:** 커밋
```bash
git add skills/docker/
git commit -m "refactor: docker 코드 templates/references 분리 (428→~100줄)"
```

---

### Task 11: cicd YAML → references/ 분리

**Files:**
- Modify: `skills/cicd/SKILL.md` (463줄 → ~150줄)
- Create: `skills/cicd/references/pipeline-examples.md`
- Create: `skills/cicd/references/deployment-strategies.md`

**Step 1:** Vercel/Cloudflare 배포, Matrix Strategy, Lighthouse CI YAML을 references/로 분리.
**Step 2:** SKILL.md는 핵심 파이프라인 구조 + Quality Gates + 체크리스트만 유지.

**Step 3:** 커밋
```bash
git add skills/cicd/
git commit -m "refactor: cicd YAML references/ 분리 (463→~150줄)"
```

---

### Task 12: fastapi/sqlalchemy gotchas.md SKILL.md 중복 정리

**Files:**
- Modify: `skills/fastapi/gotchas.md`
- Modify: `skills/sqlalchemy/gotchas.md`

**Step 1:** fastapi gotchas에서 SKILL.md와 동일한 4개 항목(#3 lazy, #4 Pydantic, #6 미들웨어, #7 EndpointPath) 제거. 실제 런타임 함정만 유지.

**Step 2:** sqlalchemy gotchas에서 SKILL.md와 동일한 2개 항목(#3 lazy, #6 expire_on_commit) 제거.

**Step 3:** 커밋
```bash
git add skills/fastapi/gotchas.md skills/sqlalchemy/gotchas.md
git commit -m "refactor: fastapi/sqlalchemy gotchas SKILL.md 중복 제거"
```

---

### Task 13: careful/freeze 스킬 보강

**Files:**
- Modify: `skills/careful/SKILL.md` (31줄 → ~60줄)
- Create: `skills/careful/gotchas.md`
- Modify: `skills/freeze/SKILL.md` (41줄 → ~65줄)
- Create: `skills/freeze/gotchas.md`

**Step 1:** careful 보강 — 차단 우회 확인 절차, 프로덕션 환경 판별, 차단 로그 확인 방법.
**Step 2:** freeze 보강 — 다중 디렉토리 설정 예시, 실수 복구 방법.
**Step 3:** 각각 gotchas.md 생성 (빈출 실수 패턴 3-4개).

**Step 4:** 커밋
```bash
git add skills/careful/ skills/freeze/
git commit -m "feat: careful/freeze 스킬 보강 + gotchas 추가"
```

---

## Phase 4: 문서 동기화

### Task 14: README.md 업데이트 + 글로벌 CLAUDE.md 동기화

**Files:**
- Modify: `README.md` (Summary 테이블 줄 수 업데이트)
- Copy: `CLAUDE.md` → `~/.claude/CLAUDE.md`

**Step 1:** README Summary 테이블의 줄 수/파일 수 정정.
**Step 2:** 글로벌 CLAUDE.md 동기화.

**Step 3:** 커밋 및 푸시
```bash
git add README.md
git commit -m "docs: README 통계 업데이트"
git push
```
