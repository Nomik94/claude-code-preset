# docker-compose 고급 패턴 레퍼런스

## 환경별 Override 패턴

### docker-compose.dev.yml (개발)

```yaml
services:
  app:
    build:
      target: builder
    volumes:
      - ./backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    environment:
      - APP_ENV=development

  frontend:
    volumes:
      - ./frontend:/app
      - /app/node_modules
    command: pnpm dev
    environment:
      - NODE_ENV=development

  db:
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"
```

### docker-compose.prod.yml (프로덕션)

```yaml
services:
  app:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  frontend:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
```

### 실행 방법

```bash
# 개발
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# 프로덕션
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 네트워크 분리 패턴

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

- **frontend**: nginx ↔ frontend (외부 접근)
- **backend**: app ↔ db ↔ redis (내부 통신)
- nginx는 양쪽 네트워크 연결 (리버스 프록시)
