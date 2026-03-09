---
name: code-review
description: |
  Code Reviewer 에이전트 스폰.
  Use when: /code-review, 코드 리뷰해줘, PR 리뷰, 리뷰해줘,
  코드 품질 점검, 리팩토링 방향, 기술 부채 식별, 코드 스멜.
  NOT for: 단순 포맷팅, 오타 수정.
argument-hint: <파일 경로 또는 PR 번호>
---

# Code Reviewer 에이전트

`agents/code-reviewer.md`를 로드하여 에이전트를 스폰하라.

**프롬프트 필수 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/code-reviewer.md`의 전체 내용
- 리뷰 대상: $ARGUMENTS
