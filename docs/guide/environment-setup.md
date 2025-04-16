# 환경별 CICD 시스템 구성 가이드

## 1. 개발 환경 (Development)

### 1.1 시스템 요구사항
- CPU: 8코어
- 메모리: 16GB
- 디스크: 256GB
- OS: Ubuntu 24.04 LTS

### 1.2 서비스 구성
```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab

  jenkins:
    image: jenkins/jenkins:lts
    user: root
    ports:
      - "8080:8080"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock

  sonarqube:
    image: sonarqube:latest
    ports:
      - "9000:9000"
    environment:
      - sonar.jdbc.username=sonar
      - sonar.jdbc.password=sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
  jenkins_home:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
```

### 1.3 네트워크 설정
- 내부망만 접근 가능
- VPN을 통한 원격 접속
- 모든 서비스는 HTTP/HTTPS 사용
- 개발자 로컬 PC에서 직접 접근

### 1.4 보안 설정
- 기본 인증 사용
- HTTPS 선택적 사용
- 간단한 방화벽 규칙
- 로컬 테스트용 인증서

## 2. 스테이징 환경 (Staging)

### 2.1 시스템 요구사항
- CPU: 16코어
- 메모리: 32GB
- 디스크: 512GB
- OS: Ubuntu 24.04 LTS

### 2.2 서비스 구성
```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.staging.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['backup_keep_time'] = 604800
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G

  jenkins:
    image: jenkins/jenkins:lts
    user: root
    ports:
      - "8080:8080"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

  sonarqube:
    image: sonarqube:latest
    ports:
      - "9000:9000"
    environment:
      - sonar.jdbc.username=sonar
      - sonar.jdbc.password=sonar
      - sonar.jdbc.url=jdbc:postgresql://postgres:5432/sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
  jenkins_home:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgres_data:
```

### 2.3 네트워크 설정
- VPN을 통한 접근
- 프록시 서버 사용
- HTTPS 필수
- 내부망 분리

### 2.4 보안 설정
- LDAP 인증 사용
- SSL 인증서 필수
- 엄격한 방화벽 규칙
- 감사 로그 활성화

## 3. 운영 환경 (Production)

### 3.1 시스템 요구사항
- CPU: 32코어
- 메모리: 64GB
- 디스크: 1TB (SSD)
- OS: Ubuntu 24.04 LTS

### 3.2 서비스 구성
```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.production.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['backup_keep_time'] = 2592000
        gitlab_rails['monitoring_whitelist'] = ['127.0.0.0/8', '192.168.0.0/16']
        nginx['enable'] = true
        nginx['redirect_http_to_https'] = true
        nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
        nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"
    ports:
      - "443:443"
      - "2222:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
      - /etc/gitlab/ssl:/etc/gitlab/ssl:ro
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 16G
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s

  jenkins:
    image: jenkins/jenkins:lts
    user: root
    ports:
      - "8080:8080"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/ssl:/etc/ssl:ro
    environment:
      - JENKINS_OPTS="--httpPort=-1 --httpsPort=8080 --httpsKeyStore=/etc/ssl/jenkins.jks --httpsKeyStorePassword=changeit"
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s

  sonarqube:
    image: sonarqube:latest
    ports:
      - "9000:9000"
    environment:
      - sonar.jdbc.username=sonar
      - sonar.jdbc.password=sonar
      - sonar.jdbc.url=jdbc:postgresql://postgres:5432/sonar
      - sonar.web.javaAdditionalOpts=-server
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s

volumes:
  gitlab_config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/gitlab/config
  gitlab_logs:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/gitlab/logs
  gitlab_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/gitlab/data
  jenkins_home:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/jenkins
  sonarqube_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/sonarqube/data
  sonarqube_extensions:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/sonarqube/extensions
  sonarqube_logs:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/sonarqube/logs
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/postgres
```

### 3.3 네트워크 설정
- 전용선 사용
- 로드밸런서 구성
- DMZ 구성
- 이중화된 네트워크

### 3.4 보안 설정
- SSO 인증
- 하드웨어 보안 모듈 (HSM)
- IDS/IPS 구성
- 24/7 보안 모니터링

## 4. DR (재해복구) 환경

### 4.1 시스템 요구사항
- 운영 환경과 동일한 사양
- 지리적으로 분산된 위치
- 전용 백업 스토리지
- 이중화된 전원 공급

### 4.2 구성 특징
- 운영 환경과 동일한 구성
- 자동 페일오버 설정
- 실시간 데이터 복제
- 정기적인 DR 테스트

### 4.3 네트워크 설정
- 전용선 이중화
- BGP 라우팅
- 글로벌 로드밸런싱
- 자동 DNS 페일오버

### 4.4 보안 설정
- 운영 환경과 동일한 보안 정책
- 독립적인 인증 시스템
- 암호화된 데이터 복제
- 별도의 보안 모니터링

## 5. 공통 구성 요소

### 5.1 모니터링
- Prometheus + Grafana
- ELK 스택
- Alert Manager
- 업타임 모니터링

### 5.2 백업 정책
- 개발: 주간 백업
- 스테이징: 일간 백업
- 운영: 실시간 백업
- DR: 실시간 복제

### 5.3 로깅
- 중앙 집중식 로깅
- 로그 보관 기간 설정
- 로그 분석 도구
- 감사 로그 관리

### 5.4 보안 정책
- 접근 제어
- 취약점 스캔
- 보안 패치 관리
- 인시던트 대응

## 6. 환경별 특이사항

### 6.1 리소스 제한
|환경|CPU 제한|메모리 제한|디스크 IOPS|네트워크 대역폭|
|---|---------|-----------|------------|---------------|
|개발|최소|최소|제한 없음|제한 없음|
|스테이징|중간|중간|중간|중간|
|운영|최대|최대|최대|최대|
|DR|운영과 동일|운영과 동일|운영과 동일|운영과 동일|

### 6.2 접근 권한
|환경|개발자|운영자|관리자|
|---|------|------|------|
|개발|모든 권한|모든 권한|모든 권한|
|스테이징|제한된 권한|대부분 권한|모든 권한|
|운영|읽기 전용|제한된 권한|모든 권한|
|DR|접근 불가|제한된 권한|모든 권한|

### 6.3 배포 정책
|환경|배포 주기|승인 필요|롤백 정책|
|---|---------|---------|---------|
|개발|수시|불필요|자동|
|스테이징|일간|팀장|자동|
|운영|주간|관리자|수동|
|DR|운영과 동일|운영과 동일|운영과 동일|