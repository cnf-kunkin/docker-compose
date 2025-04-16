# Jenkins 파이프라인 설정 가이드

## 1. Jenkins 플러그인 설정

### 1.1 필수 플러그인 설치
Jenkins 관리 > Plugins > Available plugins에서 설치:
- GitLab
- Docker Pipeline
- SonarQube Scanner
- Blue Ocean
- Pipeline Utility Steps
- HTTP Request
- SSH Pipeline Steps

### 1.2 플러그인 구성
1. Jenkins 관리 > System에서:
   - GitLab Connection 설정:
     - Connection name: gitlab-local
     - Gitlab host URL: https://gitlab.local
     - Credentials: GitLab API token 추가
   - SonarQube Server 설정:
     - Name: SonarQube
     - Server URL: https://sonarqube.local
     - Server authentication token: 추가

## 2. Credentials 설정

### 2.1 필요한 자격증명 추가
Jenkins 관리 > Credentials > System > Global credentials에서:

1. GitLab API Token:
   - Kind: GitLab API token
   - ID: gitlab-api-token
   - Token: [GitLab Access Token]

2. Harbor 자격증명:
   - Kind: Username with password
   - ID: harbor-credentials
   - Username: kunkin
   - Password: [Harbor Password]

3. SSH 키:
   - Kind: SSH Username with private key
   - ID: deploy-key
   - Username: devops
   - Private Key: [배포 서버 SSH 키]

4. SonarQube Token:
   - Kind: Secret text
   - ID: sonar-token
   - Secret: [SonarQube Token]

## 3. 파이프라인 작성

### 3.1 파이프라인 작업 생성
1. New Item 클릭
2. 이름 입력: python-demo-pipeline
3. Pipeline 선택
4. OK 클릭

### 3.2 파이프라인 구성
Pipeline 섹션에서:

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'harbor.local'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/python-demo/python-demo"
        DOCKER_TAG = "${GIT_COMMIT}"
        APP_SERVER = '172.16.10.40'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://gitlab.local/kunkin/python-demo.git',
                        credentialsId: 'gitlab-api-token'
                    ]]
                )
            }
        }
        
        stage('Test') {
            agent {
                docker {
                    image 'python:3.12-slim'
                    args '-u root'
                }
            }
            steps {
                sh '''
                    pip install -r requirements.txt
                    pytest tests/
                    pytest --cov=app tests/ --cov-report=xml
                '''
                stash includes: 'coverage.xml', name: 'coverage-report'
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                unstash 'coverage-report'
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=python-demo \
                        -Dsonar.sources=app \
                        -Dsonar.python.coverage.reportPaths=coverage.xml
                    '''
                }
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Build & Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASSWORD'
                )]) {
                    sh '''
                        docker login ${DOCKER_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PASSWORD}
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                    '''
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                sh """
                    docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    aquasec/trivy:latest image \
                    ${DOCKER_IMAGE}:${DOCKER_TAG}
                """
            }
        }
        
        stage('Deploy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'deploy-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    usernamePassword(
                        credentialsId: 'harbor-credentials',
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASSWORD'
                    )
                ]) {
                    sh '''
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$APP_SERVER "
                            cd /data/python && \
                            docker login ${DOCKER_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PASSWORD} && \
                            docker pull ${DOCKER_IMAGE}:${DOCKER_TAG} && \
                            docker-compose down && \
                            echo \\"DOCKER_IMAGE=${DOCKER_IMAGE}\\" > .env && \
                            echo \\"DOCKER_TAG=${DOCKER_TAG}\\" >> .env && \
                            docker-compose up -d && \
                            docker image prune -f"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
            updateGitlabCommitStatus state: 'success'
        }
        failure {
            echo 'Pipeline failed!'
            updateGitlabCommitStatus state: 'failed'
        }
    }
}
```

### 3.3 웹훅 설정
1. 파이프라인 설정에서 Build Triggers 섹션:
   - Build when a change is pushed to GitLab 체크
   - 고급:
     - Enabled GitLab triggers: Push Events
     - Generate 클릭하여 Secret token 생성
     - 생성된 토큰을 GitLab 웹훅 설정에 추가

## 4. 파이프라인 테스트

### 4.1 수동 실행 테스트
1. 파이프라인 페이지에서 Build Now 클릭
2. Blue Ocean에서 진행 상황 모니터링
3. 각 스테이지 로그 확인

### 4.2 자동 실행 테스트
1. 로컬에서 코드 수정:
```bash
git checkout -b feature/test-pipeline
echo "# Test pipeline" >> README.md
git add README.md
git commit -m "test: Add test comment for pipeline"
git push origin feature/test-pipeline
```

2. GitLab에서 Merge Request 생성
3. Jenkins에서 파이프라인 실행 확인

## 5. 모니터링 설정

### 5.1 Jenkins 대시보드 설정
1. Blue Ocean에서:
   - 파이프라인 성공/실패 통계
   - 스테이지 실행 시간
   - 테스트 커버리지 트렌드

### 5.2 알림 설정
1. Jenkins 관리 > System에서:
   - Email 알림:
     - SMTP 서버 설정
     - 알림 수신자 설정
   - Slack/Teams 알림 (선택사항):
     - Webhook URL 설정
     - 채널 설정

## 다음 단계
Jenkins 파이프라인 설정이 완료되면, [SonarQube 연동](./06-sonarqube-integration.md) 가이드로 진행하세요.