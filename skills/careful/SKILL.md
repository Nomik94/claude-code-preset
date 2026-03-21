---
name: careful
description: |
  프로덕션 환경 작업 시 위험 명령을 자동 차단합니다.
  rm -rf, DROP TABLE, git push --force 등 파괴적 명령을 감지하고 블록합니다.
hooks:
  - type: PreToolUse
    matcher: Bash
    hook:
      type: command
      command: "bash ${SKILL_DIR}/guard.sh"
      timeout: 3000
---

# Careful Mode

프로덕션 환경 작업 시 위험 명령을 자동 차단합니다.

## 차단 대상
| 명령 | 이유 |
|------|------|
| `rm -rf` | 재귀 삭제 |
| `DROP TABLE/DATABASE` | DB 파괴 |
| `git push --force` | 히스토리 덮어쓰기 |
| `git reset --hard` | 작업 손실 |
| `kubectl delete` | 인프라 리소스 삭제 |
| `docker system prune` | 전체 정리 |

## 사용법
`/careful` 호출 시 세션 동안 활성화. 차단된 명령 실행 시 경고 후 블록.
차단을 우회하려면 사용자가 명시적으로 확인해야 함.
