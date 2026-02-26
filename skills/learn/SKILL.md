---
name: learn
description: |
  Use when: 문제 해결 후, 디버깅 성공, 패턴 발견, 기억해둘 것,
  나중에 또 나올 수 있는, 해결했다, 찾았다, root cause 발견.
  NOT for: 일반 지식, 공식 문서에 있는 내용, 단순 오타.
---

# Learn

디버깅으로 얻은 인사이트와 프로젝트 고유 지식을 향후 세션을 위해 기록합니다.

## 저장 기준

네 가지 조건을 **모두** 충족해야 합니다. 하나라도 실패하면 저장하지 마세요.

1. **검색 불가**: 5분 내 구글링으로 찾을 수 없는 내용
2. **프로젝트 고유**: 이 코드베이스, 설정, 환경에 고유한 내용
3. **어렵게 얻은**: 실제 디버깅 노력이나 여러 번의 시도가 필요했던 내용
4. **실행 가능**: 특정 파일, 라인, 명령어, 설정값을 포함하는 내용

## 저장해야 하는 것

- 이 프로젝트 고유의 버그 패턴 (예: "Y 설정이 없으면 X가 조용히 실패")
- 설정 특이사항 및 환경별 함정
- 아키텍처 결정과 그 근거
- 의존성 우회 방법 및 버전 비호환성
- 모듈 간 비직관적인 상호작용
- 프로파일링으로 발견한 성능 함정

## 저장하지 않을 것

- 일반적인 프로그래밍 지식 (async/await 작동 방식)
- 표준 라이브러리 사용법 (datetime 포매팅)
- 공식 문서에서 찾을 수 있는 내용
- 일회성 오타 또는 복사-붙여넣기 실수
- 명백한 수정 (누락된 import, 잘못된 변수명)

## 저장 위치

경로: `~/.claude/projects/<project>/memory/`

인사이트를 설명하는 의미 있는 파일명을 사용하세요:
- `sqlalchemy-async-session-leak.md`
- `docker-compose-volume-permission.md`
- `celery-retry-backoff-config.md`

## 형식

```markdown
---
learned: YYYY-MM-DD
tags: [relevant, searchable, tags]
severity: high | medium | low
---

## Problem
[Exact error message or symptom. Include file paths.]

## Root Cause
[Why it happened. Be specific about the mechanism.]

## Solution
[Exact code change, config change, or command that fixes it.]

## Prevention
[How to avoid hitting this again. CI check, lint rule, or pattern to follow.]
```

## 품질 게이트

저장하기 전에 확인하세요:
- 누군가의 디버깅 시간을 30분 이상 절약할 수 있는가?
- 수정 방법뿐만 아니라 근본 원인이 명확하게 설명되었는가?
- 파일 경로와 코드 스니펫이 포함되었는가?

모두 예라면 저장하세요. 아니라면 폐기하세요.
