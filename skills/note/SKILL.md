---
name: note
description: 컴팩션에서 살아남는 영구 메모 시스템. 긴 세션에서 중요 컨텍스트 손실 방지.
  Use when: /note 명령어, 기억해, remember, 메모, 저장해둬, context save.
  NOT for: 일반 코드 작성, 파일 생성.
---

# Note 스킬

컴팩션에서 살아남는 영구 메모 시스템.

**핵심**: 중요 정보 → 메모 저장 → 컴팩션 후에도 유지 → 다음 세션에서도 사용 가능

## 저장 위치
- **프로젝트 레벨**: `.claude/notepad.md` (프로젝트 루트)
- **글로벌 레벨**: `~/.claude/notepad.md` (프로젝트 간 공유)

## 명령어

| 명령어 | 설명 |
|--------|------|
| `/note <content>` | Working Memory에 타임스탬프와 함께 추가 |
| `/note --priority <content>` | Priority Context에 추가 (항상 로드) |
| `/note --manual <content>` | MANUAL 섹션에 추가 (절대 삭제 안 됨) |
| `/note --show` | 현재 notepad 내용 표시 |
| `/note --prune` | 7일 이상 된 Working Memory 항목 정리 |
| `/note --clear` | Working Memory만 삭제 (Priority, MANUAL 유지) |

## 섹션

### 1. Priority Context (항상 로드)
```markdown
## Priority Context
<!-- 500자 제한 - 세션 시작 시 항상 로드 -->
- Poetry 필수, pip 금지
- API 패턴: /{client}/v{version}/{domain}/{action}
- Auth: PyJWT + pwdlib
```
- 프로젝트 핵심 정보만 간결하게
- **500자 제한** (컨텍스트 예산 고려)

### 2. Working Memory (임시 메모)
```markdown
## Working Memory
<!-- 타임스탬프 포함, 7일 후 자동 정리 -->
[2026-02-26 14:30] auth.py:45 race condition 발견 - await 누락
[2026-02-26 15:45] RLS policy 이슈 해결 - service_role key 사용
```
- 디버깅 중 발견한 사항, 현재 작업 내용
- **파일명:라인번호** 포함 권장

### 3. MANUAL (영구 저장)
```markdown
## MANUAL
<!-- 영구 저장 - 절대 자동 삭제 안 됨 -->
- Production DB: readonly, 직접 수정 금지
- Deploy: main branch push → auto-deploy
```
- 팀 정보, 배포 규칙, 영구 규칙

## Notepad 템플릿

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

## 구현

1. **인자 파싱**: --priority, --manual, --show, --prune, --clear 확인
2. **Notepad 로드/생성**: `.claude/notepad.md` 읽기 또는 생성
3. **동작 실행**:
   - 기본: Working Memory에 `[YYYY-MM-DD HH:MM]` 타임스탬프와 함께 추가
   - `--priority`: Priority Context에 추가 (500자 초과 시 경고)
   - `--manual`: MANUAL 섹션에 추가
   - `--show`: 전체 내용 표시
   - `--prune`: 7일+ Working Memory 항목 삭제
4. **저장**: 변경사항 저장

## 자동 제안 트리거

| 상황 | 행동 |
|------|------|
| 세션 메시지 50+ | "중요 정보를 /note로 저장하세요" 제안 |
| 컨텍스트 70%+ | Priority Context 저장 제안 |
| 복잡한 문제 해결 후 | Working Memory 저장 제안 |
| 세션 종료 전 | 미완료 작업 상태 저장 제안 |

## 베스트 프랙티스

```markdown
✅ Good (구체적, 파일/라인 포함)
[2026-02-26] auth.py:89 await 누락으로 race condition - asyncio.gather 사용

❌ Bad (모호)
[2026-02-26] 버그 발견
```
