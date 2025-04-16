# CICD 시스템 트러블슈팅 가이드

## 1. GitLab 관련 문제

### 1.1 웹훅 동작 안 함
문제: GitLab 웹훅이 Jenkins를 트리거하지 않음

해결 방법:
1. 웹훅 URL 확인:
```bash
curl -v https://jenkins.local/gitlab-webhook/
```

2. Jenkins 로그 확인:
```bash
docker logs jenkins | grep "Webhook"
```

3. 일반적인 해결책:
- SSL 인증서 문제: 인증서 갱신 또는 검증 비활성화
- 네트워크 문제: 방화벽 규칙 확인
- 권한 문제: Jenkins 시스템 설정의 CSRF 설정 확인

### 1.2 Git Push 실패
문제: Git push 명령 실패

해결 방법:
1. 인증 확인:
```bash
git config --list | grep credential
```

2. SSL 인증서 문제:
```bash
git config --global http.sslVerify false  # 임시 해결책
```

## 2. Jenkins 관련 문제

### 2.1 파이프라인 빌드 실패
문제: Jenkins 파이프라인이 특정 단계에서 실패

해결 방법:
1. 빌드 로그 확인:
- Blue Ocean 인터페이스에서 각 단계 검사
- 빨간색으로 표시된 단계의 로그 확인

2. 일반적인 해결책:
- 도커 권한: jenkins 사용자 docker 그룹 추가
- Workspace 권한: chmod -R 777 workspace
- 메모리 부족: Jenkins 컨테이너 메모리 제한 확인

### 2.2 플러그인 문제
문제: Jenkins 플러그인 충돌 또는 동작 안 함

해결 방법:
1. 플러그인 캐시 초기화:
```bash
rm -rf $JENKINS_HOME/plugins/*.lock
docker restart jenkins
```

2. 플러그인 의존성 확인:
- Jenkins 관리 > Plugin Manager > Advanced
- Check Now 클릭하여 업데이트 확인

## 3. Harbor 관련 문제

### 3.1 이미지 Push 실패
문제: Docker push 명령이 실패

해결 방법:
1. 로그인 상태 확인:
```bash
docker login harbor.local
```

2. 인증서 문제:
```bash
sudo mkdir -p /etc/docker/certs.d/harbor.local
sudo cp ca.crt /etc/docker/certs.d/harbor.local/
```

### 3.2 디스크 공간 부족
문제: Harbor에서 디스크 공간 부족 경고

해결 방법:
1. 가비지 컬렉션 실행:
- Harbor UI > Configuration > Garbage Collection
- Run Garbage Collection 클릭

2. 오래된 이미지 정리:
```bash
docker system prune -a
```

## 4. 애플리케이션 배포 문제

### 4.1 컨테이너 시작 실패
문제: 애플리케이션 컨테이너가 시작되지 않음

해결 방법:
1. 로그 확인:
```bash
docker logs python-demo
docker-compose logs
```

2. 상태 확인:
```bash
docker ps -a
docker-compose ps
```

### 4.2 헬스체크 실패
문제: 애플리케이션 헬스체크 실패

해결 방법:
1. 엔드포인트 확인:
```bash
curl -v http://localhost:8000/health
```

2. 로그 확인:
```bash
tail -f /data/logs/python/application.log
```

## 5. 모니터링 문제

### 5.1 메트릭 수집 안 됨
문제: Prometheus가 메트릭을 수집하지 못함

해결 방법:
1. 타겟 상태 확인:
- Prometheus UI > Targets
- Status 확인

2. 설정 검증:
```bash
curl http://localhost:9090/-/config
```

### 5.2 알림 발송 실패
문제: AlertManager 알림이 전송되지 않음

해결 방법:
1. AlertManager 설정 확인:
```bash
curl -X GET http://localhost:9093/-/config
```

2. 알림 상태 확인:
- AlertManager UI > Alerts
- Silence 상태 확인

## 6. 네트워크 문제

### 6.1 서비스 간 통신 실패
문제: 서비스 간 네트워크 통신이 안 됨

해결 방법:
1. DNS 확인:
```bash
nslookup service-name
dig +short service-name
```

2. 네트워크 연결성 테스트:
```bash
ping service-name
telnet service-name port
```

### 6.2 SSL/TLS 문제
문제: SSL 인증서 관련 오류

해결 방법:
1. 인증서 상태 확인:
```bash
openssl x509 -in cert.pem -text -noout
```

2. 인증서 갱신:
```bash
./generate-certs.sh
```

## 7. 시스템 리소스 문제

### 7.1 메모리 부족
문제: 시스템 또는 컨테이너 메모리 부족

해결 방법:
1. 메모리 사용량 확인:
```bash
free -h
docker stats
```

2. 스왑 사용량 확인:
```bash
swapon -s
```

### 7.2 디스크 공간 부족
문제: 디스크 공간 부족

해결 방법:
1. 디스크 사용량 확인:
```bash
df -h
du -sh /*
```

2. 도커 리소스 정리:
```bash
docker system prune -af
docker volume prune -f
```

## 8. 긴급 복구 절차

### 8.1 전체 시스템 복구
심각한 장애 발생 시 복구 절차:

1. 서비스 상태 확인:
```bash
for service in gitlab jenkins harbor sonarqube; do
    docker-compose -f $service/docker-compose.yml ps
done
```

2. 데이터 백업 확인:
```bash
ls -l /backup/*
```

3. 단계별 복구:
- 데이터 복원
- 서비스 재시작
- 설정 검증
- 연동 테스트

### 8.2 장애 보고서 작성
문제 해결 후 장애 보고서 작성:

1. 장애 내용
- 발생 시간
- 영향 범위
- 증상

2. 조치 사항
- 임시 조치
- 영구 조치
- 재발 방지 대책

## 9. 모니터링 대시보드

### 9.1 시스템 상태 확인
Grafana 대시보드 URL:
- 시스템 개요: https://grafana.local/d/system-overview
- 애플리케이션 상태: https://grafana.local/d/application-status
- 로그 분석: https://grafana.local/d/log-analysis

### 9.2 알림 설정 확인
AlertManager 설정:
- 알림 규칙: /etc/alertmanager/rules/
- 수신자 설정: /etc/alertmanager/alertmanager.yml