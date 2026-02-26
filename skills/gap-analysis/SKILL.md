---
name: gap-analysis
description: |
  Use when: 설계 vs 구현 비교, 스펙 검증, 요구사항 충족 확인,
  gap analysis, 구현 빠진 거 없나, 설계대로 했나, match rate.
  NOT for: 코드 품질 리뷰 (code-reviewer 참조).
---

# Gap Analysis

설계 문서 또는 스펙과 실제 구현을 비교하여 불일치를 찾습니다.

## 비교 차원

각 차원을 독립적으로 분석하세요:

### 1. API 표면
- 엔드포인트: 메서드, 경로, 쿼리 파라미터, 요청 바디, 응답 형태
- 상태 코드 및 에러 응답
- 인증 및 인가 요구사항
- Rate Limiting 및 페이지네이션

### 2. 데이터 모델
- 엔티티와 필드 (이름, 타입, nullable, 기본값)
- 관계 (일대일, 일대다, 다대다)
- 인덱스 및 제약 조건
- 마이그레이션과 스키마 설계의 정합성

### 3. 비즈니스 로직
- 핵심 비즈니스 규칙이 올바르게 구현되었는지
- 유효성 검증 규칙이 스펙과 일치하는지
- 엣지 케이스 및 에러 핸들링이 커버되었는지
- 이벤트 흐름 및 사이드 이펙트가 존재하는지

### 4. 컨벤션
- 네이밍 컨벤션 준수 (파일, 함수, 변수, 라우트)
- import 순서 및 모듈 구조
- 에러 응답 형식의 일관성
- 로깅 및 모니터링 패턴

## 점수 산정

각 차원 내 항목에 아래 상태 중 하나를 부여하세요:

| 상태 | 기호 | 의미 |
|------|------|------|
| 일치 | M | 설계대로 정확히 구현됨 |
| 부분 | P | 구현되었으나 불완전하거나 약간 다름 |
| 누락 | - | 설계에 있으나 구현되지 않음 |
| 초과 | + | 구현되었으나 설계에 없음 |

## Match Rate 계산

```
match_rate = (matched_items / total_designed_items) * 100

Partial counts as 0.5
Extra items are noted but do not affect the rate
```

## 임계값

| 비율 | 조치 |
|------|------|
| >= 90% | 완료 보고서로 진행 |
| 70-89% | 반복: 갭 수정 후 재확인 (최대 5회) |
| < 70% | 중단: 계속하기 전에 설계 재검토 필요 |

## 출력 형식

```
## Gap Analysis: [feature name]

### Summary
- Match Rate: XX%
- Iteration: N/5
- Status: PASS / ITERATE / REVIEW_NEEDED

### Dimension Scores
| Dimension | Matched | Partial | Missing | Extra | Score |
|-----------|---------|---------|---------|-------|-------|
| API Surface | 5 | 1 | 0 | 0 | 92% |
| Data Model | 3 | 0 | 1 | 0 | 75% |
| Business Logic | 4 | 2 | 1 | 1 | 71% |
| Conventions | 6 | 0 | 0 | 0 | 100% |

### Gaps Detail
| # | Dimension | Item | Status | Detail |
|---|-----------|------|--------|--------|
| 1 | Data Model | user.role field | Missing | Not in migration |

### Action Items
1. [Concrete fix for each gap]
```
