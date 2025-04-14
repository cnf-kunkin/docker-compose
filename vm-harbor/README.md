# Harbor VM 설치 가이드

## 1. 환경 구성
- IP: 172.16.10.11
- Hostname: vm-harbor
- 서비스: Harbor Registry
- SSL: 자체 서명 인증서

## 1. 시스템 구성도

```mermaid
graph TD
    subgraph Harbor VM[Harbor VM - 172.16.10.11]
        Proxy[Nginx Proxy<br>443/80] --> Core[Harbor Core]
        
        subgraph Core Components
            Core --> Registry[Registry Service]
            Core --> Portal[Harbor Portal UI]
            Core --> JobService[Job Service]
            Core --> RegistryCtl[Registry Controller]
            Core --> Trivy[Trivy Scanner]
        end
        
        subgraph Databases
            Core --> PostgreSQL[PostgreSQL<br>메타데이터]
            Core --> Redis[Redis<br>작업큐/캐시]
        end
        
        subgraph Storage[스토리지]
            Registry --> RegStorage[Registry Storage<br>/data/harbor/data]
            Core --> LogStorage[Log Storage<br>/data/harbor/logs]
        end
    end

    Client[External Client] -->|HTTPS| Proxy
    Docker[Docker Client] -->|HTTPS| Proxy
```

### 1.1 컴포넌트 설명

#### 핵심 서비스
- **Harbor Core**: API 서비스 및 웹훅 처리
- **Registry**: Docker/OCI 이미지 저장소
- **Portal**: 웹 UI 인터페이스
- **Job Service**: 복제/스캔 작업 관리
- **Registry Controller**: 레지스트리 관리
- **Trivy**: 컨테이너 취약점 스캐너

#### 데이터베이스
- **PostgreSQL**
  - 용도: 사용자/프로젝트/정책 메타데이터
  - 경로: /data/database
  - 계정: postgres/root123

- **Redis**
  - 용도: 세션관리, 작업큐
  - 경로: /data/redis
  - 인증: 비활성화

#### 저장소
- **Registry Storage**: /data/registry
  - 컨테이너 이미지
  - 아티팩트 메타데이터

- **Log Storage**: /var/log/harbor
  - 시스템/접근 로그
  - 작업 로그

### 1.2 네트워크 구성
- **외부 접근**
  - HTTPS: 443 포트
  - HTTP: 80 포트 (HTTPS 리다이렉트)
  - 도메인: harbor.local

- **내부 네트워크**
  - harbor_network (Docker bridge)
  - 컨테이너 간 통신

### 1.3 볼륨 구성
```plaintext
/data/
├── harbor/          # Harbor 설정 및 데이터
├── database/        # PostgreSQL 데이터
├── redis/           # Redis 데이터
├── registry/        # 이미지 저장소
└── certs/          # SSL 인증서
    └── combined/   # 통합 인증서
```

## 2. 설치 순서

### 2.1 기본 환경 설정
```bash
# 디렉토리 생성
sudo mkdir -p /data/harbor/data
sudo mkdir -p /data/harbor/logs
sudo mkdir -p /data/certs
sudo chmod -R 777 /data

cd /data/certs
# harbor.local 도메인용 인증서 생성
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout harbor.local.key -out harbor.local.crt \
  -subj "/CN=harbor.local/O=harbor/C=KR"

```

### 2.2 Harbor 설치 준비
```bash


# Harbor 설치 파일 다운로드
# https://github.com/goharbor/harbor/releases 최신 버전 확인 
cd ~
wget https://github.com/goharbor/harbor/releases/download/v2.12.2/harbor-offline-installer-v2.12.2.tgz

tar xzvf harbor-offline-installer-v2.12.2.tgz
```

## 3. 서비스 배포

### 3.1 설정 파일 준비
```bash
# Harbor 설정

cd ~/harbor
cp harbor.yml.tmpl harbor.yml


# 설정 파일 수정
sed -i 's/hostname: reg.mydomain.com/hostname: harbor.local/g' harbor.yml
sed -i "s#certificate: /your/certificate/path#certificate: /data/certs/harbor.local.crt#g" harbor.yml
sed -i "s#private_key: /your/private/key/path#private_key: /data/certs/harbor.local.key#g" harbor.yml

# 데이터 경로 수정
sed -i 's#data_volume: /data#data_volume: /data/harbor/data#g' harbor.yml
sed -i 's#location: /var/log/harbor#location: /data/harbor/logs#g' harbor.yml
```

### 3.2 Harbor 설치
```bash
# 설치 전 Docker Compose 플러그인 확인
docker compose version

# 설치 스크립트 실행 
sudo ./install.sh 

# 컨테이너 상태 확인
cd ~/harbor
sudo docker compose ps
sudo docker compose logs
```

## 4. 서비스 접속 정보
- URL: https://harbor.local
- 초기 계정: admin
- 초기 비밀번호: Harbor12345

## 5. Docker 클라이언트 설정
```bash
# Docker 재시작
sudo systemctl restart docker

# Harbor 로그인
docker login harbor.local
```

## 6. 운영 관리

### 6.1 상태 모니터링
```bash
# 전체 서비스 상태
docker compose ps

# 서비스별 로그 확인
docker compose logs -f [서비스명]

# 디스크 사용량 확인
du -sh /data/*
```

### 6.2 백업
```bash
# 설정 파일 백업
cp ~/harbor/harbor.yml ~/harbor/harbor.yml.bak

# 데이터베이스 백업
docker compose exec postgresql pg_dump -U postgres harbor > harbor_db_backup.sql

# 인증서 백업
cp -r /data/certs/combined /data/certs/backup
```

### 6.3 성능 최적화
- Registry 캐시 설정
- Garbage Collection 주기적 실행
- 로그 로테이션 설정
- 이미지 청소 정책 설정
