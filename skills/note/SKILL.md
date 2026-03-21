---
name: note
description: |
  영구 메모 시스템. 세션 간 정보 전달 및 영구 규칙 저장.
  Use when: /note 명령어, 기억해, remember, 메모, 저장해둬.
  NOT for: 일반 코드 작성, 파일 생성.
---

# Note

세션 간 정보를 전달하는 영구 메모 시스템.

## 저장 위치

| 레벨 | 경로 | 용도 |
|------|------|------|
| 프로젝트 | `.claude/notepad.md` | 프로젝트별 메모 |
| 글로벌 | `~/.claude/notepad.md` | 프로젝트 간 공유 |

## 명령어

| 명령어 | 동작 |
|--------|------|
| `/note <content>` | Working Memory에 타임스탬프와 함께 추가 |
| `/note --manual <content>` | MANUAL 섹션에 추가 (영구 저장) |
| `/note --show` | 현재 notepad 전체 내용 표시 |
| `/note --prune` | 7일 이상 된 Working Memory 항목 정리 |

## 2단계 섹션

### 1. Working Memory (임시 메모)

```markdown
## Working Memory
[2026-03-21 14:30] auth.py:45 race condition 발견 - await 누락
[2026-03-21 15:45] UserForm.tsx hydration mismatch - useEffect로 해결
```

- 디버깅 중 발견한 사항, 현재 작업 메모
- **파일명:라인번호** 포함 권장
- 7일 후 `/note --prune`으로 정리

### 2. MANUAL (영구 저장)

```markdown
## MANUAL
- Production DB: readonly, 직접 수정 금지
- Deploy: main branch push → auto-deploy
- FE 배포: Vercel, 환경변수는 대시보드에서 관리
```

- 팀 정보, 배포 규칙, 영구 규칙
- 자동 삭제 대상 아님

## 구현 절차

1. **인자 파싱**: --manual, --show, --prune 확인
2. **Notepad 로드/생성**: `.claude/notepad.md` 읽기 또는 템플릿으로 생성
3. **동작 실행**:
   - 기본: Working Memory에 `[YYYY-MM-DD HH:MM]` 타임스탬프와 함께 추가
   - `--manual`: MANUAL 섹션에 추가
   - `--show`: 전체 내용 표시
   - `--prune`: 7일+ Working Memory 항목 삭제
4. **저장**: 변경사항 파일에 기록

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
