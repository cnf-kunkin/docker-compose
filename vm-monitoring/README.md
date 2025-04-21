<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# Ubuntu 24에 Prometheus-Grafana 기반 시스템 메트릭 모니터링 구축 가이드

## 서론

시스템 메트릭 수집과 시각화는 인프라 관리의 핵심 요소로, 서버의 건강 상태를 실시간으로 파악하고 장애 발생 시 신속한 대응을 가능하게 합니다. 본 가이드는 오픈소스 모니터링 도구인 Prometheus와 시각화 도구 Grafana를 Docker Compose로 통합 구축하는 방법을 단계별로 설명합니다.

Prometheus는 다차원 데이터 모델과 강력한 쿼리 언어(PromQL)를 제공하는 메트릭 수집 시스템이며, Grafana는 이를 기반으로 대시보드를 구성해 시각화하는 도구입니다. Docker Compose를 사용하면 복잡한 구성 요소를 단일 명령어로 관리할 수 있어 유지보수가 용이합니다.

## 사전 준비

### 시스템 요구사항

- Ubuntu 24.04 LTS (커널 6.8 이상)
- CPU: 2코어 이상
- 메모리: 4GB 이상
- 디스크: 20GB 이상 여유 공간

### 디렉토리 구조 생성

```bash
sudo mkdir -p /data/docker-compose/prometheus/conf/
sudo vi /data/docker-compose/prometheus/conf/prometheus.yml
### Prometheus 설정 파일 (prometheus.yml)

```yaml
global:
  scrape_interval: 15s  # 데이터 수집 주기
  evaluation_interval: 15s  # 규칙 평가 주기

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']  # Prometheus 자체 모니터링

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']  # Node Exporter 엔드포인트
    metrics_path: /metrics
```



## SSL 인증서 생성

먼저 Subject Alternative Name (SAN)을 포함한 SSL 인증서를 생성하기 위한 설정 파일을 만듭니다:

```bash
# SSL 인증서 디렉토리 생성
sudo mkdir -p /data/docker-compose/nginx/ssl
cd /data/docker-compose/nginx/ssl


# 개인키 생성
openssl genrsa -out prometheus.local.key 2048

# CSR(Certificate Signing Request) 생성
openssl req -new -key prometheus.local.key -out prometheus.local.csr -subj "/CN=prometheus.local/O=SonarQube/C=KR"

# 자체 서명된 인증서 생성
openssl x509 -req -days 3650 -in prometheus.local.csr -signkey prometheus.local.key -out prometheus.local.crt


# 개인키 생성
openssl genrsa -out grafana.local.key 2048

# CSR(Certificate Signing Request) 생성
openssl req -new -key grafana.local.key -out grafana.local.csr -subj "/CN=grafana.local/O=SonarQube/C=KR"

# 자체 서명된 인증서 생성
openssl x509 -req -days 3650 -in grafana.local.csr -signkey grafana.local.key -out grafana.local.crt



```

### Nginx 설정 파일 생성

/data/docker-compose/nginx/conf/default.conf 파일을 생성하고 다음 내용을 추가합니다:

sudo mkdir -p /data/docker-compose/nginx/conf
cd /data/docker-compose/nginx/conf


sudo vi /data/docker-compose/nginx/conf/prometheus.conf


다음 내용을 추가합니다:

```nginx
# HTTP를 HTTPS로 리다이렉트
server {
    listen 80;
    server_name prometheus.local;
    return 301 https://$host$request_uri;
}

# HTTPS 서버 설정
server {
    listen 443 ssl;
    server_name prometheus.local;

    ssl_certificate /etc/nginx/ssl/prometheus.local.crt;
    ssl_certificate_key /etc/nginx/ssl/prometheus.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/prometheus.access.log;
    error_log /var/log/nginx/prometheus.error.log;

    location / {
        proxy_pass http://prometheus:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 지원
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 타임아웃 설정
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
    }
}
```


sudo vi /data/docker-compose/nginx/conf/grafana.conf


다음 내용을 추가합니다:

```nginx
# HTTP를 HTTPS로 리다이렉트
server {
    listen 80;
    server_name grafana.local;
    return 301 https://$host$request_uri;
}

# HTTPS 서버 설정
server {
    listen 443 ssl;
    server_name grafana.local;

    ssl_certificate /etc/nginx/ssl/grafana.local.crt;
    ssl_certificate_key /etc/nginx/ssl/grafana.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/grafana.access.log;
    error_log /var/log/nginx/grafana.error.log;

    location / {
        proxy_pass http://grafana:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 지원
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 타임아웃 설정
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
    }
}


```



sudo chmod -R 777 /data

```


## Docker Compose 설정

sudo vi /data/docker-compose/docker-compose.yml
### docker-compose.yml 파일 구성

```yaml
version: '3.8'

services:
  # Nginx 리버스 프록시
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/docker-compose/nginx/conf:/etc/nginx/conf.d
      - /data/docker-compose/nginx/ssl:/etc/nginx/ssl
      - /data/nginx/logs:/var/log/nginx      
    networks:
      - monitoring
    depends_on:
      - grafana
      - prometheus

  # 메트릭 수집기
  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node-exporter
    restart: always
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'
    ports:
      - "9100:9100"
    networks:
      - monitoring

  # 메트릭 저장소
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    volumes:
      - /data/prometheus/data:/prometheus
      - /data/prometheus/rules:/etc/prometheus/rules
      - /data/docker-compose/prometheus/conf/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
    ports:
      - "9090:9090"
    networks:
      - monitoring
    depends_on:
      - node-exporter

  # 시각화 도구
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    volumes:
      - /data/grafana/data:/var/lib/grafana
      - /data/grafana/provisioning:/etc/grafana/provisioning
      - /data/grafana/dashboards:/var/lib/grafana/dashboards      
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    ports:
      - "3000:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

networks:
  monitoring:
    driver: bridge
```


### 컨테이너 재시작

설정을 적용하기 위해 컨테이너를 재시작합니다:

```bash
sudo chmod -R 777 /data
docker-compose up -d
docker-compose logs -f
docker-compose logs -f prometheus

docker-compose down
```

이제 다음 URL로 접속할 수 있습니다:
- Grafana: https://grafana.local
- Prometheus: https://prometheus.local

참고: 자체 서명 인증서를 사용하므로 브라우저에서 보안 경고가 표시될 수 있습니다. 개발 환경에서는 이 경고를 무시하고 진행할 수 있습니다.

## 시스템 메트릭 수집기 설정

### Node Exporter 실행 검증

```bash
curl http://localhost:9100/metrics
```

출력에 `node_cpu_seconds_total` 등의 메트릭이 표시되면 정상 작동

## 외부 서버 Node Exporter 추가 가이드

다른 서버에서 실행 중인 어플리케이션의 메트릭을 수집하려면 해당 서버에 Node Exporter를 추가하고 Prometheus 설정을 업데이트해야 합니다.

### 1. 외부 서버의 docker-compose.yml 수정

기존 docker-compose.yml 파일에 node-exporter 서비스를 추가합니다:

```yaml
services:
  # 기존 서비스들...
  
  # Node Exporter 추가
  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node-exporter
    restart: always
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - '--path.rootfs=/host'
    ports:
      - "9100:9100"  # 호스트의 9100 포트를 외부에 노출
    networks:
      - your_existing_network  # 기존 네트워크 이름으로 변경

networks:
  your_existing_network:
    external: false
```

### 2. Prometheus 설정 업데이트

중앙 모니터링 서버의 prometheus.yml 파일에 새로운 타겟을 추가합니다:

```yaml
scrape_configs:
  # 기존 설정...

  - job_name: 'node-exporter-external'
    static_configs:
      - targets: ['외부서버IP:9100']  # 외부 서버의 IP 주소와 포트
        labels:
          instance: '서버이름'  # 식별하기 쉬운 서버 이름
```

### 3. 외부 서버 방화벽 설정

Node Exporter의 포트를 외부에서 접근 가능하도록 설정:

```bash
sudo ufw allow 9100/tcp
```

### 4. 연결 테스트

중앙 모니터링 서버에서 외부 Node Exporter 연결 테스트:

```bash
curl http://외부서버IP:9100/metrics
```

### 5. Prometheus 재시작

설정 변경을 적용하기 위해 Prometheus 서비스 재시작:

```bash
docker-compose restart prometheus
```

### 6. 확인

1. Prometheus UI (Status > Targets)에서 새로 추가된 타겟 상태가 UP인지 확인
2. 다음 PromQL로 메트릭 수집 확인:
   - `up{job="node-exporter-external"}`
   - `node_cpu_seconds_total{instance="서버이름"}`

### 주의사항

1. 보안을 위해 가능하면 VPN이나 프라이빗 네트워크를 통해 메트릭을 수집
2. Node Exporter 포트(9100)는 신뢰할 수 있는 IP에서만 접근 가능하도록 제한
3. 필요한 경우 TLS를 설정하여 암호화된 통신 사용

### 문제 해결

1. 연결이 안 되는 경우:
   - 방화벽 설정 확인
   - Docker 네트워크 설정 확인
   - Node Exporter 컨테이너 로그 확인
   
2. 메트릭이 수집되지 않는 경우:
   - Prometheus 타겟 상태 확인
   - 네트워크 지연시간 체크
   - scrape_interval 조정 고려

## Grafana 초기 설정

### 웹 접속 및 로그인

1. 브라우저에서 `http://:3000` 접속
2. 초기 계정: admin / admin123

### 데이터 소스 추가

1. 좌측 메뉴 → Configuration → Data Sources
2. Prometheus 선택
3. URL: `http://prometheus:9090`
4. Save \& Test 클릭 → "Data source is working" 확인

### 대시보드 생성 예시

```json
{
  "title": "시스템 모니터링",
  "panels": [
    {
      "type": "graph",
      "title": "CPU 사용량",
      "targets": [{
        "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
        "legendFormat": "{{instance}}"
      }],
      "yaxes": [{"format": "percent"}]
    },
    {
      "type": "stat",
      "title": "메모리 사용량",
      "targets": [{
        "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
        "legendFormat": "사용률"
      }],
      "options": {"reduceOptions": {"calcs": ["last"]}}
    }
  ]
}
```


## 아키텍처 다이어그램

### 시스템 구성도

```
+----------------+       +-------------+       +-----------+
|                |       |             |       |           |
| Node Exporter  +------&gt;+ Prometheus  +------&gt;+ Grafana   |
| (호스트 메트릭) |       | (저장/쿼리)  |       | (시각화)   |
+----------------+       +-------------+       +-----------+
```


### 데이터 흐름

1. Node Exporter: 호스트의 CPU, 메모리, 디스크 사용량 수집 (9100 포트)
2. Prometheus: 15초 주기로 Node Exporter에서 메트릭 수집 (9090 포트)
3. Grafana: Prometheus의 데이터를 시각화하여 대시보드 제공 (3000 포트)

## 방화벽 설정

```bash
# HTTP 및 HTTPS 포트 개방
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 문제 해결 가이드

### Prometheus 타겟 연결 실패

```bash
# 대상 서비스 상태 확인
docker ps | grep exporter

# 로그 확인
docker logs node-exporter

# 네트워크 연결 테스트
docker exec prometheus curl -v http://node-exporter:9100/metrics
```


### Grafana 데이터 소스 오류

1. Data Source 설정에서 URL 확인
2. Prometheus 컨테이너 로그 확인: `docker logs prometheus`
3. 방화벽 규칙 확인:
```bash
sudo ufw allow 9090/tcp
sudo ufw allow 3000/tcp
```


## 결론

본 가이드를 통해 Ubuntu 24 환경에 Prometheus-Grafana 기반 모니터링 시스템을 성공적으로 구축했습니다. 다음 단계로 다음을 고려해 보세요:

1. 추가 메트릭 수집기 설정 (cAdvisor, MySQL Exporter 등)
2. 경고 규칙 설정 (Alertmanager 연동)
3. 대시보드 공유 및 버전 관리
4. 장기 저장을 위한 Remote Write 설정

시스템 모니터링은 DevOps 생태계의 기반이 되는 핵심 인프라입니다. 지속적인 메트릭 분석을 통해 서비스의 안정성과 성능을 극대화할 수 있습니다.

<div style="text-align: center">⁂</div>

[^1]: https://countrymouse.tistory.com/entry/dockercomposeprometheusgrafana

[^2]: https://railly-linker.tistory.com/entry/서버-모니터링-시스템-Docker-로-구성하기Grafana-Prometheus-Loki-Promtail

[^3]: https://cinnamonlover.tistory.com/entry/node-exporter-사용법

[^4]: https://nauco.tistory.com/45

[^5]: https://dev.to/kevinsheeranxyj/docker-series-run-grafana-prometheus-with-docker-compose-in-ubuntu-njh

[^6]: https://www.devkuma.com/docs/prometheus/docker-compose-install/

[^7]: https://waveofmymind.github.io/posts/springboot-monitoring2/

[^8]: https://one-armed-boy.tistory.com/entry/k6-Prometheus-Grafana-자동-환경-구성하기-with-Docker-compose

[^9]: https://velog.io/@greentea/docker-compose로-prometheus와-grafana띄우기

[^10]: https://jung-mmmmin.tistory.com/169

[^11]: https://cheesecat47.github.io/blog/2023/04/23/prometheus-setup

[^12]: https://pinggoopark.tistory.com/346

[^13]: https://atsky.tistory.com/84

[^14]: https://www.fosstechnix.com/install-prometheus-and-grafana-on-ubuntu-24-04/

[^15]: https://mycup.tistory.com/421

[^16]: https://cheesecat47.github.io/blog/2023/05/13/prometheus-setup2

[^17]: https://supern0va.tistory.com/34

[^18]: https://velog.io/@dobecom/monitoring2

[^19]: https://github.com/Einsteinish/Docker-Compose-Prometheus-and-Grafana

[^20]: https://coding-review.tistory.com/436

