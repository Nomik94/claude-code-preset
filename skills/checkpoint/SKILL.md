---
name: checkpoint
description: |
  위험한 작업 전 안전 체크포인트 생성.
  Use when: 리팩토링, 삭제, 마이그레이션, 대규모 변경, 위험한 작업,
  파일 삭제, 코어 변경, 스키마 변경, 구조 변경.
  NOT for: 단순 수정, 새 파일 추가, 테스트 추가.
---

# Checkpoint

위험한 작업 전 안전 체크포인트. 롤백 지점을 생성하고 진행 전 위험도를 평가.

## 트리거 시점

다음 작업 전에 활성화:

- 3개 이상 파일에 영향을 미치는 리팩토링
- 파일 또는 디렉토리 삭제
- 데이터베이스 마이그레이션 (스키마 변경)
- 대규모 이름 변경 (함수, 클래스, 모듈, 컴포넌트)
- 핵심 추상화 수정 (기본 클래스, 공유 유틸리티, 공통 훅)
- 인증 또는 권한 부여 로직 변경
- 빌드 또는 배포 설정 변경
- 패키지 매니저 설정 변경 (pyproject.toml, package.json)

## 단계

### 1. 위험 평가

| 수준 | 기준 | 예시 |
|------|------|------|
| LOW | 추가 위주 변경, 쉽게 되돌림 | 새 엔드포인트/페이지 추가 |
| MEDIUM | 기존 로직 수정, 3-5개 파일 | 서비스 리팩토링, 컴포넌트 분리 |
| HIGH | 브레이킹 체인지, 5개 초과 파일, 데이터 손실 가능 | 스키마 마이그레이션, 라우팅 구조 변경 |
| CRITICAL | 프로덕션 데이터, 인증, 핵심 인프라 | 컬럼 삭제, 인증 방식 변경 |

### 2. 안전망 생성

변경 전에 다음을 수행:

```bash
# Option A: Git commit (권장)
git add -A && git commit -m "checkpoint: before [description]"

# Option B: Git stash (미커밋 실험용)
git stash push -m "checkpoint: before [description]"
```

롤백 참조용으로 커밋 또는 스태시 해시를 기록.

### 3. 사용자 확인

위험 평가 결과를 제시하고 명시적 확인 요청:

- 위험 수준 및 근거
- 영향받는 파일 수
- 발생 가능한 문제
- 롤백 계획 (되돌리기 위한 정확한 명령어)

**MEDIUM 이상에서는 사용자 확인 없이 절대 진행 금지.**

### 4. 완료 후 검증

작업 성공 여부 확인:

| Stack | 검증 |
|-------|------|
| BE | `poetry run pytest` 실행, 앱 시작 확인 |
| FE | `pnpm test` 실행, `pnpm build` 성공 확인 |
| 공통 | `git diff`로 의도하지 않은 변경 없는지 확인 |

## 출력 형식

```
## Checkpoint: [작업 설명]

- Risk: [LOW/MEDIUM/HIGH/CRITICAL]
- Files affected: [count]
- Rollback: `git reset --hard [hash]`
- Confirm: [MEDIUM 이상이면 사용자 확인 대기]
```
