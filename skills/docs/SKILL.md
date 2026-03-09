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
