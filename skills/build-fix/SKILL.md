---
name: build-fix
description: |
  빌드/린트 에러 자동 수정.
  Use when: ruff error, mypy error, TypeError, ImportError, SyntaxError,
  Build failed, tsc error, eslint error, next build failed,
  빌드 실패, 린트 에러, 타입 에러, ModuleNotFoundError.
  NOT for: 런타임 로직 버그, 비즈니스 로직 에러.
---

# Build Fix

빌드/린트 에러 감지 시 자동 실행. 최소 변경으로 근본 원인 수정.

## 원칙

1. **최소 변경**: 에러를 고치기 위한 최소한의 수정만
2. **근본 원인**: 워크어라운드 금지, 실제 원인 수정
3. **재검증**: 수정 후 반드시 해당 검증 재실행

## BE 에러 수정 (pyproject.toml 감지 시)

### 자동 수정 흐름

1. **에러 분류 → 수정 → 재검증**

| 에러 유형 | 자동 수정 |
|----------|----------|
| Ruff lint (`F401` 미사용 import 등) | `poetry run ruff check --fix .` |
| Ruff format (`E501` 줄 길이 등) | `poetry run ruff format .` |
| mypy `missing return` | 반환 타입 추가 |
| mypy `incompatible type` | 타입 힌트 수정 |
| `ModuleNotFoundError` | `poetry add <pkg>` |
| `ImportError` | import 경로 수정 |
| `SyntaxError` | 코드 구문 수정 |

2. **수정 후**: `poetry run ruff check . && poetry run mypy --strict app/`

## FE 에러 수정 (package.json 감지 시)

### 자동 수정 흐름

| 에러 유형 | 자동 수정 |
|----------|----------|
| ESLint error | `pnpm eslint --fix .` |
| Prettier format | `pnpm prettier --write .` |
| tsc type error | 타입 정의 수정 |
| Module not found | `pnpm add <pkg>` 또는 import 경로 수정 |
| next build error | 빌드 설정 또는 코드 수정 |

2. **수정 후**: `pnpm tsc --noEmit && pnpm eslint .`

## 수정 실패 시

자동 수정 불가한 경우:
1. 에러 원인 분석 결과 보고
2. 수정 제안 (코드 스니펫 포함)
3. 사용자 확인 후 수동 수정

## 출력 형식

```
Build Fix: [N errors fixed] [BE/FE]
- [에러 유형]: [수정 내용] (파일:라인)
→ 재검증: [PASS/FAIL]
```

또는

```
Build Fix: [N errors remain] [BE/FE]
- [에러 유형]: [수동 수정 필요 사유]
→ 제안: [수정 방법]
```

자주 발생하는 실수는 이 디렉토리의 gotchas.md를 참조하라.
