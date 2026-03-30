---
name: freeze
description: |
  특정 디렉토리만 수정 허용하여 디버깅 시 실수로 다른 코드를 수정하는 것을 방지합니다.
  허용 디렉토리 외의 파일 수정(Edit/Write)을 차단합니다.
  Use when: 디버깅, 특정 디렉토리만 수정, 실수 방지.
  NOT for: 일반 개발, 새 기능 구현.
hooks:
  - type: PreToolUse
    matcher: Edit|Write
    hook:
      type: command
      command: "bash ${SKILL_DIR}/freeze-guard.sh"
      timeout: 3000
---

# Freeze Mode

특정 디렉토리만 수정 허용. 디버깅 시 실수 방지.

## 사용법

1. `/freeze` 호출 → 허용 디렉토리 질문 → `config.json`에 저장
2. 이후 허용 디렉토리 밖 파일 수정 시 자동 차단
3. `/freeze --off` 또는 세션 종료 시 해제 (`config.json` 삭제)

## config.json 예시

```json
{
  "allowed_dirs": [
    "/Users/jungmin/project/src/auth/",
    "/Users/jungmin/project/tests/auth/"
  ]
}
```

> 절대 경로 필수. 상대 경로는 작업 디렉토리 변경 시 깨질 수 있음.

## 동작 방식

- `config.json` 없음 → 허용 디렉토리 설정 요청
- 허용 디렉토리 내 → 허용 (exit 0)
- 허용 디렉토리 밖 → 차단 (exit 2)

## 실수 복구

freeze 차단 발동 시 실제 파일 미수정이므로 복구 불필요. 만약 허용 범위 밖 수정 발생 시:
1. 즉시 중단
2. `git diff`로 변경 확인
3. `git checkout -- <파일>` 또는 `git restore -p <파일>`로 복구
4. `/freeze` 상태 재확인

## 세션 종료 시

- 세션 종료 시 freeze 해제, 단 `config.json`은 잔존 가능
- 다음 세션에서 불필요 시 `/freeze --off` 또는 `config.json` 삭제할 것
- 영구 보호 필요 시 chmod 또는 git hook 사용
