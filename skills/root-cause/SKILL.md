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
