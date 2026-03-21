# test-templates: 코드 템플릿 모음

webapp-testing 스킬에서 사용하는 완전한 실행 가능 Python 코드 템플릿.

---

## 1. 기본 테스트 스크립트

```python
"""기본 웹앱 테스트 스크립트."""

from playwright.sync_api import sync_playwright


def test_homepage():
    """홈페이지 기본 검증."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            page = browser.new_page()
            page.goto("http://localhost:3000", wait_until="networkidle")

            # 페이지 타이틀 확인
            assert "My App" in page.title()

            # 주요 요소 존재 확인
            assert page.get_by_role("navigation").is_visible()
            assert page.get_by_role("heading", name="Welcome").is_visible()

            # 스크린샷 저장
            page.screenshot(path="test_homepage.png")

        finally:
            browser.close()


if __name__ == "__main__":
    test_homepage()
    print("테스트 통과")
```

---

## 2. 서버 연동 테스트

```python
"""서버 자동 시작/종료 테스트."""

from playwright.sync_api import sync_playwright
from scripts.with_server import ServerConfig, with_server


def run_e2e_tests():
    """E2E 테스트 실행."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            page = browser.new_page()
            page.goto("http://localhost:3000", wait_until="networkidle")

            # 로그인 플로우
            page.get_by_role("link", name="로그인").click()
            page.get_by_label("이메일").fill("admin@example.com")
            page.get_by_label("비밀번호").fill("admin1234")
            page.get_by_role("button", name="로그인").click()

            # 로그인 성공 확인
            page.wait_for_url("**/dashboard")
            assert page.get_by_text("환영합니다").is_visible()

            # CRUD 테스트
            page.get_by_role("button", name="새 항목").click()
            page.get_by_label("제목").fill("테스트 항목")
            page.get_by_role("button", name="저장").click()
            page.wait_for_selector("text=테스트 항목")

        finally:
            browser.close()


# 프론트엔드 + 백엔드 서버 시작 후 테스트
with_server(
    [
        ServerConfig(command=["pnpm", "dev"], port=3000),
        ServerConfig(
            command=["python", "-m", "uvicorn", "app.main:app", "--port", "8000"],
            port=8000,
        ),
    ],
    callback=run_e2e_tests,
)
```

---

## 3. 정찰 단계 스크립트

```python
"""1단계: 페이지 구조 파악."""

from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()

    # 페이지 로드 대기
    page.goto("http://localhost:3000", wait_until="networkidle")

    # 스크린샷 촬영
    page.screenshot(path="recon_screenshot.png", full_page=True)

    # DOM 구조 검사
    structure = page.evaluate("""
        () => {
            const elements = document.querySelectorAll('button, a, input, [role]');
            return Array.from(elements).map(el => ({
                tag: el.tagName.toLowerCase(),
                text: el.textContent?.trim().slice(0, 50),
                role: el.getAttribute('role'),
                id: el.id,
                className: el.className?.toString().slice(0, 80),
                type: el.getAttribute('type'),
                href: el.getAttribute('href'),
            }));
        }
    """)

    for el in structure:
        print(el)

    browser.close()
```

---

## 4. 행동 단계 스크립트

```python
"""2단계: 정찰 결과 기반 자동화."""

from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("http://localhost:3000", wait_until="networkidle")

    # 서술적 셀렉터 사용 (정찰에서 발견한 요소)
    page.get_by_role("button", name="로그인").click()
    page.get_by_label("이메일").fill("test@example.com")
    page.get_by_label("비밀번호").fill("password123")
    page.get_by_role("button", name="제출").click()

    # 결과 확인
    page.wait_for_selector("text=환영합니다")
    assert "대시보드" in page.title()

    browser.close()
```

---

## 5. 정적 HTML 직접 테스트

```python
"""정적 HTML 파일 테스트 (서버 불필요)."""

from pathlib import Path
from playwright.sync_api import sync_playwright


def test_static_html():
    """정적 HTML 페이지 검증."""
    html_path = Path("public/index.html").resolve()
    assert html_path.exists(), f"파일 없음: {html_path}"

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            page = browser.new_page()
            page.goto(f"file://{html_path}")

            # 기본 구조 확인
            assert page.get_by_role("heading", level=1).is_visible()

            # 링크 검증
            links = page.get_by_role("link").all()
            for link in links:
                href = link.get_attribute("href")
                assert href, f"href 없는 링크: {link.text_content()}"

        finally:
            browser.close()


if __name__ == "__main__":
    test_static_html()
    print("정적 HTML 테스트 통과")
```
