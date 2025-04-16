# 통합 테스트 가이드

## 1. 전체 시스템 상태 확인

### 1.1 서비스 상태 점검
각 서비스의 상태 확인:
```bash
# CI/CD 서비스
curl -k https://gitlab.local/health_check
curl -k https://jenkins.local/login
curl -k https://sonarqube.local/api/system/health

# 컨테이너 레지스트리
curl -k https://harbor.local/api/v2.0/health

# 애플리케이션
curl -k https://python-demo.local/health

# 모니터링
curl -k https://grafana.local/api/health
curl -k http://prometheus.local:9090/-/healthy
```

### 1.2 네트워크 연결성 테스트
```bash
# DNS 확인
for host in gitlab.local jenkins.local harbor.local sonarqube.local python-demo.local grafana.local; do
    dig +short $host
done

# 포트 연결성
for host in 172.16.10.{10,11,20,30,40}; do
    nc -zv $host 22
done
```

## 2. CI/CD 파이프라인 테스트

### 2.1 코드 변경 테스트
1. 소스 코드 수정:
```bash
cd python-demo
echo "# Test change" >> README.md
git add README.md
git commit -m "test: Add test comment"
git push origin main
```

2. 파이프라인 실행 확인:
   - GitLab 웹훅 트리거 확인
   - Jenkins 파이프라인 자동 시작 확인
   - 각 스테이지 성공 여부 확인

### 2.2 품질 게이트 테스트
1. 테스트 커버리지 확인:
```python
# tests/test_low_coverage.py
def test_uncovered_function():
    pass  # 커버리지를 낮추기 위한 테스트
```

2. 커버리지 리포트 생성:
```bash
pytest --cov=app tests/ --cov-report=xml
```

3. SonarQube 분석 실행 및 결과 확인

## 3. 컨테이너 레지스트리 테스트

### 3.1 이미지 푸시/풀 테스트
```bash
# 테스트 이미지 생성
docker build -t harbor.local/python-demo/test:latest .

# Harbor 로그인
docker login harbor.local -u kunkin

# 이미지 푸시
docker push harbor.local/python-demo/test:latest

# 이미지 풀
docker pull harbor.local/python-demo/test:latest
```

### 3.2 취약점 스캔 테스트
1. Harbor UI에서 스캔 실행
2. 스캔 결과 확인:
   - 심각도별 취약점 수
   - CVE 상세 정보
   - 수정 권장사항

## 4. 배포 테스트

### 4.1 롤아웃 테스트
1. 새 버전 배포:
```bash
# 버전 태그 생성
git tag v1.0.0
git push origin v1.0.0

# 배포 진행 상황 모니터링
watch docker ps
```

2. 헬스체크 모니터링:
```bash
while true; do 
    curl -k https://python-demo.local/health
    sleep 1
done
```

### 4.2 롤백 테스트
1. 이전 버전으로 롤백:
```bash
# 이전 태그로 체크아웃
git checkout v0.9.0

# 변경사항 커밋
git add .
git commit -m "rollback: Return to v0.9.0"
git push origin main
```

2. 롤백 후 서비스 상태 확인

## 5. 모니터링 테스트

### 5.1 메트릭 수집 테스트
1. 부하 테스트 실행:
```bash
# 5분간 부하 생성
hey -z 5m -c 50 https://python-demo.local/api/v1/items
```

2. Prometheus 메트릭 확인:
   - 요청 수
   - 응답 시간
   - 오류율
   - 시스템 리소스 사용량

### 5.2 알림 테스트
1. CPU 부하 생성:
```bash
# CPU 스트레스 테스트
stress --cpu 4 --timeout 300
```

2. 알림 전달 확인:
   - Slack 채널
   - 이메일
   - Grafana 알림

## 6. 장애 시나리오 테스트

### 6.1 서비스 장애 테스트
```bash
# 컨테이너 강제 종료
docker kill python-demo

# 복구 확인
watch docker ps
curl -k https://python-demo.local/health
```

### 6.2 네트워크 장애 테스트
```bash
# 네트워크 지연 시뮬레이션
sudo tc qdisc add dev eth0 root netem delay 100ms

# 지연 제거
sudo tc qdisc del dev eth0 root
```

## 7. 전체 시스템 검증

### 7.1 체크리스트
- [ ] GitLab 웹훅 정상 작동
- [ ] Jenkins 파이프라인 모든 스테이지 성공
- [ ] SonarQube 품질 게이트 통과
- [ ] Harbor 이미지 스캔 완료
- [ ] 애플리케이션 정상 배포
- [ ] Prometheus 메트릭 수집
- [ ] Grafana 대시보드 표시
- [ ] 알림 시스템 작동

### 7.2 문제 해결
공통적인 문제 해결 방법:

1. 로그 확인:
```bash
# 컨테이너 로그
docker logs -f container_name

# 시스템 로그
sudo journalctl -fu service_name
```

2. 네트워크 연결:
```bash
# DNS 확인
dig +short service_name

# 포트 확인
netstat -tuln
```

3. 디스크 공간:
```bash
# 디스크 사용량
df -h

# Docker 볼륨
docker system df -v
```

## 8. 성능 테스트

### 8.1 부하 테스트
```bash
# API 엔드포인트 부하 테스트
hey -n 10000 -c 100 https://python-demo.local/api/v1/items

# 결과 분석
- RPS (Requests per Second)
- 응답 시간 분포
- 오류율
```

### 8.2 확장성 테스트
```bash
# 컨테이너 스케일 아웃
docker-compose up -d --scale python-demo=3

# 부하 분산 확인
for i in {1..100}; do
    curl -k https://python-demo.local/health
done
```

## 마무리
모든 테스트가 완료되면, 시스템이 프로덕션 환경에서 사용할 준비가 된 것입니다. 
정기적으로 이 통합 테스트를 실행하여 시스템의 안정성을 확인하세요.