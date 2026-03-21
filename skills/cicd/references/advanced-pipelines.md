# 고급 파이프라인 패턴 레퍼런스

## Matrix Strategy (멀티 버전 테스트)

```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: ["3.13"]
        node-version: ["20", "22"]
        os: [ubuntu-latest]
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
```

## Lighthouse CI 설정

**`frontend/lighthouserc.json`**:

```json
{
  "ci": {
    "collect": {
      "startServerCommand": "pnpm start",
      "url": ["http://localhost:3000"],
      "numberOfRuns": 3
    },
    "assert": {
      "assertions": {
        "categories:performance": ["warn", { "minScore": 0.9 }],
        "categories:accessibility": ["error", { "minScore": 0.9 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }],
        "categories:seo": ["warn", { "minScore": 0.9 }]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

### CI 워크플로우 연동

```yaml
fe-lighthouse:
  name: "FE: Lighthouse CI"
  runs-on: ubuntu-latest
  needs: [fe-build]
  steps:
    - uses: actions/checkout@v4
    - uses: ./.github/actions/setup-fe
    - run: pnpm build
      working-directory: frontend
    - uses: treosh/lighthouse-ci-action@v12
      with:
        configPath: frontend/lighthouserc.json
        uploadArtifacts: true
```

## 캐시 전략

### 캐시 대상 및 키

| 대상 | 경로 | 키 |
|------|------|----|
| Poetry | `~/.cache/pypoetry`, `.venv` | `poetry-{os}-{hash(poetry.lock)}` |
| pnpm store | pnpm store path | 자동 (`setup-node` cache 옵션) |
| Next.js | `.next/cache` | `nextjs-{os}-{hash(pnpm-lock)}-{hash(src)}` |
| Docker layers | GHA cache | `type=gha` (BuildKit) |

### 캐시 크기 관리
- GitHub Actions 캐시 제한: 10GB/리포지토리
- 오래된 캐시 자동 정리: 7일 미사용 시 삭제
- 캐시 키에 lock 파일 해시 포함 → 의존성 변경 시 자동 갱신
