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

## 다중 디렉토리 설정

여러 디렉토리를 동시에 허용할 수 있다. `config.json`에 배열로 나열:

```json
{
  "allowed_dirs": [
    "/Users/jungmin/project/src/auth/",
    "/Users/jungmin/project/tests/auth/",
    "/Users/jungmin/project/src/utils/"
  ]
}
```

> 주의: 절대 경로를 사용해야 한다. 상대 경로는 현재 디렉토리 기준으로 해석되어 작업 디렉토리 변경 시 깨질 수 있다.

## 실수 복구

freeze 상태에서 실수로 허용 범위 밖에서 작업한 경우:

1. **즉시 중단**: 추가 작업 금지
2. **변경 확인**: `git diff`로 의도치 않은 수정 내역 파악
3. **선택적 복구**:
   - 전체 되돌리기: `git checkout -- <파일경로>`
   - 부분 복구: `git restore -p <파일경로>` (대화형 선택)
4. **freeze 재확인**: `/freeze` 상태와 `config.json` 내용 재검토

freeze 차단이 발동했다면 실제 파일은 수정되지 않았으므로 복구 불필요.

## 세션 종료 시 자동 해제

freeze는 **세션 한정** 기능이다:

- Claude Code 세션이 종료되면 freeze 상태도 함께 해제됨
- 단, `config.json` 파일 자체는 삭제되지 않으므로 다음 세션 시작 시 남아 있을 수 있음
- 다음 세션에서 freeze를 원하지 않는다면 `/freeze --off`로 명시적으로 해제하거나 `config.json`을 삭제해야 함
- 영구 보호가 필요한 경우에는 파일 시스템 권한(chmod) 또는 git hook을 사용할 것
