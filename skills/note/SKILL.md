---
name: note
description: |
  컴팩션에서 살아남는 영구 메모 시스템. 긴 세션에서 중요 컨텍스트 손실 방지.
  Use when: /note 명령어, 기억해, remember, 메모, 저장해둬, context save.
  NOT for: 일반 코드 작성, 파일 생성.
---

# Note

컴팩션에서 살아남는 영구 메모 시스템.

**핵심**: 중요 정보 → 메모 저장 → 컴팩션 후에도 유지 → 다음 세션에서도 사용 가능

## 저장 위치

| 레벨 | 경로 | 용도 |
|------|------|------|
| 프로젝트 | `.claude/notepad.md` | 프로젝트별 메모 |
| 글로벌 | `~/.claude/notepad.md` | 프로젝트 간 공유 |

## 명령어

| 명령어 | 동작 |
|--------|------|
| `/note <content>` | Working Memory에 타임스탬프와 함께 추가 |
| `/note --priority <content>` | Priority Context에 추가 (항상 로드, 500자 제한) |
| `/note --manual <content>` | MANUAL 섹션에 추가 (영구 저장, 자동 삭제 안 됨) |
| `/note --show` | 현재 notepad 전체 내용 표시 |
| `/note --prune` | 7일 이상 된 Working Memory 항목 정리 |
| `/note --clear` | Working Memory만 삭제 (Priority, MANUAL 유지) |

## 3단계 섹션

### 1. Priority Context (항상 로드)

```markdown
## Priority Context
<!-- 500자 제한 - 세션 시작 시 항상 로드 -->
- Poetry 필수, pip 금지 / pnpm 필수, npm 금지
- BE: controllers → service → repository
- FE: Server Components 기본, 'use client' 최소화
```

- 프로젝트 핵심 정보만 간결하게
- **500자 제한** (컨텍스트 예산 고려)
- 초과 시 경고 메시지 출력

### 2. Working Memory (임시 메모)

```markdown
## Working Memory
<!-- 타임스탬프 포함, 7일 후 자동 정리 -->
[2026-03-21 14:30] auth.py:45 race condition 발견 - await 누락
[2026-03-21 15:45] UserForm.tsx hydration mismatch - useEffect로 해결
```

- 디버깅 중 발견한 사항, 현재 작업 내용
- **파일명:라인번호** 포함 권장
- 7일 후 `/note --prune`으로 정리

### 3. MANUAL (영구 저장)

```markdown
## MANUAL
<!-- 영구 저장 - 절대 자동 삭제 안 됨 -->
- Production DB: readonly, 직접 수정 금지
- Deploy: main branch push → auto-deploy
- FE 배포: Vercel, 환경변수는 대시보드에서 관리
```

- 팀 정보, 배포 규칙, 영구 규칙
- 자동 삭제 대상 아님

## Notepad 템플릿

파일: `templates/notepad.md`

```markdown
# Notepad
<!-- 컴팩션에서 살아남는 세션 메모 -->

## Priority Context
<!-- 500자 제한 - 항상 로드 -->


## Working Memory
<!-- 타임스탬프 포함, 7일 후 /note --prune으로 정리 -->


## MANUAL
<!-- 영구 저장 - 절대 자동 삭제 안 됨 -->

```

## 구현 절차

1. **인자 파싱**: --priority, --manual, --show, --prune, --clear 확인
2. **Notepad 로드/생성**: `.claude/notepad.md` 읽기 또는 템플릿으로 생성
3. **동작 실행**:
   - 기본: Working Memory에 `[YYYY-MM-DD HH:MM]` 타임스탬프와 함께 추가
   - `--priority`: Priority Context에 추가 (500자 초과 시 경고)
   - `--manual`: MANUAL 섹션에 추가
   - `--show`: 전체 내용 표시
   - `--prune`: 7일+ Working Memory 항목 삭제
   - `--clear`: Working Memory 전체 삭제
4. **저장**: 변경사항 파일에 기록

## 자동 제안 트리거

| 상황 | 행동 |
|------|------|
| 세션 메시지 50+ | "중요 정보를 /note로 저장하세요" 제안 |
| 컨텍스트 70%+ | Priority Context 저장 제안 |
| 복잡한 문제 해결 후 | Working Memory 저장 제안 |
| 세션 종료 전 | 미완료 작업 상태 저장 제안 |

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
