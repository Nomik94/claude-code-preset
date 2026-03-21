---
name: webapp-testing
description: |
  Use when 로컬 웹앱 E2E 테스트, 브라우저 자동화, 스크린샷 비교 시.
  NOT for 유닛 테스트, API 테스트, 백엔드 전용 테스트.
---

# Python Playwright 웹앱 테스트 가이드

> Python `playwright` (sync API)를 사용한 로컬 웹앱 테스트.
> 서버 라이프사이클 관리, 정찰-후-행동 패턴, 코드 템플릿 포함.

---

## 의사결정 트리

테스트 대상에 따라 접근 방식 선택:

```
테스트 대상 판별
  │
  ├── 정적 HTML 파일? ──→ file:// 프로토콜로 직접 열기
  │
  ├── 동적 앱 + 서버 미실행? ──→ with_server.py 사용
  │
  └── 서버 이미 실행 중? ──→ 정찰-후-행동 패턴
```

---

## 핵심 원칙

### sync_playwright() 사용

테스트 스크립트에서는 동기 API 사용. 비동기 API는 프로덕션 코드용.

- **Bad**: `async_playwright` + `asyncio.run()`
- **Good**: `with sync_playwright() as p:`

### 서술적 셀렉터 우선

CSS 셀렉터보다 역할/텍스트 기반 셀렉터 사용.

| 우선순위 | 메서드 | 용도 |
|---------|--------|------|
| 1 | `get_by_role()` | 버튼, 링크, 헤딩 등 역할 기반 |
| 2 | `get_by_label()` | 폼 입력 필드 |
| 3 | `get_by_placeholder()` | placeholder 기반 |
| 4 | `get_by_text()` | 텍스트 내용 기반 |
| 5 | `get_by_test_id()` | data-testid 속성 |
| 6 | CSS 셀렉터 | 최후 수단 |

### 브라우저 종료 필수

`try/finally`로 항상 브라우저 정리. 예외 발생 시에도 좀비 프로세스 방지.

### 명시적 대기

`time.sleep()` 대신 Playwright 내장 대기 사용.

- **Bad**: `time.sleep(2)`
- **Good**: `page.wait_for_selector(".result", state="visible")`
- **Good**: `page.goto(url, wait_until="networkidle")`

### 타임아웃 설정

```python
context.set_default_timeout(10_000)  # 10초
```

### 안티패턴

- `async_playwright` 테스트 스크립트에서 사용
- CSS 셀렉터 (`#id`, `.class`) 우선 사용
- `time.sleep()` 으로 대기
- `browser.close()` 를 `try/finally` 밖에 위치
- 서버 없이 동적 앱 직접 접근

---

## 정찰-후-행동 패턴

이미 실행 중인 서버에 대해 테스트할 때 사용.

1. **정찰**: 페이지 스크린샷 + DOM 구조 출력으로 셀렉터 파악
2. **행동**: 정찰에서 발견한 셀렉터 기반으로 자동화 스크립트 작성

> 코드 예시: references/test-templates.md (정찰 단계, 행동 단계 참조)

---

## 체크리스트

```
[ ] sync_playwright() 사용 (테스트 스크립트)
[ ] 서술적 셀렉터 (get_by_role, get_by_label 등)
[ ] 브라우저 종료 보장 (try/finally)
[ ] 명시적 대기 (time.sleep 금지)
[ ] 서버 라이프사이클 관리 (with_server.py)
[ ] 스크린샷 저장 (디버깅용)
[ ] 애니메이션 비활성화 (스크린샷 비교 시)
[ ] 일관된 뷰포트 설정
```

---

> 코드 템플릿: [references/test-templates.md](references/test-templates.md) 참조.
> 서버 헬퍼 구현: [references/server-helper.md](references/server-helper.md) 참조.
> 스크린샷 테스트: [references/screenshot-testing.md](references/screenshot-testing.md) 참조.

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
