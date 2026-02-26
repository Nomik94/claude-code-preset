---
name: api-versioning
description: |
  프로젝트 고유 API 버저닝 패턴 레퍼런스.
  Use when: API 버전 관리, v1/v2 경로 설정, 버전 올리기, 버전 분리,
  EndpointPath 헬퍼 사용법, 엔드포인트 경로 규칙, 하드코딩 경로 금지,
  admin/app/web 분리, Sub-Application, 클라이언트별 Swagger, 클라이언트별 미들웨어,
  app.mount, 서브앱 구조, deprecated API, sunset, deprecation 처리,
  check_versioning.py, CI에서 경로 린트.
  NOT for: 일반적인 REST API 설계 (그건 /api-design skill).
---

# API 버저닝 Skill

## URL 패턴

```
/{client}/v{version}/{domain}/{action}
```

| 세그먼트 | 설명 | 예시 |
|---------|------|------|
| `client` | 클라이언트 유형 | `admin`, `app`, `web` |
| `version` | API 버전 | `v1`, `v2` |
| `domain` | 서비스 도메인 | `attendance`, `user` |
| `action` | 엔드포인트 | `/list`, `/detail/{id}` |

## EndpointPath 헬퍼

```python
class EndpointPath:
    def __init__(self, client: str, domain: str, default_version: int = 1):
        self.client = client
        self.domain = domain
        self.default_version = default_version

    def __call__(self, action: str, *, v: int | None = None) -> str:
        version = v or self.default_version
        if not action.startswith("/"): action = f"/{action}"
        return f"/{self.client}/v{version}/{self.domain}{action}"

def admin(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("admin", domain, **kwargs)
def app(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("app", domain, **kwargs)
def web(domain: str, **kwargs) -> EndpointPath:
    return EndpointPath("web", domain, **kwargs)
```

## 사용법

```python
from core.util.versioning import admin
router = APIRouter()
api = admin("attendance")

@router.get(api("/list"))              # /admin/v1/attendance/list
@router.get(api("/detail/{id}"))       # /admin/v1/attendance/detail/{id}
@router.get(api("/list", v=2))         # /admin/v2/attendance/list
```

## Sub-Application 구조

```python
app = FastAPI(docs_url=None)
admin_app = FastAPI(title="Admin API")
app_app = FastAPI(title="App API")
web_app = FastAPI(title="Web API")

app.mount("/admin", admin_app)  # /admin/docs → Admin Swagger
app.mount("/app", app_app)      # /app/docs → App Swagger
app.mount("/web", web_app)      # /web/docs → Web Swagger
```

## 클라이언트별 미들웨어

```python
app.add_middleware(CORSMiddleware, ...)      # Global
admin_app.add_middleware(AdminAuthMiddleware) # /admin/** only
app_app.add_middleware(JWTMobileAuth)         # /app/** only
web_app.add_middleware(WebSessionMiddleware)  # /web/** only
```

## Deprecation 처리

```python
@deprecated_version(version=1, sunset_date="2026-06-01", successor_version=2)
async def get_attendance_list(): ...
```

## CI 린트: 하드코딩 경로 금지

```python
# scripts/check_versioning.py
PATTERN = re.compile(r'@router\.(get|post|put|patch|delete)\(\s*["\']/(admin|app|web)/v\d+')
# Fails CI if found → enforce EndpointPath usage
```
