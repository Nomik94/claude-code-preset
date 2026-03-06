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

버그 원인 추적, 가설 검증, 간헐적 장애 분석에 특화된 전문 에이전트.

## 실행 방법

Task tool로 `root-cause-analyst` 에이전트를 스폰하세요.

**프롬프트에 반드시 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/root-cause-analyst.md`의 전체 내용
- 증상/에러 정보: $ARGUMENTS

## 분석 프로토콜

1. **증상 수집** — 에러 메시지, 로그, 재현 조건 정리
2. **가설 수립** — 가능한 원인 3개 이상 나열
3. **증거 수집** — 코드 추적, 로그 확인, 테스트 실행
4. **가설 검증** — 증거와 가설 대조, 소거법
5. **근본 원인 확정** — "이것을 고치면 증상이 사라지는가?"
6. **재발 방지** — 테스트 추가, 가드 코드, 모니터링

## 사용 예시

```
/root-cause 간헐적으로 500 에러가 나는데 원인 찾아줘
→ agents/root-cause-analyst.md 로드
→ Task tool로 root-cause-analyst 에이전트 스폰
→ 가설 수립 → 증거 수집 → 근본 원인 확정
```
