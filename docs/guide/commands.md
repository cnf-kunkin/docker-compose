# CICD 시스템 명령어 모음집

## 1. Git 명령어

### 1.1 기본 작업
```bash
# 저장소 복제
git clone https://gitlab.local/kunkin/python-demo.git

# 브랜치 작업
git checkout -b feature/new-feature
git branch -l
git branch -D old-branch

# 변경사항 관리
git status
git add .
git commit -m "type: Add new feature"
git push origin feature/new-feature

# 메인 브랜치 동기화
git checkout main
git pull origin main
git merge feature/new-feature
```

### 1.2 고급 작업
```bash
# 커밋 수정
git commit --amend
git rebase -i HEAD~3

# 태그 관리
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 변경사항 임시 저장
git stash
git stash pop
```

## 2. Docker 명령어

### 2.1 컨테이너 관리
```bash
# 컨테이너 상태
docker ps
docker ps -a

# 컨테이너 생명주기
docker start container_name
docker stop container_name
docker restart container_name
docker rm container_name

# 로그 확인
docker logs -f container_name
docker logs --tail 100 container_name
```

### 2.2 이미지 관리
```bash
# 이미지 빌드
docker build -t image_name:tag .
docker build --no-cache -t image_name:tag .

# 이미지 관리
docker images
docker rmi image_name:tag
docker image prune -a

# 레지스트리 작업
docker login harbor.local
docker pull harbor.local/python-demo/app:latest
docker push harbor.local/python-demo/app:latest
```

### 2.3 Docker Compose
```bash
# 서비스 관리
docker-compose up -d
docker-compose down
docker-compose restart

# 로그 확인
docker-compose logs -f
docker-compose logs service_name

# 설정 검증
docker-compose config
docker-compose ps
```

## 3. Kubernetes 명령어

### 3.1 기본 작업
```bash
# 리소스 조회
kubectl get pods
kubectl get services
kubectl get deployments

# 로그 확인
kubectl logs pod_name
kubectl logs -f deployment/app-deployment

# 리소스 상세 정보
kubectl describe pod pod_name
kubectl describe service service_name
```

### 3.2 배포 관리
```bash
# 배포 수행
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml

# 롤백
kubectl rollout history deployment/app-deployment
kubectl rollout undo deployment/app-deployment

# 스케일링
kubectl scale deployment/app-deployment --replicas=3
```

## 4. Jenkins 파이프라인

### 4.1 파이프라인 관리
```groovy
// 파이프라인 문법
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t app:latest .'
            }
        }
    }
}

// 환경 변수 설정
environment {
    DOCKER_REGISTRY = 'harbor.local'
    IMAGE_NAME = 'python-demo'
}

// 조건부 실행
when {
    branch 'main'
    environment name: 'DEPLOY_TO', value: 'production'
}
```

### 4.2 스크립트 헬퍼
```groovy
// 인증 정보 사용
withCredentials([
    usernamePassword(
        credentialsId: 'harbor-creds',
        usernameVariable: 'HARBOR_USER',
        passwordVariable: 'HARBOR_PASS'
    )
]) {
    sh 'docker login ${DOCKER_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PASS}'
}

// 타임아웃 설정
timeout(time: 1, unit: 'HOURS') {
    sh './long-running-task.sh'
}
```

## 5. 모니터링 명령어

### 5.1 Prometheus
```bash
# 상태 확인
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:9090/-/ready

# 설정 리로드
curl -X POST http://localhost:9090/-/reload

# 쿼리 예제
curl 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up'
```

### 5.2 Grafana
```bash
# API 토큰 생성
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"api_key", "role": "Admin"}' \
  http://admin:admin@localhost:3000/api/auth/keys

# 대시보드 관리
curl -X GET http://localhost:3000/api/dashboards/uid/dashboard_uid \
  -H "Authorization: Bearer $API_KEY"
```

## 6. 로그 분석

### 6.1 로그 검색
```bash
# 실시간 로그 확인
tail -f /data/logs/application.log | grep ERROR

# 특정 시간대 로그
sed -n '/2024-04-15 10:00/,/2024-04-15 11:00/p' /data/logs/application.log

# 에러 로그 추출
grep -r "ERROR" /data/logs/ > errors.log
```

### 6.2 로그 처리
```bash
# 로그 압축
find /data/logs -name "*.log" -mtime +7 -exec gzip {} \;

# 용량 확인
du -sh /data/logs/*

# 오래된 로그 삭제
find /data/logs -name "*.log" -mtime +30 -delete
```

## 7. 시스템 관리

### 7.1 리소스 모니터링
```bash
# CPU/메모리 사용량
top
htop
free -h

# 디스크 사용량
df -h
du -sh /*
ncdu /

# 네트워크 상태
netstat -tulpn
ss -tunlp
```

### 7.2 서비스 관리
```bash
# 서비스 상태
systemctl status service_name
systemctl restart service_name
journalctl -u service_name

# 프로세스 관리
ps aux | grep process_name
kill -9 process_id
pkill process_name
```

## 8. SSL/인증서

### 8.1 인증서 관리
```bash
# 인증서 정보 확인
openssl x509 -in cert.pem -text -noout

# 인증서 만료일 확인
openssl x509 -enddate -noout -in cert.pem

# 인증서 체인 검증
openssl verify -CAfile ca.crt cert.pem
```

### 8.2 SSL 테스트
```bash
# SSL 연결 테스트
openssl s_client -connect domain:443

# 인증서 체인 다운로드
openssl s_client -connect domain:443 -showcerts

# SSL 상태 확인
curl -vI https://domain
```