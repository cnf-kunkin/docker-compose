# Harbor 레지스트리 설정 가이드

## 1. Harbor 초기 설정

### 1.1 레지스트리 설정
1. Harbor (https://harbor.local) 접속 후 kunkin 계정으로 로그인
2. Projects > python-demo 프로젝트 선택
3. Configuration 탭에서:
   - Enable Content Trust: 활성화
   - Automatically scan images on push: 활성화
   - Prevent vulnerable images from running: 활성화
     - Severity: High 이상
     - CVE Allowlist: 필요한 CVE ID 추가

### 1.2 리포지토리 구성
1. python-demo 프로젝트의 Repositories 탭:
   - python-demo 리포지토리 확인
   - Tag Retention Policy 설정:
     - 최근 10개 태그 유지
     - 30일 이상 된 이미지 자동 삭제

## 2. 취약점 스캐닝 설정

### 2.1 스캐너 설정
1. Administration > Interrogation Services
2. Scanner Pool:
   - Trivy 스캐너 설정
   - 스캔 주기: 매일
   - 취약점 데이터베이스 자동 업데이트: 활성화

### 2.2 스캔 정책
1. python-demo 프로젝트의 Configuration:
   - Auto Scan on Push: 활성화
   - Scan on Schedule: 매주 일요일 새벽 3시
   - CVE Whitelist 설정

## 3. 접근 제어 설정

### 3.1 로봇 계정 생성
1. python-demo 프로젝트의 Robot Accounts:
2. New Robot Account:
   - Name: python-demo-robot
   - Description: CI/CD Pipeline Robot Account
   - Permissions:
     - Push: 활성화
     - Pull: 활성화
     - Scanner: 활성화

### 3.2 Docker 클라이언트 설정
각 클라이언트에서 실행:
```bash
# Harbor 인증서 설치
sudo mkdir -p /etc/docker/certs.d/harbor.local
sudo cp ca.crt /etc/docker/certs.d/harbor.local/

# Docker 데몬 재시작
sudo systemctl restart docker

# 로그인 테스트
docker login harbor.local -u kunkin
```

## 4. 이미지 관리

### 4.1 태그 관리 정책
1. python-demo 리포지토리 설정:
   - Immutable Tags: production-* 패턴
   - Tag Retention:
     - 최신 10개 development 태그
     - 모든 production 태그
     - 모든 release-* 태그

### 4.2 복제 정책
1. Administration > Replications
2. New Replication Rule:
   - Name: Backup-to-DR
   - Source Registry: harbor.local
   - Destination Registry: dr-harbor.local
   - Trigger Mode: 
     - Event Based
     - Scheduled (매일 새벽 2시)

## 5. 모니터링 설정

### 5.1 로그 설정
1. Administration > Configuration > Log:
   - Log Retention: 90일
   - External Syslog: 활성화
   - Syslog Endpoint: monitoring.local:514

### 5.2 알림 설정
1. Administration > Email:
   - Email Server: smtp.local
   - From: harbor@local
   - Test 이메일 발송

2. Administration > Webhooks:
   - Jenkins 알림
   - Slack 알림 (선택사항)

## 6. 성능 최적화

### 6.1 가비지 컬렉션
1. Administration > Garbage Collection
2. Schedule:
   - 매주 일요일 새벽 4시
   - Delete Untagged Artifacts: 활성화
   - Delete Empty Folders: 활성화

### 6.2 캐시 설정
1. Administration > Configuration > System
2. Redis 캐시 설정:
   - Cache Update Interval: 10분
   - Cache Cleanup Interval: 24시간

## 7. 보안 강화

### 7.1 OIDC 설정 (선택사항)
1. Administration > Configuration > Authentication:
   - Auth Mode: OIDC
   - OIDC Provider: Keycloak
   - 자동 사용자 생성: 비활성화

### 7.2 이미지 서명
1. python-demo 프로젝트의 Configuration:
   - Enable Content Trust: 활성화
   - Notary 서버 설정
2. 클라이언트 설정:
```bash
# Notary 설정
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.harbor.local
```

## 8. 운영 가이드

### 8.1 백업 절차
1. 정기 백업 설정:
```bash
# 백업 스크립트
harbor-backup.sh \
  --backup-registry \
  --backup-chartmuseum \
  --backup-trivy \
  --output-dir /backup/harbor
```

### 8.2 장애 복구 절차
1. 기본 복구 절차:
```bash
# 복구 스크립트
harbor-restore.sh \
  --input-dir /backup/harbor \
  --restore-registry \
  --restore-chartmuseum \
  --restore-trivy
```

## 다음 단계
Harbor 설정이 완료되면, [애플리케이션 배포](./08-application-deployment.md) 가이드로 진행하세요.