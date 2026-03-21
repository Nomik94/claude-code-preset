---
name: confidence-check
description: |
  구현 전 신뢰도 평가. 구현 시작 전에 자동 실행.
  Use when: 구현, 만들어줘, 추가해줘, implement, create, add, 개발해줘, 코드 작성.
  NOT for: 단순 오타 수정, 주석 추가, 포맷팅.
---

# Confidence Check

구현 시작 전 자동 실행. 90% 이상이면 진행, 미만이면 부족한 부분 먼저 해결.

## Stack Detection

프로젝트 파일로 체크리스트 자동 결정:
- `pyproject.toml` 존재 → BE 항목 활성
- `package.json` 존재 → FE 항목 활성
- 둘 다 → 전체 활성

## 체크리스트

### 1. 요구사항 이해 (25%)
- [ ] 무엇을 만드는지 명확한가?
- [ ] 입력/출력이 정의되어 있는가?
- [ ] 엣지 케이스를 파악했는가?
- [ ] 완료 기준이 명확한가?

### 2. 아키텍처 준수 (25%)

**BE (pyproject.toml)**
- [ ] 어느 레이어에 코드가 들어가는지 알고 있는가? (controllers → service → repository)
- [ ] Folder-first: controllers/, dto/, exceptions/, constants/는 폴더로 생성하는가?
- [ ] domain/에 framework import가 없는가?
- [ ] lazy="raise" 기본값을 따르는가?

**FE (package.json)**
- [ ] Server Component vs Client Component 구분이 명확한가?
- [ ] 상태관리 전략을 결정했는가? (URL state > Context > Zustand)
- [ ] API 호출 방식을 결정했는가? (Server Actions > Route Handlers > fetch)
- [ ] loading.tsx / error.tsx / not-found.tsx 필요 여부를 확인했는가?

### 3. 기존 코드 확인 (25%)
- [ ] 중복 구현이 아닌가?
- [ ] 기존 패턴/컨벤션을 따르는가?
- [ ] 영향받는 파일을 파악했는가?
- [ ] 재사용 가능한 기존 유틸/훅이 있는가?

### 4. 기술적 확신 (25%)
- [ ] 사용할 라이브러리/API를 알고 있는가?
- [ ] 공식 문서를 확인했는가? (Context7)
- [ ] 테스트 방법을 알고 있는가?
- [ ] 성능/보안 이슈를 검토했는가?

## 점수 판정

| Score | Action |
|-------|--------|
| >= 90% | 진행 |
| 70-89% | 부족한 항목 먼저 해결 후 진행 |
| < 70% | 추가 정보 요청 (사용자에게 질문) |

## 90% 미만 시 해소 절차

1. 불확실 영역 목록 작성
2. 각 영역별 해소 방안 제시:
   - 코드 탐색으로 확인 가능 → 즉시 탐색
   - 문서 확인 필요 → Context7 조회
   - 사용자 결정 필요 → 질문
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
