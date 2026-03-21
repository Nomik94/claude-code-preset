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

## 프로덕션 환경 판별 기준

다음 상황에서 `/careful` 모드를 활성화해야 한다:

| 상황 | 판별 기준 |
|------|----------|
| SSH 원격 접속 | `ssh`, `scp`, 원격 호스트 키워드 포함 |
| 프로덕션 DB 작업 | `prod`, `production`, `live` 환경 변수 또는 DB URL |
| 클라우드 인프라 조작 | AWS, GCP, Azure CLI 명령 실행 |
| 쿠버네티스 클러스터 조작 | `kubectl`, `helm` 명령 실행 |
| CI/CD 파이프라인 실행 | 배포 스크립트, 릴리즈 태그 작업 |

SSH 접속 또는 `prod` 키워드 감지 시 Claude는 `/careful` 활성화를 자동으로 제안해야 한다.

## 차단 우회 확인 절차

차단된 명령이 정말 필요한 경우 다음 프로세스를 따른다:

1. **차단 발생**: guard.sh가 위험 명령을 감지하고 stderr에 차단 사유 출력
2. **사용자 확인 요청**: Claude가 사용자에게 명령의 목적과 위험성을 설명
3. **명시적 승인**: 사용자가 "확인", "진행", "yes" 등 명시적 동의 입력
4. **단일 실행**: 승인은 해당 명령 1회에만 적용. careful 모드는 유지됨
5. **재차단**: 다음 위험 명령에서 다시 차단 절차 시작

> 주의: "그냥 해", "알아서 해" 같은 모호한 표현은 승인으로 간주하지 않는다.

## 차단 로그

차단된 명령은 stderr로 출력된다. 형식:

```
[careful] BLOCKED: rm -rf /data — 재귀 삭제는 차단됩니다.
[careful] 이 명령을 실행하려면 사용자 확인이 필요합니다.
```

- stdout은 오염하지 않아 파이프라인 동작에 영향 없음
- 차단 기록은 세션 로그에서 확인 가능
- exit code 2로 종료하여 훅 시스템이 명령 실행을 중단
