---
name: audit
description: |
  커밋/PR 전 프로젝트 규칙 위반 검사.
  Use when: 프로젝트 규칙 검증, 커스텀 린트, 커밋 전 검사,
  audit, 규칙 위반 체크, 프로젝트 컨벤션 확인, 배포 전 검증.
  NOT for: 일반 린트 (ruff/eslint가 처리), 보안 감사 (security-audit 참조).
---

# Audit

자동화된 린터가 잡을 수 없는 프로젝트 고유 규칙을 검증.

## 동작 방식

1. `.claude/audit-rules/*.md`에서 커스텀 규칙 로드
2. Stack Detection으로 적용 규칙 결정
3. 기본 내장 검사 실행 (항상 활성)
4. 변경된 파일을 모든 규칙 기준으로 스캔
5. 심각도 및 수정 제안과 함께 위반 사항 보고

## 커스텀 규칙 형식

`.claude/audit-rules/` 내 각 규칙 파일:

```markdown
---
name: rule-name
severity: error | warning | info
stack: be | fe | all
---

## Pattern
[검사 대상 - 파일 패턴, 코드 패턴, 구조 패턴]

## Expected
[올바른 상태]

## Example
[위반 사례와 수정 예시]
```

## 기본 내장 검사 (10개)

### 공통 (항상 활성)

| # | 검사 항목 | 심각도 | 내용 |
|---|----------|--------|------|
| 1 | 하드코딩 시크릿 금지 | error | 소스 코드 내 API 키, 비밀번호, 토큰 |
| 2 | 디버그 아티팩트 금지 | error | `print()`, `breakpoint()`, `debugger`, `console.log` (프로덕션) |
| 3 | TODO/FIXME 잔존 | warning | 스테이징된 파일의 미해결 마커 |
| 4 | .env 파일 커밋 금지 | error | git에 포함된 `.env`, `.env.local` |
| 5 | Conventional Commits | warning | 커밋 메시지가 `feat:`, `fix:` 등으로 시작하지 않음 |

### BE 전용 (pyproject.toml 감지 시)

| # | 검사 항목 | 심각도 | 내용 |
|---|----------|--------|------|
| 6 | Folder-first 위반 | error | router.py 단일 파일 (controllers/ 폴더 필수) |
| 7 | lazy="raise" 누락 | warning | relationship에 lazy="raise" 미적용 |
| 8 | 와일드카드 import 금지 | warning | `from module import *` |

### FE 전용 (package.json 감지 시)

| # | 검사 항목 | 심각도 | 내용 |
|---|----------|--------|------|
| 9 | 'use client' 남용 | warning | Server Component로 충분한 컴포넌트에 'use client' 사용 |
| 10 | img 태그 사용 금지 | warning | `<img>` 대신 `next/image` 사용 필수 |

## 규칙 관리

| 작업 | 방법 |
|------|------|
| 규칙 추가 | `.claude/audit-rules/`에 새 `.md` 파일 생성 |
| 규칙 목록 | `.claude/audit-rules/` 내 모든 파일 이름 + 심각도 표시 |
| 규칙 삭제 | `.claude/audit-rules/`에서 해당 `.md` 파일 삭제 |

## 종료 기준

| 결과 | 판정 |
|------|------|
| 위반 0건 | Audit 통과, 커밋/배포 진행 가능 |
| 위반 1건 이상 (error) | Audit 실패, 진행 전 반드시 수정 |
| 경고만 있는 경우 | 참고 사항과 함께 Audit 통과 |

## 출력 형식

```
## Audit Report [BE/FE/Fullstack]

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

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
