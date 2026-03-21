# 배포 전략 레퍼런스

## 배포 트리거 전략

| 이벤트 | 대상 | 방식 |
|--------|------|------|
| PR 생성/업데이트 | Preview | 자동 (Vercel/Cloudflare) |
| `main` 브랜치 push | Staging | 자동 배포 |
| `v*` 태그 push | Production | 수동 승인 후 배포 |

## 스테이징 배포 (자동)

```yaml
name: Deploy Staging
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Build & Push BE Image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          tags: registry.example.com/app-backend:staging
          cache-from: type=gha

      - name: Deploy to Staging
        run: |
          # SSH 또는 클라우드 CLI로 배포
          echo "Deploying to staging..."
```

## 프로덕션 배포 (수동 승인)

```yaml
name: Deploy Production
on:
  push:
    tags: ["v*"]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4

      - name: Build & Push BE Image
        uses: docker/build-push-action@v6
        with:
          context: ./backend
          push: true
          tags: |
            registry.example.com/app-backend:${{ github.ref_name }}
            registry.example.com/app-backend:latest

      - name: Deploy to Production
        run: |
          echo "Deploying ${{ github.ref_name }} to production..."
```

## Vercel/Cloudflare 배포 (FE)

### Preview Deploy (PR)

```yaml
# Vercel이 자동 처리 (GitHub 앱 연동)
# 또는 수동 설정:
jobs:
  preview:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
```

### Production Deploy (main)

```yaml
jobs:
  deploy-fe:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: "--prod"
```
