# screenshot-testing: 스크린샷 비교 테스트

스크린샷 기반 시각적 회귀 테스트 템플릿.

## 스크린샷 비교 테스트

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
