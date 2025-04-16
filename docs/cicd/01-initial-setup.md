# 초기 환경 구성 가이드

## 1. 시스템 요구사항 확인

### 1.1 호스트 PC 사양
- CPU: 최소 16코어 (권장 20코어)
- 메모리: 최소 32GB (권장 64GB)
- 디스크: 최소 500GB
- OS: Windows 10/11 Pro 이상

### 1.2 가상머신 할당 사양
| VM 이름 | IP 주소 | CPU | 메모리 | 디스크 |
|---------|---------|-----|--------|---------|
| CI/CD | 172.16.10.10 | 6코어 | 12GB | 100GB |
| Harbor | 172.16.10.11 | 4코어 | 8GB | 80GB |
| Monitoring | 172.16.10.20 | 2코어 | 4GB | 60GB |
| Security | 172.16.10.30 | 2코어 | 4GB | 60GB |
| Application | 172.16.10.40 | 4코어 | 8GB | 80GB |

## 2. 네트워크 구성

### 2.1 VMware 네트워크 설정
1. VMware Workstation에서 Edit > Virtual Network Editor 실행
2. NAT 네트워크 설정:
```bash
네트워크 이름: VMnet8
서브넷 IP: 172.16.10.0
서브넷 마스크: 255.255.255.0
게이트웨이 IP: 172.16.10.2
```

### 2.2 호스트 파일 설정
Windows의 hosts 파일 (C:\Windows\System32\drivers\etc\hosts)에 추가:
```plaintext
# CI/CD 서비스
172.16.10.10   gitlab.local
172.16.10.10   jenkins.local
172.16.10.11   harbor.local

# 모니터링 서비스
172.16.10.20   grafana.local
172.16.10.20   prometheus.local

# 보안 서비스
172.16.10.30   sonarqube.local
172.16.10.30   security.local

# 애플리케이션 서비스
172.16.10.40   python-demo.local
```

## 3. SSL 인증서 생성

### 3.1 인증서 생성 스크립트 실행
```bash
# generate-certs.sh 스크립트 실행
cd /path/to/docker-compose
chmod +x generate-certs.sh
./generate-certs.sh
```

### 3.2 인증서 배포
각 VM의 적절한 위치에 인증서 파일 복사:
```bash
# CI/CD VM
scp /data/certs/combined/gitlab.local.* devops@172.16.10.10:/data/nginx/ssl/
scp /data/certs/combined/jenkins.local.* devops@172.16.10.10:/data/nginx/ssl/

# Harbor VM
scp /data/certs/combined/harbor.local.* devops@172.16.10.11:/data/nginx/ssl/

# Security VM
scp /data/certs/combined/sonarqube.local.* devops@172.16.10.30:/data/nginx/ssl/
scp /data/certs/combined/security.local.* devops@172.16.10.30:/data/nginx/ssl/

# Application VM
scp /data/certs/combined/python-demo.local.* devops@172.16.10.40:/data/nginx/ssl/
```

## 4. 디렉토리 구조 설정

### 4.1 CI/CD VM (172.16.10.10)
```bash
sudo mkdir -p /data/gitlab/{config,logs,data}
sudo mkdir -p /data/gitlab-runner/{config,data}
sudo mkdir -p /data/jenkins
sudo mkdir -p /data/nginx/{conf,ssl,logs}
```

### 4.2 Harbor VM (172.16.10.11)
```bash
sudo mkdir -p /data/harbor/{data,logs}
sudo mkdir -p /data/certs
```

### 4.3 Monitoring VM (172.16.10.20)
```bash
sudo mkdir -p /data/{prometheus,grafana}
sudo mkdir -p /data/nginx/{conf,ssl,logs}
```

### 4.4 Security VM (172.16.10.30)
```bash
sudo mkdir -p /data/{sonarqube,zap}
sudo mkdir -p /data/nginx/{conf,ssl,logs}
```

### 4.5 Application VM (172.16.10.40)
```bash
sudo mkdir -p /data/{python,nginx}
sudo mkdir -p /data/nginx/{conf,ssl,logs}
```

## 5. 권한 설정

각 VM에서 실행:
```bash
# 데이터 디렉토리 권한 설정
sudo chown -R 1000:1000 /data
sudo chmod -R 755 /data

# SSL 디렉토리 권한 설정
sudo chmod -R 600 /data/nginx/ssl
sudo chown -R root:root /data/nginx/ssl
```

## 6. 설치 확인

### 6.1 네트워크 연결 확인
각 VM에서 실행:
```bash
# DNS 확인
ping gitlab.local
ping harbor.local
ping grafana.local
ping sonarqube.local
ping python-demo.local

# 포트 연결 확인
nc -zv gitlab.local 443
nc -zv harbor.local 443
nc -zv grafana.local 443
nc -zv sonarqube.local 443
```

### 6.2 디렉토리 권한 확인
각 VM에서 실행:
```bash
# 디렉토리 권한 확인
ls -la /data
ls -la /data/nginx/ssl
```

### 6.3 도커 설정 확인
각 VM에서 실행:
```bash
# 도커 버전 확인
docker --version
docker compose version

# 도커 데몬 상태 확인
sudo systemctl status docker
```

## 다음 단계
모든 초기 설정이 완료되면, [사용자 계정 설정](./02-user-accounts.md) 가이드로 진행하세요.