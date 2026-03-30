---
name: audit
description: |
  커밋/PR 전 프로젝트 규칙 위반 검사.
  Use when: 프로젝트 규칙 검증, 커스텀 린트, 커밋 전 검사,
  audit, 규칙 위반 체크, 프로젝트 컨벤션 확인, 배포 전 검증.
  NOT for: 일반 린트 (ruff/eslint가 처리), 보안 감사 (security-audit 참조).
---

# Audit

자동화 린터가 못 잡는 프로젝트 고유 규칙 검증.

## 동작 방식
1. `.claude/audit-rules/*.md`에서 커스텀 규칙 로드
2. Stack Detection으로 적용 규칙 결정
3. 기본 내장 검사 실행
4. 변경 파일을 규칙 기준으로 스캔
5. 심각도 및 수정 제안과 함께 위반 보고

## 커스텀 규칙 형식

`.claude/audit-rules/` 내 `.md` 파일:

```markdown
---
name: rule-name
severity: error | warning | info
stack: be | fe | all
---
## Pattern
[검사 대상]
## Expected
[올바른 상태]
## Example
[위반→수정 예시]
```

## 기본 내장 검사 (10개)

### 공통

| # | 검사 | 심각도 | 내용 |
|---|------|--------|------|
| 1 | 하드코딩 시크릿 | error | API 키, 비밀번호, 토큰 |
| 2 | 디버그 아티팩트 | error | `print()`, `debugger`, `console.log` |
| 3 | TODO/FIXME 잔존 | warning | 미해결 마커 |
| 4 | .env 커밋 | error | `.env`, `.env.local` |
| 5 | Conventional Commits | warning | `feat:`/`fix:` 미준수 |

### BE 전용 (pyproject.toml 감지)

| # | 검사 | 심각도 | 내용 |
|---|------|--------|------|
| 6 | Folder-first 위반 | error | 단일 파일 → 폴더 필수 |
| 7 | lazy="raise" 누락 | warning | relationship 미적용 |
| 8 | 와일드카드 import | warning | `from module import *` |

### FE 전용 (package.json 감지)

| # | 검사 | 심각도 | 내용 |
|---|------|--------|------|
| 9 | 'use client' 남용 | warning | SC로 충분한 곳에 사용 |
| 10 | img 태그 | warning | `next/image` 필수 |

## 규칙 관리

| 작업 | 방법 |
|------|------|
| 추가 | `.claude/audit-rules/`에 `.md` 생성 |
| 목록 | 폴더 내 파일명 + 심각도 |
| 삭제 | 해당 `.md` 삭제 |

## 종료 기준

| 결과 | 판정 |
|------|------|
| 위반 0건 | 통과, 진행 가능 |
| error 1건+ | 실패, 수정 필수 |
| warning만 | 참고 사항 포함 통과 |

## 출력 형식

```
## Audit Report [BE/FE/Fullstack]

### Summary
- Passed: [count] / Warnings: [count] / Violations: [count]

### Violations (must fix)
| # | Rule | File | Line | Detail |

### Warnings (should fix)
| # | Rule | File | Line | Detail |

### Passed
- [rule name]: All clear
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
