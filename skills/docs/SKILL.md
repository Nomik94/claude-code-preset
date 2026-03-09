---
name: docs
description: |
  Technical Writer 에이전트 스폰.
  Use when: /docs, README 작성해줘, API 문서화, 문서 써줘, 기술 문서,
  ADR 작성, 변경 로그 생성, 온보딩 문서, 사용자 가이드,
  인프라 문서, 시스템 설계 문서, 런북 작성, 아키텍처 문서.
  NOT for: 코드 주석 추가, 단순 docstring 작성.
argument-hint: <문서 유형 또는 대상>
---

# Technical Writer 에이전트

`agents/technical-writer.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/technical-writer.md`의 전체 내용
- 문서 작성 대상: $ARGUMENTS

**필수 스킬** (트리거 조건 충족 시 반드시 호출):
- `/verify` — 문서 완료 후 검증
- `/audit` — 커밋/PR 전 규칙 검증

**참조 가능 스킬** (문서 작성 중 정확한 패턴 확인 시 Skill 도구로 호출):
- `/fastapi` — 프로젝트 구조, 아키텍처
- `/domain-layer` — 도메인 모델, 레이어 구조
- `/api-design` — API 설계 규칙, 버저닝
- `/sqlalchemy` — DB 모델, 쿼리 패턴
- `/alembic` — 마이그레이션 패턴
- `/pydantic-schema` — DTO 구조
- `/error-handling` — 예외 처리 체계
- `/middleware` — 미들웨어 구성
- `/testing` — 테스트 전략, 구조
- `/background-tasks` — 비동기 작업, Celery 패턴
- `/websocket` — WebSocket, 실시간 통신
- `/docker` — 인프라 구성 패턴
- `/cicd` — CI/CD 파이프라인
- `/monitoring` — 모니터링, 로깅
- `/environment` — 환경변수, 설정
- `/security-audit` — 보안 패턴, 인증
- `/production-checklist` — 운영 체크리스트
