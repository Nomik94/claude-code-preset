---
name: careful
description: |
  프로덕션 환경 작업 시 위험 명령을 자동 차단합니다.
  rm -rf, DROP TABLE, git push --force 등 파괴적 명령을 감지하고 블록합니다.
  Use when: 프로덕션 작업, 위험 명령 실행 환경, rm -rf, DROP TABLE.
  NOT for: 개발 환경 일반 작업, 테스트 환경.
hooks:
  - type: PreToolUse
    matcher: Bash
    hook:
      type: command
      command: "bash ${SKILL_DIR}/guard.sh"
      timeout: 3000
---

# Careful Mode

프로덕션 환경 위험 명령 자동 차단.

## pre-tool-use-safety.sh와의 차이
- `pre-tool-use-safety.sh`: 항상 활성, `rm -rf /`/`DROP TABLE`/`git push --force` 등 핵심만 차단
- `/careful`: 프로덕션 강화 모드, `kubectl delete`/`docker system prune`/`terraform destroy` 등 추가 차단

## 차단 대상

| 명령 | 이유 |
|------|------|
| `rm -rf` | 재귀 삭제 |
| `DROP TABLE/DATABASE` | DB 파괴 |
| `git push --force` | 히스토리 덮어쓰기 |
| `git reset --hard` | 작업 손실 |
| `kubectl delete` | 인프라 삭제 |
| `docker system prune` | 전체 정리 |

## 사용법
`/careful` 호출 시 세션 동안 활성. 차단 우회 시 사용자 명시적 확인 필요.

## 프로덕션 판별 기준

| 상황 | 기준 |
|------|------|
| SSH 원격 접속 | `ssh`, `scp`, 원격 호스트 키워드 |
| 프로덕션 DB | `prod`, `production`, `live` 환경변수/DB URL |
| 클라우드 인프라 | AWS/GCP/Azure CLI |
| 쿠버네티스 | `kubectl`, `helm` |
| CI/CD | 배포 스크립트, 릴리즈 태그 |

SSH/`prod` 감지 시 `/careful` 활성화 자동 제안.

## 차단 우회 절차
1. guard.sh가 감지 → stderr에 차단 사유 출력
2. Claude가 목적/위험성 설명
3. 사용자 명시적 승인 ("확인", "진행", "yes")
4. 해당 명령 1회만 적용, careful 유지
5. 다음 위험 명령에서 재차단

> "그냥 해", "알아서 해" 등 모호한 표현은 승인 불가.

## 차단 로그

```
[careful] BLOCKED: rm -rf /data — 재귀 삭제는 차단됩니다.
[careful] 이 명령을 실행하려면 사용자 확인이 필요합니다.
```

- stdout 미오염 (파이프라인 안전)
- exit code 2로 훅 시스템이 실행 중단
