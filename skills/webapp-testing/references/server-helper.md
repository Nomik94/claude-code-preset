# server-helper: with_server.py 구현

서버 라이프사이클 관리 헬퍼. 테스트 전 서버를 자동으로 시작하고, 테스트 후 정리.

## scripts/with_server.py 구현

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

## 사용 예시

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
