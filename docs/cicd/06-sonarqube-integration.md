# SonarQube 연동 가이드

## 1. 품질 게이트 설정

### 1.1 기본 품질 게이트 설정
1. SonarQube (https://sonarqube.local) 접속 후 kunkin 계정으로 로그인
2. Quality Gates > Create 클릭
3. 이름 입력: Python Demo Gate
4. 조건 추가:
   - Coverage: 80% 이상
   - Duplicated Lines: 3% 미만
   - Maintainability Rating: A등급
   - Reliability Rating: A등급
   - Security Rating: A등급
   - Security Hotspots Reviewed: 100%
   - Code Smells: 프로젝트당 10개 미만

### 1.2 프로젝트별 품질 게이트 적용
1. Projects > python-demo 선택
2. Project Settings > Quality Gate
3. Python Demo Gate 선택 후 Set as Default

## 2. 프로젝트 설정

### 2.1 프로젝트 생성
1. Projects > Create Project 클릭
2. Manually 선택
3. 프로젝트 정보 입력:
   - Project display name: Python Demo
   - Project key: python-demo
   - Main branch name: main
4. Analyze your project locally 선택

### 2.2 분석 토큰 생성
1. User > My Account > Security
2. Generate Tokens 클릭:
   - Name: python-demo-token
   - Type: Project Analysis Token
   - Project: python-demo
3. Generate 클릭
4. 생성된 토큰을 Jenkins Credentials에 등록 (이미 완료)

## 3. 분석 규칙 설정

### 3.1 Quality Profiles 설정
1. Quality Profiles > Python 선택
2. Sonar way 복사하여 새 프로파일 생성:
   - Name: Python Demo Profile
3. 규칙 활성화/비활성화:
   - Security: 모든 규칙 활성화
   - Bugs: Critical/Blocker 규칙 활성화
   - Code Smell: Major 이상 규칙 활성화
   - 중복 코드: 3줄 이상 감지

### 3.2 프로젝트에 프로파일 적용
1. Projects > python-demo 선택
2. Project Settings > Quality Profiles
3. Python Demo Profile 선택

## 4. Jenkins 연동 설정

### 4.1 Jenkins SonarQube Scanner 구성
1. Jenkins 관리 > Tools
2. SonarQube Scanner 설정:
   - Name: SonarScanner
   - Install automatically 체크
   - Version: Latest

### 4.2 분석 속성 설정
프로젝트 루트의 sonar-project.properties 파일 업데이트:
```properties
sonar.projectKey=python-demo
sonar.projectName=Python Demo Application
sonar.projectVersion=1.0

sonar.sources=app
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.version=3.12

sonar.sourceEncoding=UTF-8
sonar.language=python

sonar.python.pylint=/usr/local/bin/pylint
sonar.python.pylint_config=.pylintrc

sonar.coverage.exclusions=tests/**,setup.py
sonar.cpd.exclusions=tests/**

sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300
```

## 5. Issue 관리

### 5.1 Issue 분류 설정
1. Administration > Configuration > General Settings
2. Issues 섹션에서:
   - 새로운 이슈 할당 규칙 설정
   - 자동 닫기 규칙 설정
   - 중복 이슈 탐지 설정

### 5.2 Issue 처리 워크플로우
1. Issues 메뉴에서:
   - Severity 기준 정렬
   - Type 별 필터링
   - 담당자 지정
   - 해결 상태 추적

## 6. 보고서 및 대시보드

### 6.1 프로젝트 대시보드 설정
1. Projects > python-demo > Project Home
2. Configure widgets:
   - Reliability/Security Hotspots
   - Coverage
   - Code Smells
   - Duplications
   - Activity

### 6.2 리포트 자동화
1. Administration > Configuration > Webhooks
2. Create 클릭:
   - Name: Jenkins Notification
   - URL: https://jenkins.local/sonarqube-webhook/
   - Secret: [Webhook Secret]

## 7. 분석 실행 및 확인

### 7.1 수동 분석 실행
로컬 환경에서 테스트:
```bash
# SonarScanner 설치
pip install pylint

# 코드 분석 실행
sonar-scanner \
  -Dsonar.projectKey=python-demo \
  -Dsonar.sources=app \
  -Dsonar.host.url=https://sonarqube.local \
  -Dsonar.login=[YOUR-SONAR-TOKEN]
```

### 7.2 분석 결과 확인
1. Projects > python-demo
2. 각 섹션 확인:
   - 코드 커버리지
   - 코드 중복
   - 버그/취약점
   - 코드 스멜
3. 이슈 해결 및 재분석

## 다음 단계
SonarQube 연동이 완료되면, [Harbor 레지스트리](./07-harbor-registry.md) 가이드로 진행하세요.