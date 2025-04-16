# CICD 시스템 퀵 스타트 가이드

## 1. 개요

### 1.1 시스템 구성
- GitLab: 소스 코드 관리
- Jenkins: CI/CD 파이프라인
- SonarQube: 코드 품질 분석
- Harbor: 컨테이너 레지스트리
- Grafana: 모니터링 대시보드

### 1.2 필요 도구
- Git 클라이언트
- Docker Desktop
- Visual Studio Code
- Postman (선택사항)
- Chrome 또는 Firefox

## 2. 초기 설정 (30분)

### 2.1 개발 환경 설정
1. hosts 파일 수정 (C:\Windows\System32\drivers\etc\hosts):
```
172.16.10.10   gitlab.local jenkins.local
172.16.10.11   harbor.local
172.16.10.20   grafana.local prometheus.local
172.16.10.30   sonarqube.local
172.16.10.40   python-demo.local
```

2. SSL 인증서 설치:
```bash
# 인증서 다운로드
cd ~/Downloads
curl -k https://gitlab.local/ca.crt -o ca.crt

# Windows 인증서 저장소에 추가
certutil -addstore -f "ROOT" ca.crt
```

### 2.2 계정 설정
1. kunkin 계정으로 각 서비스 로그인 테스트:
- https://gitlab.local
- https://jenkins.local
- https://harbor.local
- https://sonarqube.local
- https://grafana.local

2. Git 설정:
```bash
git config --global user.name "Kunkin"
git config --global user.email "kunkin@local.domain"
```

## 3. 첫 번째 파이프라인 실행 (1시간)

### 3.1 데모 프로젝트 복제
```bash
# 프로젝트 복제
git clone https://gitlab.local/kunkin/python-demo.git
cd python-demo

# 의존성 설치
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3.2 로컬 테스트
```bash
# 단위 테스트 실행
pytest tests/

# 애플리케이션 실행
uvicorn app.main:app --reload
```

### 3.3 변경사항 푸시
```bash
# 브랜치 생성
git checkout -b feature/my-first-change

# 변경사항 작성
echo "# My first change" >> README.md

# 커밋 및 푸시
git add README.md
git commit -m "docs: Add my first change"
git push origin feature/my-first-change
```

### 3.4 파이프라인 모니터링
1. GitLab에서 Merge Request 생성
2. Jenkins에서 파이프라인 진행 상황 확인
3. SonarQube에서 코드 분석 결과 확인
4. Harbor에서 생성된 이미지 확인

## 4. 주요 작업 가이드

### 4.1 코드 리뷰
1. GitLab Merge Request 확인:
- Changes 탭에서 코드 변경사항 검토
- Discussions 탭에서 리뷰어와 소통

2. 리뷰 의견 반영:
```bash
# 변경사항 수정
git add .
git commit -m "fix: Apply review comments"
git push origin feature/my-first-change
```

### 4.2 파이프라인 모니터링
1. Jenkins Blue Ocean 인터페이스:
- 실시간 진행 상황 확인
- 실패한 단계 로그 확인

2. 품질 게이트 확인:
- SonarQube 프로젝트 대시보드
- 코드 커버리지
- 코드 스멜

## 5. 자주 사용하는 기능

### 5.1 로컬 개발
1. 코드 수정:
```bash
# 브랜치 생성
git checkout -b feature/new-feature

# 의존성 추가 시
pip install new-package
pip freeze > requirements.txt
```

2. 테스트:
```bash
# 단위 테스트
pytest tests/

# 커버리지 리포트
pytest --cov=app tests/ --cov-report=html
```

### 5.2 배포 모니터링
1. 애플리케이션 로그:
```bash
# 실시간 로그 확인
tail -f /data/logs/python/application.log
```

2. 메트릭 확인:
- Grafana 대시보드
- Prometheus 쿼리 브라우저

## 6. 문서 및 리소스

### 6.1 주요 문서
- [시스템 아키텍처](../diagrams/cicd-pipeline.md)
- [트러블슈팅 가이드](./troubleshooting.md)
- [환경 구성 가이드](./environment-setup.md)

### 6.2 유용한 링크
- [GitLab 문서](https://gitlab.local/help)
- [Jenkins 플러그인](https://jenkins.local/pluginManager)
- [SonarQube 규칙](https://sonarqube.local/coding_rules)
- [Harbor API](https://harbor.local/devcenter-api)

## 7. 팁과 모범 사례

### 7.1 Git 작업
- 의미 있는 커밋 메시지 작성
- 작은 단위로 커밋
- 기능별로 브랜치 생성
- 정기적으로 main 브랜치 동기화

### 7.2 코드 품질
- 테스트 코드 필수 작성
- SonarQube 규칙 준수
- 코드 리뷰 적극 참여
- 문서화 습관화

## 8. 다음 단계

### 8.1 심화 학습
1. 파이프라인 사용자화:
- Jenkinsfile 수정
- 스테이지 추가/수정
- 알림 설정

2. 모니터링 대시보드:
- 사용자 정의 대시보드 생성
- 알림 규칙 설정
- 로그 분석

### 8.2 추천 학습 경로
1. 기본 (1-2주):
- Git 기본 명령어
- Docker 기본 개념
- Python 웹 개발

2. 중급 (2-4주):
- CI/CD 파이프라인 이해
- 테스트 자동화
- 코드 품질 관리

3. 고급 (4주+):
- 시스템 아키텍처 이해
- 보안 설정
- 성능 최적화