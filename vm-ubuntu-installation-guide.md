# VM 및 Docker 설치 가이드

## 1. VMware 네트워크 설정
### 1.1 NAT 네트워크 구성
1. VMware Workstation에서 Edit > Virtual Network Editor 실행
2. NAT 네트워크 설정:
```bash
# VMnet8 (NAT) 설정
Network Name: VMnet8
Subnet IP: 172.16.10.0
Subnet mask: 255.255.255.0
Gateway IP: 172.16.10.2

# DHCP 설정 해제
[] Use local DHCP service to distribute IP address to VMs (체크 해제)
```

### 1.2 NAT 설정 확인
```bash
# Windows PowerShell (관리자 권한)에서 실행
ipconfig /all | findstr VMware
# VMware Network Adapter VMnet8이 있는지 확인
```

## 2. Ubuntu 24.04 설치
### 2.1 기본 설정
- Ubuntu 24.04 LTS Server ISO 다운로드
- VMware에서 새로운 VM 생성
  ```bash
  # 각 VM별 스펙 설정
  CI/CD VM: 6 CPU, 12GB RAM, 100GB Disk
  Harbor VM: 4 CPU, 8GB RAM, 80GB Disk
  Monitoring VM: 2 CPU, 4GB RAM, 60GB Disk
  Security VM: 2 CPU, 4GB RAM, 60GB Disk
  Application VM: 4 CPU, 8GB RAM, 80GB Disk
  N8N VM: 2 CPU, 4GB RAM, 60GB Disk
  ```

### 2.2 Ubuntu 설치 프로세스
1. 부팅 옵션 선택
```bash
# 언어 선택
English

# 키보드 설정
Korean -> Korean (101/104 key compatible)
```

2. 네트워크 설정
```bash
# ens33 네트워크 카드 선택 후 Edit IPv4
IPv4 Method: Manual
Subnet: 172.16.10.0/24
Address: 172.16.10.X  # VM별 할당된 IP 입력
Gateway: 172.16.10.2
Name servers: 8.8.8.8,8.8.4.4
Search domains: local
```

3. 스토리지 구성
```bash
# 파티션 생성 순서
1. 새 파티션 테이블 생성 (gpt 선택)
2. 파티션 순서대로 생성:

# /dev/sda1 - /boot 파티션
크기: 2GB
유형: Primary
파일시스템: ext4
마운트 포인트: /boot

# /dev/sda2 - swap 파티션
크기: RAM 크기와 동일 (예: 4GB)
유형: Logical
파일시스템: swap

# /dev/sda3 - 루트 파티션
크기: 40GB
유형: Primary
파일시스템: ext4
마운트 포인트: /

# /dev/sda4 - 데이터 파티션
크기: 남은 공간 전체
유형: Primary
파일시스템: ext4
마운트 포인트: /data

# 각 VM별 권장 /data 파티션 크기
LoadBalancer VM: 38GB
CI/CD VM: 154GB
Monitoring VM: 54GB
Security VM: 54GB
Application VM: 74GB
```

4. 사용자 설정
```bash
# 시스템 정보 입력 (예시)
Your name: 관리자
Your server's name: vm-cicd
Username: devops
Password: <안전한 비밀번호>

# 추가 설정
- OpenSSH server 설치 체크
- 기타 추가 패키지는 선택하지 않음
```

### 2.3 한글 환경 설정
```bash
# 한글 로케일 생성
sudo locale-gen ko_KR.UTF-8

# 기본 로케일 설정
sudo update-locale LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8

# 한글 폰트 설치
sudo apt install -y fonts-nanum fonts-nanum-coding fonts-nanum-extra
```

### 2.4 시간 동기화 설정
```bash
# timesyncd 설정
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# 타임존 설정
sudo timedatectl set-timezone Asia/Seoul

# NTP 서버 설정
sudo bash -c 'cat > /etc/systemd/timesyncd.conf << EOF
[Time]
NTP=time.bora.net time.kornet.net
FallbackNTP=ntp.ubuntu.com
EOF'

# 시간 동기화 재시작
sudo systemctl restart systemd-timesyncd
```

### 2.5 Sudo 설정
```bash
# sudo 설정 파일 생성
sudo bash -c 'echo "ubuntu ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/custom'

sudo cat /etc/sudoers.d/custom


# 권한 설정
sudo chmod 440 /etc/sudoers.d/custom
```

### 2.6 네트워크 설정
```bash
# /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    ens33:
      addresses:
      - "172.16.10.90/24" 
      nameservers:
        addresses:
        - 8.8.8.8
        - 8.8.4.4
        search:
        - local
      routes:
      - to: "default"
        via: "172.16.10.2"
```

### 2.7 기본 패키지 설치
```bash
# 시스템 업데이트
sudo apt update
sudo apt upgrade -y

# 기본 도구 설치
sudo apt install -y  curl   wget   git   vim   net-tools   ca-certificates   gnupg   lsb-release
```

## 3. Docker 설치
### 3.1 Docker Repository 설정
```bash
# Docker 공식 GPG key 추가
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker Repository 추가
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 3.2 Docker Engine 설치
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 데이터 디렉토리 생성
sudo mkdir -p /data/docker
sudo chown root:root /data/docker

# Docker 데이터 디렉토리 설정
sudo tee /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker"
}
EOF

# Docker 서비스 시작 및 자동 실행 설정
sudo systemctl start docker
sudo systemctl enable docker

# 현재 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# Docker 서비스 재시작
sudo systemctl restart docker

# 새로운 데이터 경로 확인
sudo docker info | grep "Docker Root Dir"
```

### 3.3 Docker Compose 설치
```bash
# Docker Compose 설치
# 버전 확인 
https://github.com/docker/compose/releases

COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d '"' -f 4)

sudo curl -SL https://github.com/docker/compose/releases/download/v2.35.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

docker-compose --version
source ~/.bashrc

# 버전 확인
docker --version
docker-compose version
docker compose version

# Docker version 28.0.4, build b8034c0
# Docker Compose version v2.34.0
```

## 4. 호스트 설정
### 4.1 호스트 파일 설정
```bash
# C:\Windows\System32\drivers\etc\hosts 파일에 추가
# sudo vi /etc/hosts 파일에 추가
# 기본 설정
127.0.0.1   localhost

# CI/CD 서비스
172.16.10.10   gitlab.local
172.16.10.10   jenkins.local
172.16.10.10   gitlab-runner.local
172.16.10.11   harbor.local
172.16.10.12   n8n.local

# 모니터링 서비스
172.16.10.20   grafana.local
172.16.10.20   prometheus.local

# 보안 서비스
172.16.10.30   sonarqube.local
172.16.10.30   security.local

# 애플리케이션 서비스
172.16.10.40   next-demo.local
172.16.10.40   nest-demo.local
172.16.10.40   python-demo.local

```

### 4.2 방화벽 설정
```bash
# UFW 영구 비활성화
sudo systemctl stop ufw
sudo systemctl disable ufw
sudo ufw disable


# UFW 활성화 및 기본 설정
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Docker 관련 포트 개방 (필요한 경우)
sudo ufw allow 2375/tcp  # Docker daemon
sudo ufw allow 2376/tcp  # Docker daemon TLS

# UFW 상태 확인
sudo ufw status 
```

## 5. 설치 확인
```bash
# Docker 실행 테스트
docker run hello-world
# Docker 실행 테스트 삭제
docker rm $(docker ps -a -q)  # Remove all containers first
docker rmi hello-world        # Then remove the image

# 종료후 os 이미지 자동 시작 삭제 처리 

```
## 6. VM별 호스트네임 변경
```bash
# VM별 IP 및 호스트네임 변경

# CI/CD VM (172.16.10.10) D:\vmware\cicd\vm-cicd
sudo sed -i 's/172\.16\.10\.90/172.16.10.10/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-cicd

# Harbor VM (172.16.10.11) D:\vmware\cicd\vm-harbor
sudo sed -i 's/172\.16\.10\.90/172.16.10.11/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-harbor


# Harbor VM (172.16.10.11) D:\vmware\cicd\vm-n8n
sudo sed -i 's/172\.16\.10\.90/172.16.10.12/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-n8n


# Monitoring VM (172.16.10.20) D:\vmware\cicd\vm-monitoring
sudo sed -i 's/172\.16\.10\.90/172.16.10.20/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-monitoring

# Security VM (172.16.10.30) D:\vmware\cicd\vm-security
sudo sed -i 's/172\.16\.10\.90/172.16.10.30/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-security

# Application VM (172.16.10.40) D:\vmware\cicd\vm-app
sudo sed -i 's/172\.16\.10\.90/172.16.10.40/g' /etc/netplan/50-cloud-init.yaml
sudo hostnamectl set-hostname vm-app

# IP 설정 확인
ip addr show ens33

# 변경사항 적용을 위한 시스템 재시작
sudo reboot
```
