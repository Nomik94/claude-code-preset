---
name: note
description: |
  영구 메모 시스템. 세션 간 정보 전달 및 영구 규칙 저장.
  Use when: /note 명령어, 기억해, remember, 메모, 저장해둬.
  NOT for: 일반 코드 작성, 파일 생성.
---

# Note

세션 간 정보 전달 영구 메모 시스템.

## 저장 위치

| 레벨 | 경로 | 용도 |
|------|------|------|
| 프로젝트 | `.claude/notepad.md` | 프로젝트별 메모 |
| 글로벌 | `~/.claude/notepad.md` | 프로젝트 간 공유 |

## 명령어

| 명령어 | 동작 |
|--------|------|
| `/note <content>` | Working Memory에 타임스탬프와 함께 추가 |
| `/note --manual <content>` | MANUAL 섹션에 영구 추가 |
| `/note --show` | notepad 전체 표시 |
| `/note --prune` | 7일+ Working Memory 정리 |

## 섹션

### Working Memory (임시)

```markdown
## Working Memory
[2026-03-21 14:30] auth.py:45 race condition 발견 - await 누락
```

- 디버깅 발견 사항, 현재 작업 메모. **파일명:라인번호** 포함 권장.

### MANUAL (영구)

```markdown
## MANUAL
- Production DB: readonly, 직접 수정 금지
- Deploy: main push → auto-deploy
```

- 팀 정보, 배포 규칙 등. 자동 삭제 대상 아님.

## 구현 절차

1. 인자 파싱: --manual, --show, --prune 확인
2. `.claude/notepad.md` 로드 또는 템플릿 생성
3. 동작 실행 (기본: Working Memory에 `[YYYY-MM-DD HH:MM]` 추가)
4. 저장

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
