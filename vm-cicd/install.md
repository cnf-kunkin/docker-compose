<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# Docker Compose를 활용한 GitLab, Jenkins, Nginx 통합 개발 환경 구축 가이드

본 가이드는 Docker Compose를 사용하여 GitLab, GitLab Runner, Jenkins, Nginx를 포함하는 통합 개발 환경을 구축하는 방법을 상세히 설명합니다. 이 환경은 지속적 통합(CI) 및 지속적 배포(CD) 파이프라인을 위한 기반으로 활용될 수 있으며, 각 서비스 간의 원활한 연동을 통해 효율적인 개발 작업흐름을 지원합니다.

## 시스템 구성 개요

다음은 구축할 시스템의 전체 구성을 ASCII 다이어그램으로 표현한 것입니다:

```
                   ┌─────────────────────────────────────────┐
                   │              Host System                │
                   │  ┌─────────────┐      ┌─────────────┐  │
                   │  │  /etc/hosts │      │ Docker      │  │
┌─────────────┐    │  │             │      │ Compose     │  │
│   User      │    │  │ gitlab.local│      │             │  │
│   Browser   │◄───┼──┼─────────────┼──────┼─────────────┤  │
│             │    │  │jenkins.local│      │             │  │
└─────┬───────┘    │  └─────────────┘      └─────────────┘  │
      │            │                                         │
      │            └─────────────────────────────────────────┘
      │                              │
      │                              ▼
      │            ┌─────────────────────────────────────────┐
      │            │          Docker Network                 │
      │            │                                         │
      │            │  ┌─────────┐        ┌─────────┐         │
      └────────────┼─►│  Nginx  │◄───────┤ Volumes │         │
                   │  └────┬────┘        └─────────┘         │
                   │       │                                 │
                   │       ▼                                 │
                   │  ┌────┴─────┬─────────────┐            │
                   │  │          │             │            │
                   │  ▼          ▼             ▼            │
              ┌────┴──────┐ ┌─────────┐  ┌──────────┐       │
              │  GitLab   │ │ Jenkins │  │  GitLab  │       │
              │           │ │         │  │  Runner  │       │
              └───────────┘ └─────────┘  └──────────┘       │
                   │                                         │
                   └─────────────────────────────────────────┘
```


## 1. 필요한 디렉토리 구조 생성하기

먼저 각 서비스의 데이터, 설정, 로그 등을 저장할 디렉토리 구조를 생성합니다.

```bash
sudo mkdir -p /data/gitlab/{data,config,logs}
sudo mkdir -p /data/gitlab-runner/config
sudo mkdir -p /data/jenkins/{data,logs}
sudo mkdir -p /data/nginx/{config,logs,certs}
sudo chmod -R 777 /data
```


## 2. Docker Compose 파일 작성

다음은 모든 서비스를 정의한 `docker-compose.yml` 파일입니다. 이 파일을 적절한 위치(예: `/data/docker-compose.yml`)에 저장하세요.

```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    hostname: gitlab.local
    restart: always
    volumes:
      - /data/gitlab/config:/etc/gitlab
      - /data/gitlab/logs:/var/log/gitlab
      - /data/gitlab/data:/var/opt/gitlab
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['initial_root_password'] = 'SecurePassword123'
        # 이메일 설정 비활성화
        gitlab_rails['smtp_enable'] = false
        # Nginx 설정 비활성화 (외부 Nginx 사용)
        nginx['enable'] = false
        gitlab_workhorse['listen_network'] = "tcp"
        gitlab_workhorse['listen_addr'] = "0.0.0.0:8181"
    ports:
      - "2222:22" # SSH 포트
    networks:
      - devops-network
    depends_on:
      - nginx

  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    restart: always
    volumes:
      - /data/gitlab-runner/config:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - devops-network
    depends_on:
      - gitlab

  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    restart: always
    volumes:
      - /data/jenkins/data:/var/jenkins_home
      - /data/jenkins/logs:/var/log/jenkins
      - /var/run/docker.sock:/var/run/docker.sock
    user: root
    environment:
      - JENKINS_OPTS="--prefix=/jenkins"
    networks:
      - devops-network
    depends_on:
      - nginx

  nginx:
    image: nginx:stable
    container_name: nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/nginx/config:/etc/nginx/conf.d
      - /data/nginx/logs:/var/log/nginx
      - /data/nginx/certs:/etc/nginx/certs
    networks:
      - devops-network

networks:
  devops-network:
    driver: bridge
```


## 3. Nginx 설정 파일 작성

Nginx에서 GitLab과 Jenkins로 트래픽을 라우팅하기 위한 설정 파일을 작성합니다. `/data/nginx/config/default.conf` 파일을 다음과 같이 작성하세요.

```nginx
# GitLab용 서버 블록
server {
    listen 80;
    server_name gitlab.local;
    
    # HTTP를 HTTPS로 리다이렉트
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name gitlab.local;

    # SSL 인증서 설정
    ssl_certificate /etc/nginx/certs/gitlab.local.crt;
    ssl_certificate_key /etc/nginx/certs/gitlab.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # GitLab 프록시 설정
    location / {
        proxy_pass http://gitlab:8181;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 로그 설정
    access_log /var/log/nginx/gitlab_access.log;
    error_log /var/log/nginx/gitlab_error.log;
}

# Jenkins용 서버 블록
server {
    listen 80;
    server_name jenkins.local;
    
    # HTTP를 HTTPS로 리다이렉트
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name jenkins.local;

    # SSL 인증서 설정
    ssl_certificate /etc/nginx/certs/jenkins.local.crt;
    ssl_certificate_key /etc/nginx/certs/jenkins.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Jenkins 프록시 설정
    location / {
        proxy_pass http://jenkins:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 로그 설정
    access_log /var/log/nginx/jenkins_access.log;
    error_log /var/log/nginx/jenkins_error.log;
}
```


## 4. SSL 인증서 생성

로컬 개발 환경을 위한 사설 인증서를 생성합니다.

### GitLab용 인증서 생성

```bash
cd /data/nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout gitlab.local.key -out gitlab.local.crt \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=DevOps/OU=Development/CN=gitlab.local"
```


### Jenkins용 인증서 생성

```bash
cd /data/nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout jenkins.local.key -out jenkins.local.crt \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=DevOps/OU=Development/CN=jenkins.local"
```


## 5. 호스트 파일 설정

로컬 도메인을 사용하기 위해 호스트 시스템의 `/etc/hosts` 파일에 다음 내용을 추가합니다.

```bash
sudo sh -c 'echo "127.0.0.1 gitlab.local jenkins.local" &gt;&gt; /etc/hosts'
```


## 6. Docker Compose 시작하기

설정이 완료되면 Docker Compose를 사용하여 모든 서비스를 시작합니다.

```bash
cd /data
docker-compose up -d
```

컨테이너가 모두 실행될 때까지 기다립니다. GitLab은 처음 시작 시 초기화에 약 5분 정도 소요될 수 있습니다.

```bash
docker-compose ps
```


## 7. GitLab 초기 설정

### GitLab 관리자 로그인

1. 웹 브라우저에서 `https://gitlab.local`로 접속합니다.
2. 사용자 이름으로 `root`를 입력하고, 비밀번호로 docker-compose.yml 파일에 설정한 `SecurePassword123`를 입력합니다.
3. 로그인 후 Settings -> Password에서 관리자 비밀번호를 변경하는 것을 권장합니다.

### 새 사용자 계정 생성 방법

1. Admin Area (렌치 아이콘) -> Users -> New user 클릭
2. 사용자 정보 입력 (이름, 이메일, 사용자 이름 등)
3. Create user 클릭
4. 생성된 사용자의 이메일로 비밀번호 설정 링크가 전송됩니다. (로컬 환경에서는 이메일 전송이 비활성화되어 있으므로 Edit 버튼을 클릭하여 수동으로 비밀번호 설정)

## 8. GitLab Runner 등록

GitLab Runner를 GitLab에 등록하기 위해 다음 단계를 따릅니다.

```bash
# GitLab Runner 컨테이너 접속
docker exec -it gitlab-runner bash

# GitLab Runner 등록
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.local/" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "docker-runner" \
  --tag-list "docker,aws" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected"
```

위 명령에서 `YOUR_REGISTRATION_TOKEN`은 GitLab에서 얻을 수 있습니다. GitLab에 로그인한 후:

1. Admin Area -> Overview -> Runners로 이동
2. "Register an instance runner" 섹션에서 등록 토큰을 확인할 수 있습니다[^2].

## 9. Jenkins 초기 설정

### Jenkins 관리자 비밀번호 확인

1. 다음 명령으로 Jenkins 초기 관리자 비밀번호를 확인합니다.
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```


### Jenkins 초기 설정 완료

1. 웹 브라우저에서 `https://jenkins.local`로 접속합니다.
2. 확인한 초기 관리자 비밀번호를 입력합니다.
3. "Install suggested plugins"를 선택하여 권장 플러그인을 설치합니다.
4. 관리자 계정 정보를 설정하고 "Save and Continue" 클릭
5. Jenkins URL 확인 후 "Save and Finish" 클릭
6. "Start using Jenkins" 클릭하여 설정 완료

### GitLab 연동 플러그인 설치

1. Jenkins 관리 -> 플러그인 관리 -> Available plugins 탭
2. "GitLab" 검색 후 설치
3. 설치 완료 후 Jenkins 재시작

## 10. 서비스 기본 사용 방법

### GitLab 프로젝트 생성

1. GitLab에 로그인
2. "New project" 클릭
3. 프로젝트 이름 입력 및 기타 설정 선택
4. "Create project" 클릭
5. 프로젝트 생성 후 git 명령어를 사용하여 코드 푸시 가능

### Jenkins 파이프라인 생성

1. Jenkins에 로그인
2. "New Item" 클릭
3. 아이템 이름 입력 및 "Pipeline" 선택
4. "OK" 클릭
5. 파이프라인 설정 (GitLab 연동, 빌드 트리거, 파이프라인 스크립트 등)
6. "Save" 클릭

### GitLab과 Jenkins 연동 설정

1. Jenkins에서 Credentials 추가 (GitLab API 토큰)
2. Jenkins 관리 -> System -> GitLab 섹션에서 연결 구성
3. GitLab 프로젝트에서 Webhooks 설정 (Settings -> Webhooks)
4. Jenkins 파이프라인에서 GitLab 트리거 설정[^1]

## 11. 서비스 간 데이터 흐름

이 통합 환경에서의 일반적인 데이터 흐름은 다음과 같습니다:

1. 개발자가 GitLab 저장소에 코드를 푸시합니다.
2. GitLab Webhook이 Jenkins에 빌드 트리거를 전송합니다.
3. Jenkins는 GitLab에서 코드를 가져와 파이프라인을 실행합니다.
4. GitLab Runner는 CI/CD 작업을 실행합니다.
5. 빌드/테스트 결과가 GitLab과 Jenkins에 보고됩니다.

## 12. 문제 해결 및 주의사항

### 서비스 로그 확인

각 서비스의 로그를 확인하여 문제를 진단할 수 있습니다.

```bash
# GitLab 로그
docker logs gitlab

# GitLab Runner 로그
docker logs gitlab-runner

# Jenkins 로그
docker logs jenkins

# Nginx 로그
docker logs nginx
```


### 브라우저 인증서 오류

자체 서명된 인증서를 사용하므로 브라우저에서 보안 경고가 표시될 수 있습니다. 개발 환경에서는 이 경고를 무시하고 진행할 수 있습니다.

### 권한 문제

볼륨 마운트에 권한 문제가 발생할 경우 다음 명령을 실행하여 권한을 조정할 수 있습니다.

```bash
sudo chown -R 1000:1000 /data/jenkins/data
```


## 결론

이 가이드를 통해 Docker Compose를 사용하여 GitLab, GitLab Runner, Jenkins, Nginx를 포함하는 통합 개발 환경을 성공적으로 구축할 수 있습니다. 이 환경은 현대적인 CI/CD 파이프라인을 위한 강력한 기반을 제공하며, 개발 팀이 효율적으로 협업할 수 있도록 지원합니다.

모든 서비스는 하나의 Docker Compose 파일로 관리되므로 환경 전체를 쉽게 시작, 중지, 재구성할 수 있습니다. 또한 볼륨 마운트를 통해 중요한 데이터가 컨테이너 외부에 저장되므로 컨테이너를 재생성하더라도 데이터가 유지됩니다.

지속적인 통합과 배포를 위한 이 환경을 기반으로 팀의 개발 워크플로우를 더욱 개선하고 자동화할 수 있습니다.

<div style="text-align: center">⁂</div>

[^1]: https://velog.io/@masibasi/CICD-Docker-기반-Jenkinslocal-GitlabVM-NginXOracle-3-Tier-CICD-구축-실습

[^2]: https://docs.gitlab.com/runner/register/

[^3]: https://ploz.tistory.com/entry/Gitlab-docker-초기-설치-후-root-password-강제-변경

[^4]: https://velog.io/@rungoat/CICD-Jenkins-설치-및-설정

[^5]: https://gksdudrb922.tistory.com/236

[^6]: https://insight.infograb.net/docs/cicd/local_runner_setting/

[^7]: https://yourusername.tistory.com/174

[^8]: https://blog.leocat.kr/notes/2020/02/16/jenkins-initial-admin-password-on-jenkins-docker-image

[^9]: https://a-half-human-half-developer.tistory.com/13

[^10]: https://www.youtube.com/watch?v=2koljDo0M70

[^11]: https://velog.io/@rectangle714/GitLab-초기-패스워드-확인-및-변경-방법

[^12]: https://yes-admit.tistory.com/91

[^13]: https://junuuu.tistory.com/443

[^14]: https://www.sangchul.kr/88

[^15]: https://not-to-be-reset.tistory.com/332

[^16]: https://svrforum.com/svr/57148

[^17]: https://blog.tetedo.com/313

[^18]: https://angellapgm.tistory.com/entry/gitlab-gitlab-root-초기-비밀번호-찾기

[^19]: https://workshop.infograb.io/setup-gitlab/3_setup_gitlab/4_verify_gitlab/

[^20]: https://baekji919.tistory.com/entry/GitLab-Self-managed-GitLab에-초기-로그인-방법

[^21]: https://velog.io/@habins226/Gitlab-Jenkins-Docker-Docker-Hub-Nginx-Blue-Green-무중단배포-CICD-구축-2

[^22]: https://sssbin.tistory.com/261

[^23]: https://woo1031.vercel.app/article/gitlab-cicd와-docker-executor로-nextjs-프로젝트-cicd-구축-과정

[^24]: https://yoonsu.tistory.com/25

[^25]: https://gist.github.com/benoitpetit/cbe19cdd369ec8c1e0defd245d91751f

[^26]: https://docs.gitlab.com/ci/docker/using_docker_images/

[^27]: https://stackoverflow.com/questions/47253978/auto-register-gitlab-runner

[^28]: https://insight.infograb.net/docs/setup/install_with_docker_compose/

[^29]: https://dncjf64.tistory.com/384

[^30]: https://adjh54.tistory.com/643

[^31]: https://tifferent.tistory.com/11

[^32]: https://precious-value.tistory.com/58

[^33]: https://www.sangchul.kr/197

[^34]: https://freedeveloper.tistory.com/181

[^35]: https://velog.io/@qkr135qkr/Jenkins-셋업하기

[^36]: https://angelplayer.tistory.com/521

<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

## GitLab Runner가 사설 인증서 및 사설 도메인 환경에서 연결되지 않는 문제 해결 방법

사설 인증서(자체 서명 인증서)와 사설 도메인(`.local` 등)을 사용하는 경우, GitLab Runner가 GitLab 서버와 통신 시 `x509: certificate signed by unknown authority` 또는 `SSL certificate problem: unable to get local issuer certificate`와 같은 오류가 발생할 수 있습니다. 이는 Runner 컨테이너 내부에서 GitLab 서버의 인증서를 신뢰하지 않기 때문입니다[^1][^2][^3].

아래는 문제 원인과 단계별 해결 방법입니다.

---

### **문제 원인**

- GitLab 서버가 자체 서명(사설 CA) 인증서를 사용
- GitLab Runner 컨테이너 내부에 해당 인증서가 신뢰 루트로 등록되어 있지 않음
- 따라서 HTTPS 통신 시 인증서 검증에 실패하여 연결이 거부됨

---

### **해결 방법**

#### 1. **사설 인증서 파일 준비**

- GitLab 서버에서 사용 중인 인증서(예: `gitlab.local.crt`) 파일을 호스트 시스템에 준비합니다.
    - 이 파일은 Nginx에서 SSL용으로 사용 중인 인증서와 동일해야 합니다.


#### 2. **Runner 컨테이너에 인증서 복사**

```bash
# 컨테이너 내부에 인증서 디렉터리 생성
docker exec -it gitlab-runner mkdir -p /etc/gitlab-runner/certs

# 호스트에서 Runner 컨테이너로 인증서 복사
docker cp /data/nginx/certs/gitlab.local.crt gitlab-runner:/etc/gitlab-runner/certs/gitlab.local.crt
```


#### 3. **Runner 컨테이너에서 인증서 신뢰 등록**

```bash
docker exec -it gitlab-runner bash -c "cp /etc/gitlab-runner/certs/gitlab.local.crt /usr/local/share/ca-certificates/gitlab.local.crt &amp;&amp; update-ca-certificates"
```

- 위 명령은 인증서를 시스템 신뢰 저장소에 추가하고, 신뢰 목록을 갱신합니다[^3].


#### 4. **GitLab Runner 컨테이너 재시작**

```bash
docker restart gitlab-runner
```

- 변경 사항이 적용되도록 Runner를 재시작합니다[^3].

---

### **(선택) GitLab 서버에 인증서 등록**

- GitLab 서버 자체에서도 신뢰 루트 인증서 디렉터리에 인증서를 추가해야 할 수 있습니다.
- 인증서를 `/etc/gitlab/trusted-certs/`에 복사한 뒤, 아래 명령 실행:

```bash
sudo gitlab-ctl reconfigure
```

- 인증서 변경이 감지되지 않으면, 해시 파일을 삭제 후 재구성:

```bash
sudo rm /var/opt/gitlab/trusted-certs-directory-hash
sudo gitlab-ctl reconfigure
```

---

### **(참고) Git 클라이언트에서 임시로 SSL 검증 비활성화**

- 보안상 권장되진 않지만, 임시로 아래 명령으로 SSL 검증을 끌 수 있습니다:

```bash
git config --global http.sslVerify false
```

- 실제 운영 환경에서는 반드시 인증서를 신뢰 저장소에 등록하는 방법을 사용하세요.

---

### **요약 및 권장사항**

- 사설 인증서를 사용하는 경우, GitLab Runner 컨테이너 내부에 해당 인증서를 복사하고 신뢰 루트로 등록해야 Runner가 정상적으로 GitLab 서버와 통신할 수 있습니다.
- 인증서 변경 후에는 반드시 Runner 컨테이너를 재시작해야 합니다.
- 보안을 위해 인증서 검증을 끄는 방법은 임시로만 사용하세요.

---

#### **참고: 공식 문서**

> "이 오류는 클라이언트가 인증서 또는 CA를 신뢰하지 않음을 나타냅니다. 이 오류를 해결하려면 서버에 연결하는 클라이언트가 인증서 또는 CA를 신뢰해야 합니다. ... 자체 서명된 인증서 또는 내부 루트 CA 인증서를 로컬 디렉토리에 복사하고 Git이 인증서를 신뢰하도록 설정합니다."[^1]

---

이 과정을 따라하면 사설 인증서, 사설 도메인 환경에서도 GitLab Runner가 GitLab 서버와 정상적으로 연동됩니다.

<div style="text-align: center">⁂</div>

[^1]: https://gitlab-docs.infograb.net/omnibus/settings/ssl/ssl_troubleshooting.html

[^2]: https://linux.systemv.pe.kr/devops/gitlab-docker-빌드시-x509-certificate-signed-by-unknown-authority-오류-해결/

[^3]: https://jinhos-devlog.tistory.com/entry/GitLab-Runner를-사용한-CICD-연동-및-자동화-테스트

[^4]: https://jost-do-it.tistory.com/entry/gitlab-server-certificate-verification-failed-해결-SSL-인증-문제

[^5]: https://engineeringcode.tistory.com/entry/Git에서-SSL-certificate-problem-self-signed-certificate-해결-방법

[^6]: https://ds2mgt.tistory.com/18

[^7]: https://gitlab-docs.infograb.net/runner/faq/

[^8]: https://velog.io/@dustndus8/클라우드Jenkins-Gitlab-runer-실습하기

