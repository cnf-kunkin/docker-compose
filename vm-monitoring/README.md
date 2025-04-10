# Monitoring VM 설치 가이드

## 1. 환경 구성
- IP: 172.16.10.20
- Hostname: vm-monitoring
- 서비스: Prometheus, Grafana, Node Exporter
- SSL: 자체 서명 인증서

## 2. 설치 순서

### 2.1 기본 환경 설정
```bash
# 호스트네임 설정
sudo hostnamectl set-hostname vm-monitoring

# 네트워크 설정
sudo tee /etc/netplan/50-cloud-init.yaml <<EOF
network:
  version: 2
  ethernets:
    ens33:
      addresses: [172.16.10.20/24]
      gateway4: 172.16.10.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

sudo netplan apply
```

### 2.2 데이터 디렉토리 설정
```bash
# 디렉토리 생성
sudo mkdir -p /data/{prometheus,grafana}
sudo mkdir -p /data/certs/combined
sudo chown -R nobody:nogroup /data/prometheus
sudo chown -R 472:472 /data/grafana
```

## 3. 서비스 배포
```bash
# docker-compose 실행
cd ~/docker-compose/vm-monitoring/docker
docker compose up -d

# 상태 확인
docker compose ps
```

## 4. 서비스 접속 정보

### 4.1 Grafana
- URL: https://grafana.local
- 초기 계정: admin
- 초기 비밀번호: admin

### 4.2 Prometheus
- URL: https://prometheus.local
- 기본 인증 없음
