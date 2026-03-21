"""서버 라이프사이클 관리 헬퍼 — E2E 테스트용"""

import subprocess
import time
import signal
import sys
from contextlib import contextmanager
from playwright.sync_api import sync_playwright


@contextmanager
def with_server(command: str, port: int = 3000, startup_timeout: int = 30):
    """서버를 시작하고 테스트 완료 후 정리한다.

    Usage:
        with with_server("npm run dev", port=3000) as page:
            page.goto("http://localhost:3000")
            assert page.title() == "My App"
    """
    process = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_IGN),
    )

    # 서버 시작 대기
    import socket
    start = time.time()
    while time.time() - start < startup_timeout:
        try:
            with socket.create_connection(("localhost", port), timeout=1):
                break
        except (ConnectionRefusedError, OSError):
            time.sleep(0.5)
    else:
        process.kill()
        raise TimeoutError(f"서버가 {startup_timeout}초 내에 시작되지 않았습니다 (port {port})")

    playwright = sync_playwright().start()
    browser = playwright.chromium.launch()
    page = browser.new_page()

    try:
        yield page
    finally:
        browser.close()
        playwright.stop()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


@contextmanager
def with_servers(servers: list[dict]):
    """여러 서버를 동시에 시작한다.

    Usage:
        servers = [
            {"command": "uvicorn main:app --port 8000", "port": 8000},
            {"command": "npm run dev", "port": 3000},
        ]
        with with_servers(servers) as page:
            page.goto("http://localhost:3000")
    """
    processes = []
    for server in servers:
        proc = subprocess.Popen(server["command"], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        processes.append(proc)

    # 모든 서버 시작 대기
    import socket
    for server in servers:
        port = server["port"]
        start = time.time()
        timeout = server.get("timeout", 30)
        while time.time() - start < timeout:
            try:
                with socket.create_connection(("localhost", port), timeout=1):
                    break
            except (ConnectionRefusedError, OSError):
                time.sleep(0.5)
        else:
            for p in processes:
                p.kill()
            raise TimeoutError(f"서버가 {timeout}초 내에 시작되지 않았습니다 (port {port})")

    playwright = sync_playwright().start()
    browser = playwright.chromium.launch()
    page = browser.new_page()

    try:
        yield page
    finally:
        browser.close()
        playwright.stop()
        for proc in processes:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
