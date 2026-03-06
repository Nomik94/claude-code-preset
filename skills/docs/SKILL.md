---
name: docs
description: |
  Technical Writer 에이전트 스폰.
  Use when: /docs, README 작성해줘, API 문서화, 문서 써줘, 기술 문서,
  ADR 작성, 변경 로그 생성, 온보딩 문서, 사용자 가이드,
  인프라 문서, 시스템 설계 문서, 런북 작성, 아키텍처 문서.
  NOT for: 코드 주석 추가, 단순 docstring 작성.
argument-hint: <문서 유형 또는 대상>
---

# Technical Writer 에이전트

README, ADR, API 문서, 시스템 설계 문서, 인프라 문서, 런북, 변경 로그에 특화된 전문 에이전트.

## 실행 방법

Task tool로 `technical-writer` 에이전트를 스폰하세요.

**프롬프트에 반드시 포함**:
- `CONTEXT: WORKER agent. STACK: Python 3.13+/FastAPI/SQLAlchemy 2.0/Poetry`
- `agents/technical-writer.md`의 전체 내용
- 문서 작성 대상: $ARGUMENTS

## 에이전트 역할

- **코드 분석 기반 문서화**: 코드를 직접 읽고 사실에 기반한 문서 작성
- **인프라 분석**: Dockerfile, compose, CI/CD, Alembic 분석 후 문서화
- **독자 맞춤**: 신규 개발자 vs 시니어 vs 운영팀 구분
- **Mermaid 다이어그램**: 아키텍처, 시퀀스, ERD 시각화

## 문서 유형

| 유형 | 설명 |
|------|------|
| README.md | 프로젝트 소개, 설치, 사용법 |
| ADR | 아키텍처 결정 배경, 대안, 결과 |
| 시스템 설계 문서 | 아키텍처, 도메인 모델, API, 데이터 모델 |
| API Docs | OpenAPI/Swagger 기반 + 사용 시나리오 |
| 인프라 문서 | Docker, CI/CD, 환경 변수, DB 스키마 |
| 런북 | 장애 대응 절차 (증상→진단→복구) |
| CHANGELOG.md | Keep a Changelog 형식 |
| 온보딩 문서 | 신규 개발자 첫날 가이드 |

## 코드 분석 명령어

### 구조 분석
```bash
# 엔드포인트 목록
rg "@router\.(get|post|put|delete|patch)" --type py

# 도메인 모델 추출
rg "class.*\(Base\)|class.*Entity|class.*ValueObject" --type py

# 환경 변수 추출
rg "env\(|getenv|Field\(.*env=" --type py
```

### 흐름 분석
```bash
# Import 관계 추적
rg "from app\." --type py | sort

# 미들웨어 등록 순서
rg "add_middleware|app\.middleware" --type py

# 에러 핸들러 매핑
rg "exception_handler|ExceptionHandler" --type py
```

## 사용 예시

```
/docs README 작성해줘
→ agents/technical-writer.md 로드
→ Task tool로 technical-writer 에이전트 스폰
→ 코드 분석 → README.md 생성
```
