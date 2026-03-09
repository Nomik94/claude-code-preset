---
name: confidence-check
description: |
  구현 전 신뢰도 평가. 구현 시작 전에 자동 실행.
  Use when: 구현, 만들어줘, 추가해줘, implement, create, add, 개발해줘, 코드 작성.
  NOT for: 단순 오타 수정, 주석 추가, 포맷팅.
---

# Confidence Check

구현 시작 전 자동 실행. 90% 이상이면 진행, 미만이면 부족한 부분 먼저 해결.

## Checklist

### 1. 요구사항 이해 (25%)
- [ ] 무엇을 만드는지 명확한가?
- [ ] 입력/출력이 정의되어 있는가?
- [ ] 엣지 케이스를 파악했는가?

### 2. 아키텍처 준수 (25%)
- [ ] 어느 레이어에 코드가 들어가는지 알고 있는가?
- [ ] Folder-first: controllers/, dto/, exceptions/, constants/는 처음부터 폴더로 생성하는가?
- [ ] domain/ 에 framework import가 없는가?
- [ ] Repository Protocol을 사용하는가?

### 3. 기존 코드 확인 (25%)
- [ ] 중복 구현이 아닌가?
- [ ] 기존 패턴/컨벤션을 따르는가?
- [ ] 영향받는 파일을 파악했는가?

### 4. 기술적 확신 (25%)
- [ ] 사용할 라이브러리/API를 알고 있는가?
- [ ] 공식 문서를 확인했는가? (Context7)
- [ ] 테스트 방법을 알고 있는가?

## Score

| Score | Action |
|-------|--------|
| >=90% | 진행 |
| 70-89% | 부족한 항목 먼저 해결 후 진행 |
| <70% | 추가 정보 요청 (AskUserQuestion) |

## Output Format
"Confidence: XX% -- [부족한 항목 요약]. 진행/해결 필요."
