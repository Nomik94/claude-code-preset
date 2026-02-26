---
name: background-tasks
description: |
  백그라운드 작업 패턴 레퍼런스.
  Use when: 백그라운드 작업, 비동기 작업, Celery, 이메일 발송,
  무거운 작업, 큐, task queue, 작업 스케줄링, periodic task,
  BackgroundTasks, worker, 작업 재시도, retry, dead letter.
  NOT for: 단순 async/await (FastAPI 기본 비동기).
---

# 백그라운드 작업

## 1. FastAPI BackgroundTasks

동일 프로세스 내에서 실행되는 단순 일회성 작업. 가벼운 작업에 적합합니다.

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str, name: str) -> None:
    """Send welcome email after signup. Non-blocking."""
    # email sending logic here
    logger.info(f"Welcome email sent to {email}")

@router.post("/users", status_code=201)
async def create_user(
    payload: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    user = await user_service.create(db, payload)
    background_tasks.add_task(send_welcome_email, user.email, user.name)
    return UserResponse.model_validate(user)
```

## 2. Celery 설정

### celery_app.py

```python
from celery import Celery

celery_app = Celery(
    "worker",
    broker="redis://redis:6379/0",
    backend="redis://redis:6379/1",
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={
        "app.tasks.email.*": {"queue": "email"},
        "app.tasks.reports.*": {"queue": "reports"},
    },
)
```

### 재시도 포함 태스크 정의

```python
from app.core.celery_app import celery_app

@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
)
def send_notification(self, user_id: int, message: str) -> dict:
    try:
        result = notification_service.send(user_id, message)
        return {"status": "sent", "user_id": user_id}
    except ConnectionError as exc:
        raise self.retry(exc=exc, countdown=2 ** self.request.retries * 60)
    except Exception as exc:
        logger.error(f"Notification failed permanently: {exc}")
        raise
```

## 3. Celery Worker

```bash
# Single worker, multiple queues
celery -A app.core.celery_app worker -l info -Q default,email

# Concurrency control
celery -A app.core.celery_app worker -l info -c 4 -Q reports
```

## 4. 주기적 작업 (Celery Beat)

```python
from celery.schedules import crontab

celery_app.conf.beat_schedule = {
    "cleanup-expired-tokens": {
        "task": "app.tasks.auth.cleanup_expired_tokens",
        "schedule": crontab(hour=3, minute=0),  # daily 03:00 UTC
    },
    "generate-daily-report": {
        "task": "app.tasks.reports.generate_daily",
        "schedule": crontab(hour=6, minute=0),
    },
    "health-check-ping": {
        "task": "app.tasks.monitoring.ping",
        "schedule": 300.0,  # every 5 minutes
    },
}
```

```bash
celery -A app.core.celery_app beat -l info
```

## 5. 작업 패턴

### Fire-and-Forget (발사 후 잊기)

```python
send_notification.delay(user_id=42, message="Order shipped")
```

### 작업 체인

```python
from celery import chain

workflow = chain(
    process_order.s(order_id),
    validate_payment.s(),
    send_confirmation.s(),
)
workflow.apply_async()
```

### 결과가 있는 작업

```python
result = generate_report.apply_async(args=[report_id])
# Option A: blocking (avoid in web requests)
report = result.get(timeout=30)
# Option B: poll status via endpoint
# GET /tasks/{task_id}/status -> result.state
```

## 6. 에러 처리

```python
@celery_app.task(
    bind=True,
    max_retries=3,
    autoretry_for=(ConnectionError, TimeoutError),
    retry_backoff=True,        # exponential: 1s, 2s, 4s
    retry_backoff_max=600,     # cap at 10 minutes
    retry_jitter=True,         # randomize to avoid thundering herd
)
def resilient_task(self, payload: dict) -> dict:
    ...
```

Dead letter 패턴 — 영구 실패한 작업을 기록합니다:

```python
@celery_app.task(bind=True, max_retries=3)
def task_with_dlq(self, data: dict) -> None:
    try:
        process(data)
    except Exception as exc:
        if self.request.retries >= self.max_retries:
            dead_letter_store.save(task_name=self.name, data=data, error=str(exc))
            logger.critical(f"Task moved to DLQ: {self.name} | {exc}")
            return
        raise self.retry(exc=exc)
```

## 7. 선택 가이드

| 기준                   | FastAPI BackgroundTasks | Celery                    |
|-----------------------|------------------------|---------------------------|
| 복잡도                 | 낮음                    | 높음                      |
| 프로세스               | 동일 프로세스            | 별도 워커 프로세스          |
| 재시도/백오프            | 수동                    | 내장 지원                  |
| 스케줄링               | 불가                    | 가능 (Beat)                |
| 분산 처리              | 불가                    | 가능                      |
| 결과 추적              | 불가                    | 가능 (backend)             |
| **사용 시점**          | 이메일, 로깅, 훅         | 리포트, ETL, 무거운 I/O    |

## 8. Docker 통합

```yaml
# docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  worker:
    build: .
    command: celery -A app.core.celery_app worker -l info -Q default,email
    depends_on: [redis]
    env_file: .env

  beat:
    build: .
    command: celery -A app.core.celery_app beat -l info
    depends_on: [redis]
    env_file: .env
```
