# MSA 개발/운영 환경 구성 가이드

## 1. 시스템 구성도
```mermaid
graph TB
    subgraph Host["개발자 PC"]
        VMware["VMware Workstation Pro"]
        subgraph Network["가상 네트워크 (172.16.10.0/24)"]
            LB["LoadBalancer VM<br>HAProxy<br>172.16.10.3"]
            CICD["CI/CD VM<br>GitLab/Jenkins/Harbor<br>172.16.10.10"]
            MON["Monitoring VM<br>Grafana/Prometheus<br>172.16.10.20"]
            SEC["Security VM<br>SonarQube/OWASP ZAP<br>172.16.10.30"]
            APP["Application VM<br>Next.js/Nest.js/Python<br>172.16.10.40"]
            
            LB --> CICD
            LB --> MON
            LB --> SEC
            LB --> APP
        end
    end
```

## 2. 설치 및 실행 순서

### 2.1 기본 환경 구성 (모든 VM 공통)
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y


# Docker 설치
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# 기본 디렉토리 생성
sudo mkdir -p /data/{certs,logs}
sudo chmod 700 /data/certs
sudo chmod 755 /data/logs
```

### 2.2 각 VM 구성 순서
1. LoadBalancer VM (172.16.10.3)
   - SSL 인증서 생성
   - HAProxy 구성
   - 도메인 라우팅 설정

2. CI/CD VM (172.16.10.10)
   - GitLab
   - Harbor
   - Jenkins

3. Monitoring VM (172.16.10.20)
   - Prometheus
   - Grafana
   - Node Exporter

4. Security VM (172.16.10.30)
   - SonarQube
   - OWASP ZAP

5. Application VM (172.16.10.40)
   - Next.js Demo
   - Nest.js Demo
   - Python Demo

### 2.3 실행 명령어
```bash
# 1. LoadBalancer VM
cd ~/docker-compose/loadbalancer/docker
cp ../.env.sample ../.env
docker compose up -d

# 2. CI/CD VM
cd ~/docker-compose/cicd/docker
cp ../.env.sample ../.env
docker compose up -d

# 3. Monitoring VM
cd ~/docker-compose/monitoring/docker
cp ../.env.sample ../.env
docker compose up -d

# 4. Security VM
cd ~/docker-compose/security/docker
cp ../.env.sample ../.env
docker compose up -d

# 5. Application VM
cd ~/docker-compose/application/docker
cp ../.env.sample ../.env
docker compose up -d
```

## 3. 시스템 요구사항
- 호스트 PC
  - CPU: 최소 16코어 (권장 20코어)
  - 메모리: 최소 32GB (권장 64GB)
  - 디스크: 최소 500GB
  - OS: Windows 10/11 Pro 이상
  
- VM 별 스펙
  - LoadBalancer VM: 2 CPU, 2GB RAM, 40GB Disk
  - CI/CD VM: 6 CPU, 12GB RAM, 100GB Disk
  - Monitoring VM: 2 CPU, 4GB RAM, 60GB Disk
  - Security VM: 2 CPU, 4GB RAM, 60GB Disk
  - Application VM: 4 CPU, 8GB RAM, 80GB Disk

## 4. Git 저장소 설정
```bash
# 소스 코드 다운로드
git clone https://github.com/cnf-kunkin/docker-compose.git
cd docker-compose

# 변경사항 커밋 및 푸시
git add .
git commit -m "feat: 환경 설정 변경"
git push origin main

# 다른 개발자의 변경사항 가져오기
git fetch origin
git pull origin main
```

## Git 저장소 사용 방법

### 전체 프로젝트 클론
```bash
# 전체 프로젝트 클론
git clone https://github.com/cnf-kunkin/docker-compose.git
cd docker-compose
```

### VM별 선택적 클론
특정 VM 환경만 필요한 경우 sparse-checkout을 사용하여 필요한 폴더만 클론할 수 있습니다.

```bash
# 1. 빈 저장소 초기화
git init docker-compose
cd docker-compose
git remote add origin https://github.com/cnf-kunkin/docker-compose.git

# 2. Sparse-checkout 설정
git sparse-checkout init
git sparse-checkout set <folder-name>  # 원하는 폴더명 지정

# 3. 저장소 내용 가져오기
git pull origin main

# 예시: LoadBalancer VM 환경만 클론
git sparse-checkout set loadbalancer

# 예시: CI/CD VM 환경만 클론
git sparse-checkout set cicd

# 예시: 여러 폴더 동시 클론
git sparse-checkout set loadbalancer cicd monitoring
```

### VM별 디렉토리 설명
```plaintext
docker-compose/
├── loadbalancer/     # LoadBalancer VM (172.16.10.3)
│   ├── docker/         # Docker Compose 파일
│   ├── config/         # HAProxy, SSL 설정
│   └── README.md       # 설치 및 설정 가이드
├── cicd/            # CI/CD VM (172.16.10.10)
│   ├── docker/         # Docker Compose 파일
│   ├── config/         # GitLab, Jenkins, Harbor 설정
│   └── README.md       # 설치 및 설정 가이드
├── monitoring/      # Monitoring VM (172.16.10.20)
│   ├── docker/         # Docker Compose 파일
│   ├── config/         # Grafana, Prometheus 설정
│   └── README.md       # 설치 및 설정 가이드
├── security/        # Security VM (172.16.10.30)
│   ├── docker/         # Docker Compose 파일
│   ├── config/         # SonarQube, OWASP ZAP 설정
│   └── README.md       # 설치 및 설정 가이드
└── application/     # Application VM (172.16.10.40)
    ├── docker/         # Docker Compose 파일
    ├── apps/           # 애플리케이션 소스코드
    ├── config/         # Nginx 설정
    └── README.md       # 설치 및 설정 가이드
```

### 작업 브랜치 생성
```bash
# 새로운 작업 브랜치 생성
git checkout -b feature/[기능명]

# 변경사항 커밋
git add .
git commit -m "feat: 새로운 기능 추가"

# 원격 저장소에 푸시
git push origin feature/[기능명]
```

## 5. 디렉토리 구조
```bash
docker-compose/
├── loadbalancer/     # 1단계: LoadBalancer VM
├── cicd/            # 2단계: CI/CD VM
├── monitoring/      # 3단계: Monitoring VM
├── security/        # 4단계: Security VM
└── application/     # 5단계: Application VM
```

## 6. 도메인 구성
- LoadBalancer: haproxy.local
- CI/CD: gitlab.local, jenkins.local, harbor.local
- Monitoring: grafana.local, prometheus.local
- Security: sonarqube.local, security.local
- Application: next-demo.local, nest-demo.local, python-demo.local
