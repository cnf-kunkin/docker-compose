# VMware Ubuntu에 Docker Compose로 GitLab, Jenkins, Nginx 서비스 구축 가이드

## 목차
1. [사전 준비](#사전-준비)
2. [Docker 및 Docker Compose 설치](#docker-및-docker-compose-설치)
3. [디렉토리 구조 설정](#디렉토리-구조-설정)
4. [SSL 인증서 생성](#ssl-인증서-생성)
5. [Docker Compose 파일 작성](#docker-compose-파일-작성)
6. [서비스 실행](#서비스-실행)
7. [서비스 접속 및 초기 설정](#서비스-접속-및-초기-설정)
8. [문제 해결](#문제-해결)

## 사전 준비

### VMware에 Ubuntu 설치 확인
이 가이드는 VMware에 Ubuntu가 이미 설치되어 있다고 가정합니다. 최소 사양:
- Ubuntu 20.04 LTS 이상
- 최소 8GB RAM
- 최소 50GB 디스크 공간
- CPU 4코어 이상

### 호스트 이름 설정
서비스에 접속할 사설 도메인 이름을 설정하기 위해 `/etc/hosts` 파일을 편집합니다:

```bash
sudo nano /etc/hosts
```

아래 내용을 추가합니다 (IP 주소는 VM의 IP로 변경):
```
192.168.x.x gitlab.local
192.168.x.x jenkins.local
```

## Docker 및 Docker Compose 설치

### 필요 패키지 설치
```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
```

### Docker 저장소 설정
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Docker 엔진 설치
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
```

### Docker 사용자 권한 설정
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Docker Compose 설치
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Docker 서비스 시작 및 활성화
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## 디렉토리 구조 설정

### 데이터 디렉토리 생성
```bash
sudo mkdir -p /data
sudo mkdir -p /data/gitlab/{config,logs,data}
sudo mkdir -p /data/gitlab-runner/{config,data}
sudo mkdir -p /data/jenkins
sudo mkdir -p /data/nginx/{conf,ssl,logs}
sudo chmod -R 777 /data
```

## SSL 인증서 생성

### 자체 서명 인증서 생성을 위한 디렉토리 생성
```bash
mkdir -p /data/nginx/ssl
cd /data/nginx/ssl
```

### SSL 인증서 생성
```bash
# gitlab.local 도메인용 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout gitlab.local.key -out gitlab.local.crt \
  -subj "/CN=gitlab.local/O=GitLab/C=KR"

# jenkins.local 도메인용 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout jenkins.local.key -out jenkins.local.crt \
  -subj "/CN=jenkins.local/O=Jenkins/C=KR"
```

## Docker Compose 파일 작성

### 작업 디렉토리 생성
```bash
mkdir -p ~/docker-services
cd ~/docker-services
```

### docker-compose.yml 파일 작성
```bash
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  # GitLab - 내부 포트만 사용하고 외부 포트는 노출하지 않음
  gitlab:
    image: 'gitlab/gitlab-ce:latest'
    container_name: gitlab
    restart: always
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.local'
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
        nginx['proxy_set_headers'] = {
          "X-Forwarded-Proto" => "https",
          "X-Forwarded-Ssl" => "on"
        }
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['time_zone'] = 'Asia/Seoul'
    ports:
      - '2222:22' # SSH 포트만 직접 노출
    volumes:
      - '/data/gitlab/config:/etc/gitlab'
      - '/data/gitlab/logs:/var/log/gitlab'
      - '/data/gitlab/data:/var/opt/gitlab'
    networks:
      - devops_network
    shm_size: '256m'

  # GitLab Runner
  gitlab-runner:
    image: 'gitlab/gitlab-runner:latest'
    container_name: gitlab-runner
    restart: always
    depends_on:
      - gitlab
    volumes:
      - '/data/gitlab-runner/config:/etc/gitlab-runner'
      - '/data/gitlab-runner/data:/home/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - devops_network
    environment:
      - TZ=Asia/Seoul

  # Jenkins
  jenkins:
    image: 'jenkins/jenkins:lts'
    container_name: jenkins
    restart: always
    user: root
    environment:
      - TZ=Asia/Seoul
    volumes:
      - '/data/jenkins:/var/jenkins_home'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - devops_network

  # Nginx (리버스 프록시) - 호스트의 80, 443 포트를 사용
  nginx:
    image: 'nginx:latest'
    container_name: nginx
    restart: always
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - '/data/nginx/conf:/etc/nginx/conf.d'
      - '/data/nginx/ssl:/etc/nginx/ssl'
      - '/data/nginx/logs:/var/log/nginx'
    networks:
      - devops_network
    depends_on:
      - gitlab
      - jenkins

networks:
  devops_network:
    driver: bridge
EOL
```

### Nginx 설정 파일 작성
```bash
mkdir -p /data/nginx/conf
cat > /data/nginx/conf/default.conf << 'EOL'
# Jenkins 리버스 프록시 설정
# GitLab 리버스 프록시 설정
server {
    listen 443 ssl;
    server_name gitlab.local;

    ssl_certificate /etc/nginx/ssl/gitlab.local.crt;
    ssl_certificate_key /etc/nginx/ssl/gitlab.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://gitlab:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Ssl on;
        proxy_redirect http:// https://;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    access_log /var/log/nginx/gitlab_access.log;
    error_log /var/log/nginx/gitlab_error.log;
}

# Jenkins 리버스 프록시 설정
server {
    listen 443 ssl;
    server_name jenkins.local;

    ssl_certificate /etc/nginx/ssl/jenkins.local.crt;
    ssl_certificate_key /etc/nginx/ssl/jenkins.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://jenkins:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect http:// https://;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    access_log /var/log/nginx/jenkins_access.log;
    error_log /var/log/nginx/jenkins_error.log;
}

# HTTP 요청을 HTTPS로 리다이렉트
server {
    listen 80;
    server_name jenkins.local gitlab.local;
    return 301 https://$host$request_uri;
}
EOL
```

### GitLab Runner 등록 스크립트 작성
```bash
cat > register-gitlab-runner.sh << 'EOL'
#!/bin/bash

# 이 스크립트는 GitLab이 시작된 후에 실행해야 합니다
# GitLab에서 생성한 등록 토큰이 필요합니다

if [ -z "$1" ]; then
    echo "Usage: $0 <gitlab-registration-token>"
    exit 1
fi

TOKEN=$1

docker-compose exec gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.local" \
  --registration-token "$TOKEN" \
  --executor "docker" \
  --docker-image "docker:20.10.16" \
  --description "docker-runner" \
  --tag-list "docker,build" \
  --run-untagged="true" \
  --locked="false" \
  --docker-privileged="true" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --docker-network-mode "devops_network"
EOL

chmod +x register-gitlab-runner.sh
```

## 서비스 실행

### Docker Compose 서비스 시작
```bash
cd ~/docker-services
docker-compose up -d
```

### 로그 확인
```bash
docker-compose logs -f gitlab  # GitLab 로그 확인
docker-compose logs -f jenkins  # Jenkins 로그 확인
docker-compose logs -f nginx  # Nginx 로그 확인
```

## 서비스 접속 및 초기 설정

### GitLab 초기 비밀번호 확인
GitLab이 완전히 시작되기까지 약 5-10분 정도 소요될 수 있습니다.
```bash
docker-compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

### Jenkins 초기 비밀번호 확인
```bash
docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 서비스 접속
- GitLab: https://gitlab.local
- Jenkins: https://jenkins.local

### GitLab Runner 등록
GitLab에 로그인한 후 Admin Area > CI/CD > Runners에서 등록 토큰을 확인하고 등록합니다:
```bash
./register-gitlab-runner.sh <registration-token>
```

## 문제 해결

### 서비스 상태 확인
```bash
docker-compose ps
```

### 컨테이너 로그 확인
```bash
docker-compose logs -f [service_name]
```

### 네트워크 연결 확인
```bash
docker network inspect docker-services_devops_network
```

### 볼륨 권한 문제 해결
```bash
sudo chown -R 1000:1000 /data/jenkins  # Jenkins 볼륨 권한 수정
sudo chmod -R 777 /data/gitlab  # GitLab 볼륨 권한 수정
```

### 서비스 재시작
```bash
docker-compose restart [service_name]
```

### 전체 서비스 재구축
```bash
docker-compose down
docker-compose up -d
```