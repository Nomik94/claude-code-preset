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

설계부터 구현까지 — API, DB, 아키텍처, 성능, 보안, 테스트를 아우르는 핵심 에이전트.

## 실행 방법

Task tool로 `engineer` 에이전트를 스폰하세요.

**프롬프트에 반드시 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/engineer.md`의 전체 내용
- 사용자의 구체적 요청 사항: $ARGUMENTS

## 에이전트 역할

- **설계**: API 스펙, DB 스키마, 도메인 예외 정의, 시스템 아키텍처, DDD
- **설계 게이트**: 설계 완료 후 사용자 승인 → 구현 진입
- **구현**: SOLID, 클린 아키텍처, TDD, Python 3.13+
- **성능**: N+1 방지, 캐싱, 프로파일링, 벤치마킹
- **보안**: JWT, RBAC, OWASP Top 10, 입력 검증
- **테스트**: 상황별 테스트 전략 (CRUD→통합 / 도메인 로직→유닛 필수)

## 사용 예시

```
/engineer 주문 시스템 설계하고 구현해줘
→ agents/engineer.md 로드
→ Task tool로 engineer 에이전트 스폰
→ 설계(API+DB) → TDD 구현 → 보안/성능 검증
```
