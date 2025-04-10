# Application VM 구성 가이드

## 1. 환경 구성
- IP: 172.16.10.40
- Hostname: vm-application
- 서비스: Next.js, Nest.js, Python Demo Apps
- SSL: 자체 서명 인증서

## 2. 설치 순서

### 2.1 기본 환경 설정
```bash
# 호스트네임 설정
sudo hostnamectl set-hostname vm-application

# 데이터 디렉토리 생성
sudo mkdir -p /data/{nextjs,nestjs,python}
sudo mkdir -p /data/certs/combined

# 권한 설정
sudo chown -R 1000:1000 /data/nextjs
sudo chown -R 1000:1000 /data/nestjs
sudo chown -R 1000:1000 /data/python
```

### 2.2 서비스 배포
```bash
cd ~/docker-compose/vm-application/docker
docker compose up -d

# 상태 확인
docker compose ps
```

## 3. 서비스 접속 정보
- Next.js Demo: https://next-demo.local
- Nest.js Demo: https://nest-demo.local
- Python Demo: https://python-demo.local
