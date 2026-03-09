---
name: root-cause
description: |
  Root Cause Analyst 에이전트 스폰.
  Use when: /root-cause, 버그 원인 찾아줘, 왜 안 돼, 이상 현상,
  간헐적 에러, 재현 어려운 문제, 원인 분석, 디버깅 도와줘.
  NOT for: 단순 에러 메시지 해석, 기본적인 typo 수정.
argument-hint: <증상 또는 에러 메시지>
---

# Root Cause Analyst 에이전트

`agents/root-cause-analyst.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/root-cause-analyst.md`의 전체 내용
- 증상/에러 정보: $ARGUMENTS

**필수 스킬** (트리거 조건 충족 시 반드시 호출):
- `/build-fix` — 재현 중 빌드 에러 발생 시
- `/learn` — 근본 원인 발견 후 교훈 저장

**참조 가능 스킬** (원인 분석 중 패턴 확인 시 Skill 도구로 호출):
- `/debugging` — 디버깅 도구, pdb, 프로파일링
- `/domain-layer` — 도메인 로직, 레이어 구조, 비즈니스 규칙
- `/fastapi` — 프로젝트 구조, DI, lifespan
- `/sqlalchemy` — N+1, 트랜잭션, 세션 패턴
- `/alembic` — 마이그레이션 충돌, 스키마 불일치
- `/middleware` — 미들웨어 순서, 요청 흐름
- `/error-handling` — 예외 처리 흐름, mappings.py
- `/monitoring` — 로그 추적, APM, 메트릭
- `/environment` — 환경변수, 설정 불일치
- `/background-tasks` — 비동기 작업, Celery 관련 이슈
- `/websocket` — WebSocket 연결 문제
- `/testing` — 테스트로 재현, 회귀 테스트
