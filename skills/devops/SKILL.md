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

`agents/devops-architect.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/devops-architect.md`의 전체 내용
- 인프라/배포 요구사항: $ARGUMENTS

> `/docker`, `/cicd`는 패턴/템플릿 참조용 Skill. `/devops`는 전문 에이전트가 실제 설계를 수행.
