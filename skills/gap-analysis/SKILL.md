---
name: gap-analysis
description: |
  설계 vs 구현 비교 분석 및 Match Rate 산출.
  Use when: 설계 vs 구현 비교, 스펙 검증, 요구사항 충족 확인,
  gap analysis, 구현 빠진 거 없나, 설계대로 했나, match rate.
  NOT for: 코드 품질 리뷰 (reviewer 에이전트 참조).
---

# Gap Analysis

설계/스펙 vs 실제 구현 비교, 불일치 탐지.

## 기준 문서 우선순위

1. `docs/specs/{feature}.spec.md` (LOCKED) — 최우선
2. 설계 문서 (architect 산출물)
3. PRD (planner 산출물)
4. 사용자 직접 제공 요구사항

스펙 있으면 §3(시나리오), §4(입출력), §5(스코프), §7(Constitution) 기준 비교.

## 비교 차원

### 1. API 표면

| 항목 | BE | FE |
|------|----|----|
| 엔드포인트 | 메서드/경로/파라미터/요청응답 | API 호출 스펙 일치 |
| 상태 코드 | 에러 응답 형식 | 에러 UI |
| 인증/인가 | JWT, RBAC | 인증 상태, 보호 라우트 |
| 페이지네이션 | 커서/오프셋 | 무한 스크롤/페이지 UI |

### 2. 데이터 모델

| 항목 | BE | FE |
|------|----|----|
| 엔티티/필드 | 이름/타입/nullable/기본값 | TS 인터페이스 일치 |
| 관계 | 1:1, 1:N, N:M | 중첩 데이터 구조 |
| 제약 | DB 제약 조건 | 클라이언트 유효성 검증 |
| 마이그레이션 | Alembic 정합성 | - |

### 3. 비즈니스 로직
- 핵심 규칙 구현 여부, 유효성 검증 일치
- 엣지 케이스/에러 핸들링 커버리지, 이벤트/사이드 이펙트

### 4. 컨벤션
- BE: snake_case, Folder-first, 에러 응답 일관성, structlog
- FE: camelCase/PascalCase, App Router, 에러 UI, 에러 바운더리

## 상태 분류

| 상태 | 기호 | 의미 |
|------|------|------|
| 일치 | M | 설계대로 구현 |
| 부분 | P | 불완전/약간 다름 |
| 누락 | - | 설계에 있으나 미구현 |
| 초과 | + | 설계에 없으나 구현됨 |

## Match Rate

```
match_rate = (matched + partial * 0.5) / total_designed_items * 100
초과 항목은 비율 무영향, 정당성 검토 필수
```

| 비율 | 조치 |
|------|------|
| >= 90% | 완료 보고서 |
| 70-89% | 갭 수정 후 재확인 (최대 5회) |
| < 70% | 중단, 설계 재검토 |

## Missing vs Excess

**Missing**: 목록 + 심각도 (critical → 즉시 / major → 이번 / minor → 다음)
**Excess**: 목록 + 정당성 (정당 → 설계 업데이트 / 부당 → 제거)

## 출력 형식

```
## Gap Analysis: [feature]

### Summary
- Match Rate: XX% / Iteration: N/5 / Status: PASS|ITERATE|REVIEW_NEEDED
- Spec: docs/specs/{feature}.spec.md (LOCKED) | 없음

### Dimension Scores
| Dimension | M | P | - | + | Score |

### Missing (구현 필요)
| # | Dimension | Item | Severity | Detail |

### Excess (설계에 없음)
| # | Dimension | Item | Justified | Detail |

### Action Items
### Spec Update Needed
```

## 완료 시

Match Rate >= 90% + 갭 해소 → 스펙 Status를 `IMPLEMENTED`로 변경.

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
