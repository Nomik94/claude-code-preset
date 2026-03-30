---
name: checkpoint
description: |
  위험한 작업 전 안전 체크포인트 생성.
  Use when: 리팩토링, 삭제, 마이그레이션, 대규모 변경, 위험한 작업,
  파일 삭제, 코어 변경, 스키마 변경, 구조 변경.
  NOT for: 단순 수정, 새 파일 추가, 테스트 추가.
---

# Checkpoint

위험한 작업 전 롤백 지점 생성 및 위험도 평가.

## 트리거 시점

- 3개+ 파일 리팩토링
- 파일/디렉토리 삭제
- DB 마이그레이션 (스키마 변경)
- 대규모 이름 변경
- 핵심 추상화 수정 (기본 클래스, 공유 유틸, 공통 훅)
- 인증/권한 로직 변경
- 빌드/배포/패키지 설정 변경

## 단계

### 1. 위험 평가

| 수준 | 기준 | 예시 |
|------|------|------|
| LOW | 추가 위주, 쉽게 되돌림 | 새 엔드포인트 추가 |
| MEDIUM | 기존 로직 수정, 3-5 파일 | 서비스 리팩토링 |
| HIGH | 브레이킹 체인지, 5+ 파일, 데이터 손실 가능 | 스키마 마이그레이션 |
| CRITICAL | 프로덕션 데이터, 인증, 핵심 인프라 | 컬럼 삭제, 인증 변경 |

### 2. 안전망 생성

```bash
# Git commit (권장)
git add -A && git commit -m "checkpoint: before [description]"

# Git stash (미커밋 실험용)
git stash push -m "checkpoint: before [description]"
```

커밋/스태시 해시를 롤백 참조용으로 기록할 것.

### 3. 사용자 확인

위험 평가 결과 제시: 위험 수준, 영향 파일 수, 발생 가능 문제, 롤백 명령어.

**MEDIUM 이상: 사용자 확인 없이 진행 금지.**

### 4. 완료 후 검증

| Stack | 검증 |
|-------|------|
| BE | `poetry run pytest`, 앱 시작 확인 |
| FE | `pnpm test`, `pnpm build` 성공 확인 |
| 공통 | `git diff`로 의도치 않은 변경 확인 |

## 출력 형식

```
## Checkpoint: [작업 설명]

- Risk: [LOW/MEDIUM/HIGH/CRITICAL]
- Files affected: [count]
- Rollback: `git reset --hard [hash]`
- Confirm: [MEDIUM 이상이면 사용자 확인 대기]
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
