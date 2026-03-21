"""FastAPI + SQLAlchemy 테스트 conftest 템플릿

사용법: 이 파일을 tests/conftest.py에 복사하고 프로젝트에 맞게 수정하라.
"""

import asyncio
from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# TODO: 프로젝트의 실제 app과 Base를 import
# from app.main import app
# from app.db.base import Base
# from app.db.session import get_session


# === 엔진 & 세션 ===

TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# === Fixtures ===

@pytest.fixture(scope="session")
def event_loop():
    """세션 스코프 이벤트 루프."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="function")
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """함수 스코프 DB 세션 — 각 테스트 후 롤백."""
    async with engine.begin() as conn:
        # await conn.run_sync(Base.metadata.create_all)  # TODO: uncomment
        pass

    async with TestSessionLocal() as session:
        yield session
        await session.rollback()

    async with engine.begin() as conn:
        # await conn.run_sync(Base.metadata.drop_all)  # TODO: uncomment
        pass


@pytest_asyncio.fixture(scope="function")
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """비동기 HTTP 테스트 클라이언트."""
    # TODO: app 의존성 오버라이드
    # app.dependency_overrides[get_session] = lambda: db_session

    # async with AsyncClient(
    #     transport=ASGITransport(app=app),
    #     base_url="http://test",
    # ) as ac:
    #     yield ac

    # app.dependency_overrides.clear()
    yield  # TODO: remove this placeholder
