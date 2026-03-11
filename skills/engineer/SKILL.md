---
name: engineer
description: |
  Engineer 에이전트 스폰.
  Use when: /engineer, 설계해줘, 구현해줘, API 설계, DB 스키마, 시스템 설계,
  아키텍처, TDD로 만들어줘, SOLID 적용, 성능 최적화해줘, 보안 구현,
  느려, 병목, N+1, 커버리지 분석, 프로덕션 코드, 확장성 설계.
  NOT for: 단순 1줄 수정, 오타 수정, 코드 리뷰 (/code-review), 버그 분석 (/root-cause).
argument-hint: <설계/구현 대상>
---

# Engineer 에이전트

`~/.claude/agents/engineer.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `~/.claude/agents/engineer.md`의 전체 내용
- 설계/구현 요청: $ARGUMENTS

**필수 스킬** (트리거 조건 충족 시 반드시 호출):
- `/confidence-check` — 구현 시작 전 신뢰도 평가
- `/verify` — 구현 완료 후 품질 검증
- `/build-fix` — 빌드/린트 에러 발생 시
- `/checkpoint` — 위험한 변경(삭제, 리팩토링) 전
- `/audit` — 커밋/PR 전 규칙 검증
- `/feature-planner` — 3+ 파일 변경 기능 설계 시
- `/learn` — 문제 해결 후 교훈 저장

**참조 가능 스킬** (작업 중 필요 시 Skill 도구로 호출):
- `/fastapi` — 프로젝트 구조, DI, App Factory
- `/domain-layer` — Entity, Aggregate Root, 도메인 설계
- `/api-design` — 엔드포인트 설계, 버저닝, EndpointPath
- `/sqlalchemy` — DB 모델, 세션, 쿼리 패턴
- `/alembic` — DB 마이그레이션
- `/pydantic-schema` — DTO, CamelModel, 검증
- `/error-handling` — 도메인 예외, mappings.py
- `/middleware` — 미들웨어, CORS, decorator 패턴
- `/testing` — 테스트 작성, 픽스처
- `/environment` — pydantic-settings, 환경변수
- `/security-audit` — JWT, RBAC, 보안 패턴
- `/background-tasks` — Celery, task queue
- `/websocket` — WebSocket, 실시간 통신
- `/python-best-practices` — 타입 힌트, 코드 품질
- `/debugging` — 디버깅 도구, pdb, 프로파일링
- `/monitoring` — 로깅, APM, 메트릭
- `/gap-analysis` — 설계 vs 구현 비교
