# 애플리케이션 배포 가이드

## 1. 배포 환경 준비

### 1.1 애플리케이션 서버 설정
1. SSH 접속:
```bash
ssh devops@172.16.10.40
```

2. 디렉토리 구조 생성:
```bash
sudo mkdir -p /data/python
sudo mkdir -p /data/logs/python
sudo chown -R devops:devops /data/python /data/logs
```

### 1.2 Docker Compose 설정
/data/python/docker-compose.yml 파일 생성:
```yaml
version: '3.8'

services:
  python-demo:
    image: ${DOCKER_IMAGE}:${DOCKER_TAG}
    container_name: python-demo
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - DEBUG=false
    volumes:
      - /data/logs/python:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app_network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  app_network:
    external: true
```

## 2. Nginx 리버스 프록시 설정

### 2.1 Nginx 설정
/data/nginx/conf.d/python-demo.conf:
```nginx
upstream python_backend {
    server 127.0.0.1:8000;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name python-demo.local;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name python-demo.local;

    ssl_certificate /etc/nginx/ssl/python-demo.local.crt;
    ssl_certificate_key /etc/nginx/ssl/python-demo.local.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # 현대적인 TLS 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS 설정
    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        proxy_pass http://python_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 헬스체크 엔드포인트
    location /health {
        proxy_pass http://python_backend/health;
        access_log off;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Prometheus 메트릭
    location /metrics {
        proxy_pass http://python_backend/metrics;
        auth_basic "Metrics";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

### 2.2 Nginx 컨테이너 실행
/data/nginx/docker-compose.yml:
```yaml
version: '3.8'

services:
  nginx:
    image: nginx:stable
    container_name: nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/nginx/conf.d:/etc/nginx/conf.d
      - /data/nginx/ssl:/etc/nginx/ssl
      - /data/nginx/.htpasswd:/etc/nginx/.htpasswd
    networks:
      - app_network

networks:
  app_network:
    external: true
```

## 3. 배포 자동화

### 3.1 배포 스크립트
/data/python/deploy.sh:
```bash
#!/bin/bash
set -e

# 환경 변수 로드
source .env

# 새 이미지 풀
docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}

# 기존 컨테이너 중지 및 제거
docker-compose down

# 새 컨테이너 시작
docker-compose up -d

# 이전 이미지 정리
docker image prune -f

# 배포 결과 확인
docker-compose ps
curl -f http://localhost:8000/health
```

### 3.2 로그 순환 설정
/etc/logrotate.d/python-demo:
```
/data/logs/python/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 devops devops
    sharedscripts
    postrotate
        docker kill -s SIGUSR1 python-demo
    endscript
}
```

## 4. 모니터링 설정

### 4.1 Prometheus 설정
Prometheus 서버의 /etc/prometheus/conf.d/python-demo.yml:
```yaml
- job_name: 'python-demo'
  metrics_path: '/metrics'
  scheme: 'https'
  tls_config:
    ca_file: /etc/prometheus/certs/ca.crt
  basic_auth:
    username: prometheus
    password: ${METRICS_PASSWORD}
  static_configs:
    - targets: ['python-demo.local']
  relabel_configs:
    - source_labels: [__address__]
      target_label: instance
      replacement: python-demo
```

### 4.2 Grafana 대시보드
1. 새 대시보드 생성:
   - 요청 수/초
   - 응답 시간 분포
   - 오류율
   - CPU/메모리 사용량
   - 디스크 I/O

### 4.3 알림 설정
1. CPU 사용량 80% 초과
2. 메모리 사용량 85% 초과
3. 오류율 1% 초과
4. 디스크 사용량 90% 초과

## 5. 보안 설정

### 5.1 방화벽 설정
```bash
# 필요한 포트만 허용
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 5.2 Docker 보안 설정
/etc/docker/daemon.json:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "userns-remap": "default",
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp-profile.json"
}
```

## 6. 백업 및 복구

### 6.1 데이터 백업
/data/python/backup.sh:
```bash
#!/bin/bash
set -e

BACKUP_DIR="/backup/python-demo"
DATE=$(date +%Y%m%d-%H%M%S)

# 설정 파일 백업
mkdir -p ${BACKUP_DIR}/${DATE}
cp -r /data/python/docker-compose.yml ${BACKUP_DIR}/${DATE}/
cp -r /data/python/.env ${BACKUP_DIR}/${DATE}/

# 로그 백업
tar czf ${BACKUP_DIR}/${DATE}/logs.tar.gz /data/logs/python/

# 오래된 백업 삭제 (30일)
find ${BACKUP_DIR} -type d -mtime +30 -exec rm -rf {} +
```

### 6.2 복구 절차
/data/python/restore.sh:
```bash
#!/bin/bash
set -e

BACKUP_DIR="/backup/python-demo"
RESTORE_DATE=$1

if [ -z "$RESTORE_DATE" ]; then
    echo "Usage: $0 BACKUP_DATE"
    exit 1
fi

# 설정 파일 복구
cp -r ${BACKUP_DIR}/${RESTORE_DATE}/docker-compose.yml /data/python/
cp -r ${BACKUP_DIR}/${RESTORE_DATE}/.env /data/python/

# 로그 복구
tar xzf ${BACKUP_DIR}/${RESTORE_DATE}/logs.tar.gz -C /

# 서비스 재시작
cd /data/python
docker-compose down
docker-compose up -d
```

## 다음 단계
애플리케이션 배포가 완료되면, [모니터링 구성](./09-monitoring-setup.md) 가이드로 진행하세요.