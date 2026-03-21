---
name: gap-analysis
description: |
  설계 vs 구현 비교 분석 및 Match Rate 산출.
  Use when: 설계 vs 구현 비교, 스펙 검증, 요구사항 충족 확인,
  gap analysis, 구현 빠진 거 없나, 설계대로 했나, match rate.
  NOT for: 코드 품질 리뷰 (reviewer 에이전트 참조).
---

# Gap Analysis

설계 문서 또는 스펙과 실제 구현을 비교하여 불일치를 찾음.

## 비교 차원

각 차원을 독립적으로 분석.

### 1. API 표면

| 항목 | BE | FE |
|------|----|----|
| 엔드포인트 | 메서드, 경로, 파라미터, 요청/응답 | API 호출 코드와 스펙 일치 |
| 상태 코드 | 에러 응답 형식 | 에러 핸들링 UI |
| 인증/인가 | JWT, RBAC 구현 | 인증 상태 관리, 보호 라우트 |
| 페이지네이션 | 커서/오프셋 구현 | 무한 스크롤/페이지 UI |

### 2. 데이터 모델

| 항목 | BE | FE |
|------|----|----|
| 엔티티/필드 | 이름, 타입, nullable, 기본값 | TypeScript 인터페이스 일치 |
| 관계 | 1:1, 1:N, N:M | 중첩 데이터 구조 |
| 인덱스/제약 | DB 제약 조건 | 클라이언트 유효성 검증 |
| 마이그레이션 | Alembic과 스키마 정합성 | - |

### 3. 비즈니스 로직

- 핵심 비즈니스 규칙 구현 여부
- 유효성 검증 규칙 스펙 일치
- 엣지 케이스 및 에러 핸들링 커버리지
- 이벤트 흐름 및 사이드 이펙트

### 4. 컨벤션

| 항목 | BE | FE |
|------|----|----|
| 네이밍 | snake_case (파일/변수/함수) | camelCase/PascalCase |
| 구조 | Folder-first, 레이어 분리 | App Router 구조, 컴포넌트 분리 |
| 에러 형식 | 일관된 에러 응답 | 일관된 에러 UI |
| 로깅 | structlog 패턴 | 에러 바운더리 패턴 |

## 상태 분류

| 상태 | 기호 | 의미 |
|------|------|------|
| 일치 | M | 설계대로 정확히 구현됨 |
| 부분 | P | 구현되었으나 불완전하거나 약간 다름 |
| 누락 | - | 설계에 있으나 구현되지 않음 (Missing) |
| 초과 | + | 구현되었으나 설계에 없음 (Excess) |

## Match Rate 계산

```
match_rate = (matched + partial * 0.5) / total_designed_items * 100

초과 항목은 비율에 영향 없으나 정당성 검토 필수
```

## 임계값

| 비율 | 조치 |
|------|------|
| >= 90% | 완료 보고서로 진행 |
| 70-89% | 반복: 갭 수정 후 재확인 (최대 5회) |
| < 70% | 중단: 설계 재검토 필요 |

## Missing vs Excess 처리

### Missing (구현 안 된 설계)
- 목록 작성 + 각 항목 심각도 (critical/major/minor)
- critical: 핵심 기능 누락 → 즉시 구현
- major: 중요 기능 누락 → 이번 이터레이션에 구현
- minor: 부가 기능 누락 → 다음 이터레이션 가능

### Excess (설계에 없는 구현)
- 목록 작성 + 정당성 검토
- 정당: 설계 업데이트 (보안, 에러 핸들링 등)
- 부당: 제거 또는 스코프 논의

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

### Missing (구현 필요)
| # | Dimension | Item | Severity | Detail |
|---|-----------|------|----------|--------|
| 1 | Data Model | user.role | critical | 마이그레이션에 없음 |

### Excess (설계에 없음)
| # | Dimension | Item | Justified | Detail |
|---|-----------|------|-----------|--------|
| 1 | API | /health endpoint | yes | 운영 필수 |

### Action Items
1. [각 갭에 대한 구체적 수정 사항]
```
