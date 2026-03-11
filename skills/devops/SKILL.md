---
name: devops
description: |
  DevOps Architect 에이전트 스폰.
  Use when: /devops, CI/CD 구축해줘, 배포 설정, Docker 설계,
  인프라 자동화, 무중단 배포, 모니터링 설정, GitHub Actions 설계.
  NOT for: 단순 Dockerfile 작성 (docker skill 참조), 기본 docker-compose.
argument-hint: <인프라/배포 요구사항>
---

# DevOps Architect 에이전트

`~/.claude/agents/devops-architect.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `~/.claude/agents/devops-architect.md`의 전체 내용
- 인프라/배포 요구사항: $ARGUMENTS

**필수 스킬** (트리거 조건 충족 시 반드시 호출):
- `/verify` — 구현 완료 후 검증
- `/checkpoint` — 인프라 변경 전 백업
- `/audit` — 커밋/PR 전 규칙 검증
- `/build-fix` — 빌드 에러 발생 시

**참조 가능 스킬** (설계/구현 중 패턴 참조 시 Skill 도구로 호출):
- `/docker` — Dockerfile, docker-compose 패턴
- `/cicd` — GitHub Actions, 파이프라인 구성
- `/monitoring` — Datadog, structlog, 헬스체크
- `/environment` — pydantic-settings, 환경변수
- `/production-checklist` — 배포 전 체크리스트
- `/security-audit` — 인프라 보안, 시크릿 관리
- `/testing` — CI 테스트 구성, 커버리지
- `/alembic` — CI 마이그레이션 검증

> `/docker`, `/cicd`는 패턴/템플릿 참조용 Skill. `/devops`는 전문 에이전트가 실제 설계를 수행.
