# nginx 설정 레퍼런스

docker-compose.yml의 nginx 서비스와 함께 사용하는 설정 파일.

## 리버스 프록시 + FE→BE 라우팅

```nginx
upstream backend {
    server app:8000;
}

upstream frontend {
    server frontend:3000;
}

server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1000;

    # API → Backend
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 나머지 → Frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 정적 파일 캐시
    location /_next/static/ {
        proxy_pass http://frontend;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }
}
```

## 파일 배치

```
nginx/
  nginx.conf         # 메인 설정 (위 내용)
  conf.d/            # 추가 server 블록
```

docker-compose.yml의 nginx 볼륨 마운트:
```yaml
volumes:
  - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
  - ./nginx/conf.d:/etc/nginx/conf.d:ro
  - ./certbot/www:/var/www/certbot:ro
  - ./certbot/conf:/etc/letsencrypt:ro
```
