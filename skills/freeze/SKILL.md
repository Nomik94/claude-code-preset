---
name: freeze
description: |
  특정 디렉토리만 수정 허용하여 디버깅 시 실수로 다른 코드를 수정하는 것을 방지합니다.
  허용 디렉토리 외의 파일 수정(Edit/Write)을 차단합니다.
hooks:
  - type: PreToolUse
    matcher: Edit|Write
    hook:
      type: command
      command: "bash ${SKILL_DIR}/freeze-guard.sh"
      timeout: 3000
---

# Freeze Mode

특정 디렉토리만 수정 허용. 디버깅 시 실수로 다른 코드를 수정하는 것을 방지합니다.

## 사용법

1. `/freeze` 호출
2. Claude가 허용할 디렉토리를 질문
3. 답변한 디렉토리가 `config.json`에 저장됨
4. 이후 허용 디렉토리 밖의 파일 수정 시 자동 차단

## 해제
- `/freeze --off` 입력 시 해제 (`config.json` 삭제)
- 세션 종료 시 자동 해제

## config.json 예시

```json
{
  "allowed_dirs": ["src/auth/", "tests/auth/"]
}
```

## 동작 방식
- `config.json`이 없으면 → 사용자에게 허용 디렉토리 설정 요청 메시지 출력
- 수정 대상 파일이 허용 디렉토리 내 → 허용 (exit 0)
- 수정 대상 파일이 허용 디렉토리 밖 → 차단 (exit 2)
