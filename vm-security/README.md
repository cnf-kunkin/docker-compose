<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# SonarQube Community Edition Docker Compose 설치 가이드

이 가이드는 Ubuntu 24 환경에서 Docker Compose를 사용하여 SonarQube Community Edition을 설치하고, 사설 인증서를 통해 HTTPS로 안전하게 서비스를 제공하는 방법을 상세히 설명합니다. 초보자도 쉽게 따라할 수 있도록 각 단계와 아키텍처를 시각적으로 제시하였습니다.

## 서론

SonarQube는 정적 코드 분석을 통해 코드 품질과 보안 취약점을 지속적으로 검사하는 오픈소스 플랫폼입니다. 29개 이상의 프로그래밍 언어를 지원하며, 코드의 버그, 코드 스멜, 보안 취약점 등을 감지해 개발 품질을 향상시키는 데 중요한 도구입니다[^1][^5].

Docker Compose를 사용하여 SonarQube를 설치하면 여러 컨테이너(SonarQube, PostgreSQL, Nginx 등)를 단일 명령어로 구성하고 관리할 수 있어 복잡한 설정 과정이 간소화됩니다. 또한 환경 격리로 다른 애플리케이션과의 충돌을 방지하고, 업그레이드 및 마이그레이션이 용이하다는 장점이 있습니다[^2][^5].

이 가이드는 Docker와 시스템 관리에 대한 기본 지식을 가진 IT 운영자, 개발자, DevOps 엔지니어를 대상으로 합니다만, 초보자도 단계별 지침을 따라 성공적으로 설치할 수 있도록 구성했습니다.

## 사전 준비

### Ubuntu 24 서버 준비

본 가이드를 위해 다음 사양의 Ubuntu 24.04 LTS 서버를 준비합니다:

- CPU: 2코어 이상
- 메모리: 4GB 이상 (SonarQube와 ElasticSearch 요구사항)
- 디스크: 20GB 이상 여유 공간


### Docker 및 Docker Compose 설치

먼저 Docker와 Docker Compose가 설치되어 있는지 확인합니다:

```bash
docker --version
docker compose version
```

### 디렉토리 구조 생성

SonarQube 데이터, 로그, 설정 파일을 영구적으로 저장할 디렉토리를 생성합니다[^1]:

```bash
# 기본 디렉토리 구조 생성
sudo mkdir -p /data/docker-compose/nginx/ssl
sudo mkdir -p /data/docker-compose/nginx/conf.d


# 권한 설정 (Docker 실행 사용자에게 쓰기 권한 부여)
sudo chmod -R 777 /data
```

### 사설 인증서 생성

HTTPS 서비스를 위한 사설 인증서를 생성합니다:

```bash
# 인증서 생성 디렉토리로 이동
cd /data/docker-compose/nginx/ssl

# OpenSSL 설치 확인 또는 설치
sudo apt install -y openssl
# 개인키 생성
openssl genrsa -out sonarqube.local.key 2048

# CSR(Certificate Signing Request) 생성
openssl req -new -key sonarqube.local.key -out sonarqube.local.csr -subj "/CN=sonarqube.local/O=SonarQube/C=KR"

# 자체 서명된 인증서 생성
openssl x509 -req -days 3650 -in sonarqube.local.csr -signkey sonarqube.local.key -out sonarqube.local.crt

# 권한 설정
chmod 644 sonarqube.local.crt
chmod 600 sonarqube.local.key
```

### Nginx 설정 파일 생성

Nginx 설정 파일을 생성합니다:

```bash

vi /data/docker-compose/nginx/conf.d/sonarqube.conf
```

다음 내용을 추가합니다:

```nginx
# HTTP를 HTTPS로 리다이렉트
server {
    listen 80;
    server_name sonarqube.local;
    return 301 https://$host$request_uri;
}

# HTTPS 서버 설정
server {
    listen 443 ssl;
    server_name sonarqube.local;

    ssl_certificate /etc/nginx/ssl/sonarqube.local.crt;
    ssl_certificate_key /etc/nginx/ssl/sonarqube.local.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/sonarqube.access.log;
    error_log /var/log/nginx/sonarqube.error.log;

    location / {
        proxy_pass http://sonarqube:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 지원
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 타임아웃 설정
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
    }
}
```

## Docker Compose 설정

### docker-compose.yml 파일 생성
cd /data/docker-compose
vi docker-compose.yml

`/data/docker-compose` 디렉토리에 `docker-compose.yml` 파일을 생성합니다:


```yaml
version: '3.8'

services:
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube
    depends_on:
      - db
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar_password
    volumes:
      - /data/sonarqube/data:/opt/sonarqube/data
      - /data/sonarqube/logs:/opt/sonarqube/logs
      - /data/sonarqube/conf:/opt/sonarqube/conf
      - /data/sonarqube/extensions:/opt/sonarqube/extensions
    expose:
      - 9000
    networks:
      - sonarnet
    ulimits:
      nofile:
        soft: 131072
        hard: 131072
    restart: always

  db:
    image: postgres:15
    container_name: sonarqube-db
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar_password
      - POSTGRES_DB=sonar
    volumes:
      - /data/postgresql:/var/lib/postgresql
      - /data/postgresql_data:/var/lib/postgresql/data
    networks:
      - sonarnet
    restart: always

  nginx:
    image: nginx:latest
    container_name: sonarqube-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/docker-compose/nginx/conf.d:/etc/nginx/conf.d
      - /data/docker-compose/nginx/ssl:/etc/nginx/ssl
      - /data/nginx/logs:/var/log/nginx
    depends_on:
      - sonarqube
    networks:
      - sonarnet
    restart: always

networks:
  sonarnet:
    driver: bridge
```


## 설치 및 실행

### Docker Compose로 서비스 시작

모든 설정이 완료되면 Docker Compose로 서비스를 시작합니다[^2][^5]:

```bash
sudo chmod -R 777 /data
cd /data/docker-compose
sudo docker compose up -d
```

이 명령은 세 개의 컨테이너(SonarQube, PostgreSQL, Nginx)를 백그라운드에서 실행합니다.

### 컨테이너 상태 확인

컨테이너가 제대로 실행되었는지 확인합니다:

```bash
docker compose ps
```

성공적으로 설치되면 다음과 같이 모든 컨테이너가 'Up' 상태로 표시됩니다:

```
NAME            IMAGE                        COMMAND                  SERVICE         CREATED          STATUS          PORTS
sonarqube       sonarqube:lts-community      "..."                    sonarqube       10 seconds ago   Up 9 seconds    9000/tcp
sonarqube-db    postgres:15                  "postgres"               db              10 seconds ago   Up 9 seconds    5432/tcp
sonarqube-nginx nginx:latest                 "nginx -g 'daemon ..."   nginx           10 seconds ago   Up 9 seconds    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```


### 로그 확인

각 컨테이너의 로그를 확인하여 오류가 없는지 확인합니다:

```bash
# SonarQube 로그 확인
docker compose logs sonarqube

# PostgreSQL 로그 확인
docker compose logs db

# Nginx 로그 확인
docker compose logs nginx

# 모든 로그를 실시간으로 확인 (Ctrl+C로 종료)
docker compose logs -f
```

SonarQube 로그에서 "SonarQube is operational" 메시지가 표시되면 성공적으로 시작된 것입니다.

## SonarQube 초기 설정

### 웹 접속 방법

브라우저에서 `https://sonarqube.local`로 접속하여 SonarQube 웹 인터페이스에 액세스합니다.

> **참고**: 자체 서명된 인증서를 사용하기 때문에 브라우저에서 보안 경고가 표시될 수 있습니다. 개발 또는 테스트 환경에서는 '고급' 옵션을 클릭한 후 '안전하지 않은 사이트로 이동' 옵션을 선택하여 계속 진행할 수 있습니다.

### 초기 관리자 계정 설정

SonarQube의 초기 기본 로그인 정보[^5]:

- 사용자명: admin
- 비밀번호: admin

첫 로그인 시 비밀번호 변경을 요청받습니다. 안전한 새 비밀번호를 설정하세요.

### 필요한 플러그인 설치

SonarQube에는 다양한 프로그래밍 언어 및 도구를 지원하는 플러그인이 있습니다. 필요한 플러그인을 설치하려면:

1. 관리자로 로그인
2. 상단 메뉴에서 'Administration' 선택
3. 왼쪽 메뉴에서 'Marketplace' 선택
4. 필요한 플러그인 검색 및 설치 (Java, JavaScript, Python 등)
5. 설치 후 SonarQube 재시작 필요할 수 있음:

```bash
cd /data/sonarqube
docker compose restart sonarqube
```


## 아키텍처 이해

### SonarQube 주요 컴포넌트

SonarQube는 다음과 같은 주요 컴포넌트로 구성됩니다:

1. **SonarQube 서버**: 웹 인터페이스, 웹 API, 계산 엔진을 포함하는 코어 서버
2. **SonarQube 데이터베이스**: 설정, 분석 결과, 사용자 정보 등을 저장 (PostgreSQL)
3. **SonarQube 스캐너**: 소스 코드를 분석하여 결과를 서버로 전송하는 클라이언트 도구
4. **Elasticsearch**: 코드 분석 결과를 검색 가능한 형태로 저장하는 검색 엔진 (SonarQube 서버 내장)

### 컨테이너 구성 다이어그램

```
+-------------------------------------------------------+
|                     클라이언트                         |
|           (웹 브라우저, SonarQube 스캐너)              |
+-------------------------+-----------------------------+
                          |
                          | HTTPS 요청 (443)
                          v
+-------------------------------------------------------+
|                      Nginx                            |
|              (리버스 프록시, TLS 종단)                  |
|              설정: /data/docker-compose/nginx/conf.d              |
|              인증서: /data/docker-compose/nginx/ssl         |
+-------------------------+-----------------------------+
                          |
                          | HTTP 내부 요청 (9000)
                          v
+-------------------------------------------------------+
|                    SonarQube                          |
|           (코드 품질 및 보안 분석 서버)                 |
|  +-------------------------------------------------+  |
|  |                 웹 서버                         |  |
|  +-------------------------------------------------+  |
|  |                 계산 엔진                       |  |
|  +-------------------------------------------------+  |
|  |               Elasticsearch                     |  |
|  +-------------------------------------------------+  |
|   저장 경로:                                          |
|   - /data/sonarqube/data                             |
|   - /data/sonarqube/logs                             |
|   - /data/sonarqube/conf                             |
|   - /data/sonarqube/extensions                       |
+-------------------------+-----------------------------+
                          |
                          | JDBC 접속 (5432)
                          v
+-------------------------------------------------------+
|                   PostgreSQL                          |
|                  (데이터베이스)                        |
|   저장 경로:                                          |
|   - /data/postgresql                        |
|   - /data/postgresql/postgresql_data                   |
+-------------------------------------------------------+
```


### HTTPS 요청 처리 흐름

다음 다이어그램은 클라이언트의 HTTPS 요청이 처리되는 흐름을 보여줍니다:

```
+----------------+    HTTPS     +----------------+
|                |    요청      |                |
|    클라이언트   +------------->+     Nginx      |
|  (웹 브라우저)  |  (443 포트)  |  (리버스 프록시) |
+----------------+              +-------+--------+
                                      |
                                      | HTTP 내부 요청 전달
                                      | (9000 포트)
                                      v
+----------------+            +----------------+
|                |   데이터    |                |
|   PostgreSQL   +<-----------+   SonarQube    |
|  (데이터베이스)  |    조회     |    (서버)      |
+----------------+            +----------------+
      ^                              |
      |                             |
      +-----------------------------+
            데이터 저장/검색
```


## Troubleshooting

### 컨테이너가 시작되지 않는 문제

**문제**: `docker compose up -d` 명령 후 컨테이너가 시작되지 않습니다.

**해결 방법**:

1. 컨테이너 로그 확인:

```bash
docker compose logs
```

2. ElasticSearch 시스템 요구 사항 충족 여부 확인[^3][^4]:

```bash
sysctl vm.max_map_count
```

값이 262144가 아니면 다시 설정:

```bash
sudo sysctl -w vm.max_map_count=262144
```


### 데이터베이스 연결 오류

**문제**: SonarQube 로그에 데이터베이스 연결 오류가 발생합니다.

**해결 방법**:

1. PostgreSQL 컨테이너가 실행 중인지 확인:

```bash
docker compose ps db
```

2. 환경 변수가 올바르게 설정되었는지 확인:

```bash
docker compose config
```

3. PostgreSQL 컨테이너 재시작:

```bash
docker compose restart db
```


### HTTPS 접속 문제

**문제**: `https://sonarqube.local`에 접속할 수 없습니다.

**해결 방법**:

1. `/etc/hosts` 파일에 올바르게 설정되었는지 확인:

```bash
cat /etc/hosts | grep sonarqube.local
```

2. Nginx 컨테이너가 실행 중인지 확인:

```bash
docker compose ps nginx
```

3. Nginx 설정 테스트:

```bash
docker exec sonarqube-nginx nginx -t
```

4. Nginx 로그 확인:

```bash
docker compose logs nginx
```

5. SSL 인증서 권한 및 경로 확인:

```bash
ls -la /data/sonarqube/nginx/ssl/
```


### 권한 문제

**문제**: 볼륨 디렉토리에 쓰기 권한이 없어 오류가 발생합니다.

**해결 방법**:

1. 볼륨 디렉토리의 권한 확인:

```bash
ls -la /data/sonarqube/
```

2. 권한 수정 (SonarQube는 일반적으로 UID 1000으로 실행):

```bash
sudo chown -R 1000:1000 /data/sonarqube/data /data/sonarqube/logs /data/sonarqube/extensions
```


## 결론

이 가이드에서는 Docker Compose를 사용하여 Ubuntu 24 환경에 SonarQube Community Edition을 설치하고, 사설 인증서를 통해 HTTPS로 안전하게 서비스를 제공하는 방법을 살펴보았습니다. 주요 구성 요소인 SonarQube, PostgreSQL, Nginx을 컨테이너로 구성하여 확장성과 유지 관리가 용이한 환경을 구축했습니다.

SonarQube는 코드 품질을 지속적으로 모니터링하고 개선함으로써, 버그와 보안 취약점을 조기에 발견하고, 기술적 부채를 관리하여 프로젝트의 장기적인 유지보수성을 향상시키는 데 큰 도움이 됩니다.

Docker Compose를 활용한 이 설정은 다음과 같은 이점을 제공합니다:

- 간편한 설치 및 관리: 단일 명령어로 전체 환경 구성
- 데이터 영속성: 볼륨 마운트를 통해 컨테이너가 재시작되어도 데이터 유지
- HTTPS 보안: Nginx을 통한 안전한 연결 제공
- 확장성: 필요에 따라 컨테이너 구성 쉽게 수정 가능

다음 단계로는 다음을 고려해 볼 수 있습니다:

- CI/CD 파이프라인과 SonarQube 통합
- 실제 도메인에 Let's Encrypt 인증서 적용
- LDAP 또는 OAuth를 통한 사용자 인증 통합
- 백업 및 복구 전략 구현

이제 SonarQube를 통해 코드 품질 관리를 시작하고, 더 나은 소프트웨어 개발 프로세스를 구축하시기 바랍니다.

<div style="text-align: center">⁂</div>

[^1]: https://docs.sonarsource.com/sonarqube-community-build/setup-and-upgrade/installing-sonarqube-from-docker/

[^2]: https://iesay.tistory.com/225

[^3]: https://blog.opendocs.co.kr/?p=711

[^4]: https://www.heyvaldemar.com/install-sonarqube-using-docker-compose/

[^5]: https://gblee1987.tistory.com/105

[^6]: https://jeffrey-oh.tistory.com/395

[^7]: https://ddangjiwon.tistory.com/351

[^8]: https://community.sonarsource.com/t/sonarqube-with-reverse-proxy-traefik-and-gitlab-certificate-issue-self-signed/38606/3

[^9]: https://velog.io/@blacknwhites/docker-compose를-이용한-SonarQube-도입기

[^10]: https://kkang-joo.tistory.com/67

[^11]: https://dlwnsdud205.tistory.com/350

[^12]: https://tommypagy.tistory.com/86

[^13]: https://github.com/heyValdemar/sonarqube-traefik-letsencrypt-docker-compose/blob/main/sonarqube-traefik-letsencrypt-docker-compose.yml

[^14]: https://psychoria.tistory.com/791

[^15]: https://openwiki.tistory.com/3

[^16]: https://velog.io/@nhj7804/CICD5-SonarQube-설치

[^17]: https://velog.io/@johnsuhr4542/Traefik-on-Docker

[^18]: https://community.traefik.io/t/using-ports-endpoints-for-containers/9386

[^19]: https://betwe.tistory.com/entry/Docker-도커의-모든-것-도커-추천-이미지

[^20]: https://techblog.tabling.co.kr/기술공유-정적-코드-분석-sonarqube-6b59fa9b6b85

