---
name: environment
description: |
  환경 설정 및 pydantic-settings 패턴.
  Use when: 환경변수, .env 파일, 설정 관리, pydantic-settings,
  Settings 클래스, 환경별 설정, local/dev/staging/prod 분리,
  env_nested_delimiter, 시크릿 관리, 설정 검증.
  NOT for: Docker 환경변수 (docker skill 참조).
---

# 환경 설정 및 Settings 패턴

## 1. Settings 클래스

```python
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseSettings):
    host: str = "localhost"
    port: int = 5432
    user: str = "postgres"
    password: str = ""
    name: str = "app"

    @property
    def url(self) -> str:
        return f"postgresql+asyncpg://{self.user}:{self.password}@{self.host}:{self.port}/{self.name}"

    @field_validator("port")
    @classmethod
    def validate_port(cls, v: int) -> int:
        if not (1 <= v <= 65535):
            raise ValueError("port must be 1-65535")
        return v


class RedisSettings(BaseSettings):
    host: str = "localhost"
    port: int = 6379
    db: int = 0

    @property
    def url(self) -> str:
        return f"redis://{self.host}:{self.port}/{self.db}"


class JWTSettings(BaseSettings):
    secret_key: str = "CHANGE-ME"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
```

## 2. 중첩 서브모델을 가진 Root Settings

```python
from typing import Literal
from functools import lru_cache
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_nested_delimiter="__",
        extra="ignore",
    )

    app_name: str = "my-app"
    env: Literal["local", "dev", "staging", "prod"] = "local"
    debug: bool = False
    log_level: str = "INFO"

    db: DatabaseSettings = DatabaseSettings()
    redis: RedisSettings = RedisSettings()
    jwt: JWTSettings = JWTSettings()

    @field_validator("jwt", mode="before")
    @classmethod
    def require_real_secret_in_prod(cls, v, info):
        """Prevent default JWT secret in production."""
        if info.data.get("env") == "prod":
            secret = v.get("secret_key", "") if isinstance(v, dict) else getattr(v, "secret_key", "")
            if secret == "CHANGE-ME":
                raise ValueError("JWT secret_key must be set in production")
        return v
```

## 3. Settings 팩토리 (싱글톤)

```python
@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

# FastAPI dependency
from fastapi import Depends

def settings_dependency() -> Settings:
    return get_settings()
```

## 4. 환경 파일 구조

```
project/
  .env              # local development (git-ignored)
  .env.example      # template committed to git
  .env.dev          # dev server overrides
  .env.staging      # staging overrides
  .env.prod         # prod overrides (or use secrets manager)
```

환경별 로드:
```python
import os

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", f".env.{os.getenv('APP_ENV', 'local')}"),
        env_nested_delimiter="__",
        extra="ignore",
    )
```

## 5. .env.example (git에 커밋)

```bash
# Application
APP_NAME=my-app
ENV=local          # local | dev | staging | prod
DEBUG=true
LOG_LEVEL=INFO

# Database  (nested via __ delimiter)
DB__HOST=localhost
DB__PORT=5432
DB__USER=postgres
DB__PASSWORD=
DB__NAME=app

# Redis
REDIS__HOST=localhost
REDIS__PORT=6379
REDIS__DB=0

# JWT
JWT__SECRET_KEY=CHANGE-ME
JWT__ALGORITHM=HS256
JWT__ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT__REFRESH_TOKEN_EXPIRE_DAYS=7
```

## 6. 프로덕션 검증

```python
from pydantic import model_validator

class Settings(BaseSettings):
    # ... fields ...

    @model_validator(mode="after")
    def validate_production(self) -> Self:
        if self.env == "prod":
            assert not self.debug, "debug must be False in prod"
            assert self.jwt.secret_key != "CHANGE-ME", "Set a real JWT secret"
            assert self.db.password, "DB password required in prod"
            assert self.log_level in ("WARNING", "ERROR", "INFO"), "Unsafe log level for prod"
        return self
```

## 7. FastAPI Lifespan에서의 사용

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    # startup: create pools, validate connections
    yield
    # shutdown: close pools

app = FastAPI(title=get_settings().app_name, lifespan=lifespan)
```
