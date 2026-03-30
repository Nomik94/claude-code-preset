---
name: confidence-check
description: |
  구현 전 신뢰도 평가. 구현 시작 전에 자동 실행.
  Use when: 구현, 만들어줘, 추가해줘, implement, create, add, 개발해줘, 코드 작성.
  NOT for: 단순 오타 수정, 주석 추가, 포맷팅.
---

# Confidence Check

구현 시작 전 자동 실행. 90% 이상이면 진행, 미만이면 부족한 부분 먼저 해결.

> Stack Detection: CLAUDE.md 규칙에 따라 자동 결정됨.

## 체크리스트

### 1. 요구사항 이해 (25%)
- [ ] 무엇을 만드는지 명확한가?
- [ ] 입력/출력 정의 완료?
- [ ] 엣지 케이스 파악 완료?
- [ ] 완료 기준 명확한가?

### 2. 아키텍처 준수 (25%)

**BE (pyproject.toml)**
- [ ] 코드가 들어갈 레이어 파악? (controllers → service → repository)
- [ ] Folder-first 준수?
- [ ] domain/에 framework import 없는가?
- [ ] lazy="raise" 기본값 준수?

**FE (package.json)**
- [ ] Server/Client Component 구분 명확?
- [ ] 상태관리 전략 결정? (URL state > Context > Zustand)
- [ ] API 호출 방식 결정? (Server Actions > Route Handlers > fetch)
- [ ] loading/error/not-found 필요 여부 확인?

### 3. 기존 코드 확인 (25%)
- [ ] 중복 구현 아닌가?
- [ ] 기존 패턴/컨벤션 준수?
- [ ] 영향받는 파일 파악?
- [ ] 재사용 가능한 유틸/훅 존재?

### 4. 기술적 확신 (25%)
- [ ] 사용할 라이브러리/API 파악?
- [ ] 공식 문서 확인? (Context7)
- [ ] 테스트 방법 파악?
- [ ] 성능/보안 이슈 검토?

## 점수 판정

| Score | Action |
|-------|--------|
| >= 90% | 진행 |
| 70-89% | 부족 항목 해결 후 진행 |
| < 70% | 사용자에게 추가 정보 요청 |

## 90% 미만 시 해소 절차

1. 불확실 영역 목록 작성
2. 해소 방안: 코드 탐색 → Context7 조회 → 사용자 질문
3. 해소 후 재평가

## 출력 형식

```
Confidence: XX% [BE/FE/Fullstack]
- 요구사항 이해: XX% -- [상세]
- 아키텍처 준수: XX% -- [상세]
- 기존 코드 확인: XX% -- [상세]
- 기술적 확신: XX% -- [상세]
→ [진행 / 해결 필요: 불확실 항목 요약]
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
