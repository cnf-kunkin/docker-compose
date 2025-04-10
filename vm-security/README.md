# Security VM 구성 가이드

## 1. 환경 구성
- IP: 172.16.10.30
- Hostname: vm-security
- 서비스: SonarQube, OWASP ZAP
- SSL: 자체 서명 인증서

## 2. 설치 순서

### 2.1 기본 환경 설정
```bash
# 호스트네임 설정
sudo hostnamectl set-hostname vm-security

# SonarQube 요구사항 설정
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf

# 데이터 디렉토리 생성
sudo mkdir -p /data/{sonarqube,zap}
sudo chown -R 1000:1000 /data/sonarqube
```

### 2.2 서비스 배포
```bash
cd ~/docker-compose/vm-security/docker
docker compose up -d

# 상태 확인
docker compose ps
```

## 3. 서비스 접속 정보

### 3.1 SonarQube
- URL: https://sonarqube.local
- 초기 계정: admin
- 초기 비밀번호: admin

### 3.2 OWASP ZAP
- URL: https://security.local
- Basic Auth: 설정 파일에서 확인
