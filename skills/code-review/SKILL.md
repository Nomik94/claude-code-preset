---
name: code-review
description: |
  Code Reviewer 에이전트 스폰.
  Use when: /code-review, 코드 리뷰해줘, PR 리뷰, 리뷰해줘,
  코드 품질 점검, 리팩토링 방향, 기술 부채 식별, 코드 스멜.
  NOT for: 단순 포맷팅, 오타 수정.
argument-hint: <파일 경로 또는 PR 번호>
---

# Code Reviewer 에이전트

`agents/code-reviewer.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/code-reviewer.md`의 전체 내용
- 리뷰 대상: $ARGUMENTS

**필수 스킬** (트리거 조건 충족 시 반드시 호출):
- `/build-fix` — 빌드/린트 에러 발견 시
- `/audit` — 규칙 위반 검증
- `/python-best-practices` — Python 코드 품질 검증

**참조 가능 스킬** (리뷰 중 패턴 검증 시 Skill 도구로 호출):
- `/fastapi` — 프로젝트 구조, 컨벤션
- `/domain-layer` — 도메인 순수성, 레이어 책임 검증
- `/api-design` — API 설계 규칙, EndpointPath
- `/sqlalchemy` — DB 패턴, N+1, lazy="raise"
- `/alembic` — 마이그레이션 패턴
- `/pydantic-schema` — DTO 설계, CamelModel
- `/error-handling` — 예외 처리 패턴, mappings.py
- `/middleware` — 미들웨어 순서, 패턴
- `/testing` — 테스트 패턴, 커버리지 기준
- `/security-audit` — JWT, RBAC, 보안 패턴
- `/environment` — 환경변수, 설정 관리
- `/monitoring` — 로깅, 메트릭 패턴
- `/background-tasks` — 비동기 작업, Celery 패턴
- `/websocket` — WebSocket, 실시간 통신 패턴
- `/gap-analysis` — 설계 vs 구현 비교
