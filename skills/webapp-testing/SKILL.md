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

## 1. 서버 라이프사이클 관리: with_server.py

### 핵심 개념

테스트 전 서버를 자동으로 시작하고, 테스트 후 정리하는 헬퍼 스크립트.

### scripts/with_server.py 구현

```python
"""서버 라이프사이클 관리 헬퍼.

단일 또는 복수 서버를 시작하고, 준비되면 콜백을 실행한 뒤 정리.
"""

from __future__ import annotations

import subprocess
import socket
import time
import signal
from dataclasses import dataclass, field
from collections.abc import Callable


@dataclass(slots=True)
class ServerConfig:
    """서버 설정."""
    command: list[str]
    port: int
    host: str = "localhost"
    startup_timeout: float = 30.0
    env: dict[str, str] = field(default_factory=dict)


def wait_for_port(host: str, port: int, timeout: float = 30.0) -> bool:
    """포트가 열릴 때까지 대기."""
    start = time.monotonic()
    while time.monotonic() - start < timeout:
        try:
            with socket.create_connection((host, port), timeout=1.0):
                return True
        except OSError:
            time.sleep(0.5)
    return False


def with_server(
    config: ServerConfig | list[ServerConfig],
    callback: Callable[[], None],
) -> None:
    """서버를 시작하고 콜백 실행 후 정리.

    Args:
        config: 단일 또는 복수 서버 설정.
        callback: 서버 준비 후 실행할 함수.
    """
    configs = config if isinstance(config, list) else [config]
    processes: list[subprocess.Popen] = []

    try:
        # 서버 시작
        for cfg in configs:
            proc = subprocess.Popen(
                cfg.command,
                env={**dict(__import__('os').environ), **cfg.env},
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            processes.append(proc)

        # 포트 대기
        for cfg in configs:
            if not wait_for_port(cfg.host, cfg.port, cfg.startup_timeout):
                raise TimeoutError(
                    f"{cfg.host}:{cfg.port} 서버가 {cfg.startup_timeout}초 내에 시작되지 않았습니다"
                )

        # 콜백 실행
        callback()

    finally:
        # 정리
        for proc in processes:
            proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
```

### 사용 예시

```python
from scripts.with_server import ServerConfig, with_server

def run_tests():
    """서버 시작 후 테스트 실행."""
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto("http://localhost:3000")

        # 테스트 로직
        assert page.title() == "My App"

        browser.close()


# 단일 서버
with_server(
    ServerConfig(command=["pnpm", "dev"], port=3000),
    callback=run_tests,
)

# 복수 서버 (프론트엔드 + 백엔드)
with_server(
    [
        ServerConfig(command=["pnpm", "dev"], port=3000),
        ServerConfig(command=["python", "-m", "uvicorn", "main:app"], port=8000),
    ],
    callback=run_tests,
)
```

---

## 2. 정찰-후-행동 패턴

이미 실행 중인 서버에 대해 테스트할 때 사용. 먼저 페이지 구조를 파악(정찰)한 뒤 자동화 스크립트를 작성(행동).

### 2.1: 정찰 단계

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

### 2.2: 행동 단계

정찰에서 발견한 셀렉터를 기반으로 자동화.

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

## 3. 핵심 원칙

### 3.1: sync_playwright() 사용

테스트 스크립트에서는 동기 API 사용. 비동기 API는 프로덕션 코드용.

```python
# ❌ Bad — 테스트에서 async
import asyncio
from playwright.async_api import async_playwright

async def test():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # ...

asyncio.run(test())

# ✅ Good — 테스트에서 sync
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    # ...
```

### 3.2: 서술적 셀렉터 우선

CSS 셀렉터보다 역할/텍스트 기반 셀렉터 사용.

```python
# ❌ Bad — 깨지기 쉬운 셀렉터
page.click(".btn-primary.submit-form")
page.fill("#input-email-field", "test@example.com")

# ✅ Good — 서술적 셀렉터
page.get_by_role("button", name="제출").click()
page.get_by_label("이메일").fill("test@example.com")
page.get_by_placeholder("검색어 입력").fill("키워드")
page.get_by_text("로그인").click()
```

### 3.3: 브라우저 종료 필수

`try/finally` 또는 context manager로 항상 브라우저 정리.

```python
# ❌ Bad — 예외 발생 시 브라우저 미종료
browser = p.chromium.launch()
page = browser.new_page()
page.goto("http://localhost:3000")
assert page.title() == "Expected"  # 실패하면 브라우저 좀비
browser.close()

# ✅ Good — 항상 종료
browser = p.chromium.launch()
try:
    page = browser.new_page()
    page.goto("http://localhost:3000")
    assert page.title() == "Expected"
finally:
    browser.close()
```

### 3.4: 명시적 대기

`time.sleep()` 대신 Playwright 내장 대기 사용.

```python
# ❌ Bad
page.click("button")
import time; time.sleep(2)
text = page.text_content(".result")

# ✅ Good
page.click("button")
page.wait_for_selector(".result", state="visible")
text = page.text_content(".result")

# ✅ Good — 네트워크 유휴 대기
page.goto("http://localhost:3000", wait_until="networkidle")
```

### 3.5: 타임아웃 설정

기본 타임아웃 외에 명시적 타임아웃 지정.

```python
# ✅ Good
browser = p.chromium.launch()
context = browser.new_context()
context.set_default_timeout(10_000)  # 10초
page = context.new_page()
```

---

## 4. 코드 템플릿

### 4.1: 기본 테스트 스크립트

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

### 4.2: 서버 연동 테스트

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

### 4.3: 스크린샷 비교 테스트

```python
"""스크린샷 기반 시각적 회귀 테스트."""

from pathlib import Path
from playwright.sync_api import sync_playwright


SCREENSHOT_DIR = Path("screenshots")
BASELINE_DIR = SCREENSHOT_DIR / "baseline"
CURRENT_DIR = SCREENSHOT_DIR / "current"


def capture_screenshots(base_url: str, routes: list[str]):
    """여러 라우트의 스크린샷 촬영."""
    CURRENT_DIR.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        try:
            # 일관된 뷰포트 설정
            context = browser.new_context(
                viewport={"width": 1280, "height": 720},
                device_scale_factor=2,
            )
            page = context.new_page()

            for route in routes:
                page.goto(f"{base_url}{route}", wait_until="networkidle")

                # 애니메이션 비활성화 (일관된 스크린샷)
                page.evaluate("""
                    () => {
                        const style = document.createElement('style');
                        style.textContent = '*, *::before, *::after { animation: none !important; transition: none !important; }';
                        document.head.appendChild(style);
                    }
                """)

                filename = route.strip("/").replace("/", "_") or "home"
                page.screenshot(path=str(CURRENT_DIR / f"{filename}.png"), full_page=True)

        finally:
            browser.close()


def compare_screenshots():
    """기준선과 현재 스크린샷 비교."""
    if not BASELINE_DIR.exists():
        print("기준선 없음. 현재 스크린샷을 기준선으로 복사합니다.")
        import shutil
        shutil.copytree(CURRENT_DIR, BASELINE_DIR)
        return

    from PIL import Image, ImageChops

    for current_path in CURRENT_DIR.glob("*.png"):
        baseline_path = BASELINE_DIR / current_path.name
        if not baseline_path.exists():
            print(f"새 페이지 감지: {current_path.name}")
            continue

        current = Image.open(current_path)
        baseline = Image.open(baseline_path)

        if current.size != baseline.size:
            print(f"크기 변경: {current_path.name} ({baseline.size} → {current.size})")
            continue

        diff = ImageChops.difference(current, baseline)
        if diff.getbbox():
            # 차이 이미지 저장
            diff_dir = SCREENSHOT_DIR / "diff"
            diff_dir.mkdir(exist_ok=True)
            diff.save(diff_dir / current_path.name)
            print(f"변경 감지: {current_path.name}")
        else:
            print(f"일치: {current_path.name}")


if __name__ == "__main__":
    capture_screenshots("http://localhost:3000", ["/", "/about", "/dashboard"])
    compare_screenshots()
```

### 4.4: 정적 HTML 직접 테스트

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

---

## 셀렉터 우선순위

| 우선순위 | 메서드 | 용도 |
|---------|--------|------|
| 1 | `get_by_role()` | 버튼, 링크, 헤딩 등 역할 기반 |
| 2 | `get_by_label()` | 폼 입력 필드 |
| 3 | `get_by_placeholder()` | placeholder 기반 |
| 4 | `get_by_text()` | 텍스트 내용 기반 |
| 5 | `get_by_test_id()` | data-testid 속성 |
| 6 | CSS 셀렉터 | 최후 수단 |

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
