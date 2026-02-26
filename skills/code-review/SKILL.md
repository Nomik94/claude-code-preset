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

코드/PR 리뷰, 5-카테고리 스코어링, 기술 부채 식별에 특화된 전문 에이전트.

## 실행 방법

Task tool로 `code-reviewer` 에이전트를 스폰하세요.

**프롬프트에 반드시 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.12+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/code-reviewer.md`의 전체 내용
- 리뷰 대상: $ARGUMENTS

## 리뷰 스코어 (5 카테고리)

| 카테고리 | 비중 | 검증 명령어 |
|---------|------|------------|
| Type Hints | 25% | `poetry run mypy --strict app/` |
| Code Quality | 25% | `poetry run ruff check .` |
| Testing | 20% | `poetry run pytest --cov=app` |
| Security | 15% | `poetry run ruff check --select S .` |
| Dependencies | 15% | `poetry check` |

## 심각도 분류

- 🔴 **CRITICAL**: 버그, 보안 취약점, 데이터 손실 → 반드시 수정
- 🟡 **IMPORTANT**: 아키텍처 위반, 성능 이슈 → 강력 권고
- 🟢 **SUGGESTION**: 네이밍 개선, 코드 간결화 → 선택적

## 사용 예시

```
/code-review src/users/
→ agents/code-reviewer.md 로드
→ Task tool로 code-reviewer 에이전트 스폰
→ 5-카테고리 스코어 + 개선 사항 반환
```
