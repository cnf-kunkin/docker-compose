# VMware Ubuntu에 Docker Compose로 GitLab, Jenkins, Nginx 서비스 구축 가이드

## 사전 준비

### VMware에 Ubuntu 설치 확인
이 가이드는 VMware에 Ubuntu가 이미 설치되어 있다고 가정합니다. 최소 사양:
- Ubuntu 20.04 LTS 이상
- 최소 8GB RAM
- 최소 50GB 디스크 공간
- CPU 4코어 이상

## 디렉토리 구조 설정

### 데이터 디렉토리 생성
```bash
sudo mkdir -p /data
sudo mkdir -p /data/gitlab/{config,logs,data}
sudo mkdir -p /data/gitlab-runner/{config,data}
sudo touch /data/gitlab-runner/config/config.toml
sudo chmod 777 /data/gitlab-runner/config/config.toml
sudo mkdir -p /data/jenkins
sudo mkdir -p /data/docker-compose
sudo chmod 777 -R /data

```

## Docker Compose 파일 작성

### 작업 디렉토리 생성
```bash
cd /data/docker-compose
```

### docker-compose.yml 파일 작성
```bash
sudo cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  gitlab:
    image: 'gitlab/gitlab-ee:latest'
    container_name: gitlab
    restart: always
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://172.16.10.10'
      TZ: 'Asia/Seoul'
    ports:
      - '80:80'
      - '2222:22'
    volumes:
      - '/data/gitlab/config:/etc/gitlab'
      - '/data/gitlab/logs:/var/log/gitlab'
      - '/data/gitlab/data:/var/opt/gitlab'

  gitlab-runner:
    image: 'gitlab/gitlab-runner:latest'
    container_name: gitlab-runner
    restart: always
    depends_on:
      - gitlab
    volumes:
      - '/data/gitlab-runner/config:/etc/gitlab-runner'
      - '/data/gitlab-runner/data:/home/gitlab-runner'
      - '/data/gitlab-runner/logs:/var/log/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    environment:
      - TZ=Asia/Seoul

  jenkins:
    image: 'jenkins/jenkins:lts'
    container_name: jenkins
    restart: always
    user: root
    environment:
      - TZ=Asia/Seoul
    ports:
      - '8080:8080'
      - '50000:50000'
    volumes:
      - '/data/jenkins/home:/var/jenkins_home'
      - '/data/jenkins/plugins:/var/jenkins_home/plugins'
      - '/data/jenkins/logs:/var/log/jenkins'
      - '/data/jenkins/jobs:/var/jenkins_home/jobs'
      - '/var/run/docker.sock:/var/run/docker.sock'
EOL
```

### 전체 서비스 재구축
```bash
cd /data/docker-compose

docker-compose down
docker-compose up -d
```

### 로그 확인
```bash
docker-compose ps

docker-compose logs -f gitlab  # GitLab 로그 확인
docker-compose logs -f jenkins  # Jenkins 로그 확인
docker-compose logs -f gitlab-runner  # Nginx 로그 확인
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
GitLab: 포트 80으로 직접 접근 (http://172.16.10.10)
Jenkins: 포트 8080로 직접 접근 (http://172.16.10.10:8080)


### GitLab Runner 등록
```bash
docker-compose exec gitlab-runner gitlab-runner register  --url http://172.16.10.10  --token glrt-t1_BpsNkKzNZDMH9ZFzALsQ

# docker
# alpine:latest
```
GitLab에 로그인한 후 Admin Area > CI/CD > Runners에서 등록 토큰을 확인하고 등록합니다:

## GitLab 프로젝트 생성

GitLab CI 파이프라인을 실행하기 위한 개인 프로젝트를 생성합니다.

- 좌측 상단 네비게이션 바에서 **[+]** 아이콘을 클릭하고 **New project/repository**를 선택합니다.
- **Create new project** 페이지에서 **Create blank project**를 클릭합니다.
- **Create blank project** 페이지에서 아래 항목을 입력 또는 선택하고 **Create project** 버튼을 클릭합니다.
    - **Project name** : `Hello GitLab CI` 입력
    - **Visibility Level** : `Private` 선택
    - **Initialize repository with a README** 체크

## .gitlab-ci.yml 파일 생성

- 프로젝트의 왼쪽 네비게이션 바에서 **Code > Repository** 를 클릭합니다. **Repository** 페이지에서 project slug(`hello-gitlab-ci`) 오른쪽에 있는 **[+]** 아이콘을 클릭하고 **New file**를 선택합니다.
- **main** 옆의 텍스트박스에서 `.gitlab-ci.yml`을 입력합니다.
- **Apply a template** 콤보박스에서 `General > Bash`을 선택합니다.
- **Commit changes** 버튼을 클릭합니다.