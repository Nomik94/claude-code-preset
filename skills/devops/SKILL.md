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

Docker, CI/CD, 인프라, 배포, 모니터링에 특화된 전문 에이전트.

## 실행 방법

Task tool로 `devops-architect` 에이전트를 스폰하세요.

**프롬프트에 반드시 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/devops-architect.md`의 전체 내용
- 인프라/배포 요구사항: $ARGUMENTS

## 에이전트 역할

- **설계 게이트**: 목표 아키텍처 + 비용 추정 사용자 승인 후 구현 진입
- **CI/CD 파이프라인**: 자동화된 테스트 게이트, 배포 전략, 롤백 판단 기준
- **Infrastructure as Code**: 버전 관리된 재현 가능한 인프라 + 인프라 코드 검증
- **관측 가능성**: 모니터링, 로깅, 알림, 메트릭
- **시크릿 관리**: 환경별 시크릿 방식, 로테이션 정책, 최소 권한
- **컨테이너 오케스트레이션**: Docker, Compose, Kubernetes

## `/docker`, `/cicd` Skill과의 차이

| | `/docker`, `/cicd` | `/devops` |
|---|---|---|
| 타입 | Skill (지식) | Agent (워커 스폰) |
| 동작 | 패턴/템플릿 로드 | 전문 에이전트가 실제 설계 수행 |
| 용도 | 참고용 | 복잡한 인프라 설계/자동화 |

## 사용 예시

```
/devops 프로덕션 CI/CD 파이프라인 설계해줘
→ agents/devops-architect.md 로드
→ Task tool로 devops-architect 에이전트 스폰
→ GitHub Actions + Docker + 모니터링 설계 반환
```
