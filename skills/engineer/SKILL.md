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

`agents/engineer.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/engineer.md`의 전체 내용
- 설계/구현 요청: $ARGUMENTS
