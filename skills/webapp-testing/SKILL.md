---
name: webapp-testing
description: |
  Use when 로컬 웹앱 E2E 테스트, 브라우저 자동화, 스크린샷 비교 시.
  NOT for 유닛 테스트, API 테스트, 백엔드 전용 테스트.
---

# Python Playwright 웹앱 테스트 가이드

> Python `playwright` (sync API) 로컬 웹앱 테스트.

## 의사결정 트리

```
테스트 대상?
  ├── 정적 HTML → file:// 직접 열기
  ├── 동적 앱 + 서버 미실행 → with_server.py
  └── 서버 실행 중 → 정찰-후-행동 패턴
```

## 핵심 원칙

### sync_playwright() 사용
테스트에서 동기 API. `async_playwright` 금지.

### 서술적 셀렉터

| 우선순위 | 메서드 | 용도 |
|---------|--------|------|
| 1 | `get_by_role()` | 버튼, 링크, 헤딩 |
| 2 | `get_by_label()` | 폼 입력 |
| 3 | `get_by_text()` | 텍스트 기반 |
| 4 | `get_by_test_id()` | data-testid |
| 5 | CSS 셀렉터 | 최후 수단 |

### 필수 규칙
- `try/finally`로 브라우저 종료 보장
- `time.sleep()` 금지 → `page.wait_for_selector()`, `wait_until="networkidle"`
- 타임아웃: `context.set_default_timeout(10_000)`

### 안티패턴
- `async_playwright` 테스트에서 사용
- CSS 셀렉터 우선 사용
- `time.sleep()` 대기
- `browser.close()` try/finally 밖
- 서버 없이 동적 앱 접근

## 정찰-후-행동 패턴

실행 중인 서버 테스트 시:
1. **정찰**: 스크린샷 + DOM 구조로 셀렉터 파악
2. **행동**: 발견한 셀렉터로 자동화 스크립트 작성

## 체크리스트

```
[ ] sync_playwright() 사용
[ ] 서술적 셀렉터 (get_by_role 등)
[ ] 브라우저 종료 보장 (try/finally)
[ ] 명시적 대기 (time.sleep 금지)
[ ] 서버 라이프사이클 관리
[ ] 스크린샷 저장 (디버깅용)
[ ] 애니메이션 비활성화 (비교 시)
[ ] 일관된 뷰포트 설정
```

> 코드 템플릿: [references/test-templates.md](references/test-templates.md)
> 서버 헬퍼: [references/server-helper.md](references/server-helper.md)
> 스크린샷 테스트: [references/screenshot-testing.md](references/screenshot-testing.md)

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
