---
name: audit
description: |
  커밋/PR 전 프로젝트 규칙 위반 검사.
  Use when: 프로젝트 규칙 검증, 커스텀 린트, 커밋 전 검사,
  audit, 규칙 위반 체크, 프로젝트 컨벤션 확인, 배포 전 검증.
  NOT for: 일반 린트 (ruff/mypy가 처리), 보안 감사 (security-audit 참조).
---

# Audit

자동화된 린터가 잡을 수 없는 프로젝트 고유 규칙을 검증합니다.

## 동작 방식

1. `.claude/audit-rules/*.md`에서 커스텀 규칙 로드
2. 기본 내장 검사 실행 (항상 활성)
3. 변경된 파일을 모든 규칙 기준으로 스캔
4. 심각도 및 수정 제안과 함께 위반 사항 보고

## 규칙 파일 형식

`.claude/audit-rules/` 내 각 규칙 파일은 다음 구조를 따릅니다:

```markdown
---
name: rule-name
severity: error | warning | info
---

## Pattern
[What to look for - file patterns, code patterns, structural patterns]

## Expected
[What the correct state should be]

## Example
[Concrete violation and fix example]
```

## 기본 내장 검사 (항상 활성)

커스텀 규칙과 관계없이 항상 실행됩니다:

| 검사 항목 | 심각도 | 내용 |
|----------|--------|------|
| 하드코딩된 시크릿 금지 | error | 소스 코드 내 API 키, 비밀번호, 토큰 |
| 디버그 아티팩트 금지 | error | 프로덕션 코드의 `print()`, `breakpoint()`, `debugger` |
| 커밋에 TODO/FIXME 금지 | warning | 스테이징된 파일의 미해결 마커 |
| 와일드카드 import 금지 | warning | Python의 `from module import *` |
| .env 파일 커밋 금지 | error | git에 포함된 `.env`, `.env.local` |
| Folder-first 위반 | error | router.py 단일 파일 (controllers/ 폴더 필수) |
| lazy="raise" 누락 | warning | relationship에 lazy="raise" 미적용 |
| python-jose import | error | PyJWT 사용 필수 (`import jwt`) |
| Conventional Commits | warning | 커밋 메시지가 `feat:`, `fix:` 등으로 시작하지 않음 |

## 규칙 관리

### 규칙 추가
위 형식에 따라 `.claude/audit-rules/`에 새 `.md` 파일을 생성합니다.

### 규칙 목록
`.claude/audit-rules/` 내 모든 파일을 읽고 이름 + 심각도를 표시합니다.

### 규칙 삭제
`.claude/audit-rules/`에서 해당 `.md` 파일을 삭제합니다.

## 출력 형식

```
## Audit Report

### Summary
- Passed: [count]
- Warnings: [count]
- Violations: [count]

### Violations (must fix)
| # | Rule | File | Line | Detail |
|---|------|------|------|--------|
| 1 | no-hardcoded-secrets | src/config.py | 12 | API key found |

### Warnings (should fix)
| # | Rule | File | Line | Detail |
|---|------|------|------|--------|
| 1 | no-todo | src/auth.py | 45 | TODO comment |

### Passed
- [rule name]: All clear
```

## 종료 기준

- **위반 0건**: Audit 통과, 커밋/배포 진행 가능
- **위반 1건 이상**: Audit 실패, 진행 전 반드시 수정
- **경고만 있는 경우**: 참고 사항과 함께 Audit 통과
