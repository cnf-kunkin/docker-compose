# GitLab 설정 가이드

## 1. 저장소 생성

### 1.1 프로젝트 생성
1. GitLab (https://gitlab.local) 접속 후 kunkin 계정으로 로그인
2. New project > Create blank project 클릭
3. 프로젝트 정보 입력:
   - Project name: python-demo
   - Project slug: python-demo
   - Visibility Level: Private
   - Initialize repository with a README: 체크
4. Create project 클릭

### 1.2 SSH 키 설정

```bash
# SSH 키를 생성할 VM:
- GitLab Repository에 접근할 VM에서 생성 (예: 개발자 PC 또는 CI/CD 서버)
# Windows PowerShell에서 실행:
cd $env:USERPROFILE
mkdir .ssh
# SSH 키 생성
ssh-keygen -t ed25519 -C "cnf.kunkin@gmail.com"

# 공개키 출력
cat ~/.ssh/id_ed25519.pub
```

1. GitLab UI에서 Settings > SSH Keys 이동
2. 생성된 공개키 추가
3. 연결 테스트:
```bash
ssh -T git@gitlab.local:2222
```

## 2. 코드 푸시

### 2.1 로컬 저장소 설정
```bash
# 저장소 클론
cd D:\cicd\
git clone ssh://git@gitlab.local:2222/kunkin/python-demo.git
cd python-demo

# 이전에 작성한 Python 애플리케이션 파일 복사
cp -r D:\cicd\docker-compose\vm-application\services\python-demo/* .

# 변경사항 커밋
git add .
git commit -m "Initial commit: Add Python demo application"
git push origin main
```

## 3. CI/CD 파이프라인 설정

### 3.1 GitLab CI 변수 설정
1. Settings > CI/CD > Variables 이동
2. 필요한 변수 추가:

| 변수명 | 값 | 보호 | 마스킹 |
|--------|-----|------|--------|
| HARBOR_USER | kunkin | No | No |
| HARBOR_PASSWORD | [Harbor 비밀번호] | No | Yes |
| SONAR_TOKEN | [SonarQube 토큰] | No | Yes |
| SSH_PRIVATE_KEY | [배포 서버 SSH 키] | No | Yes |
| SSH_KNOWN_HOSTS | [known_hosts 내용] | No | No |


값 조회 방법:
- SONAR_TOKEN:
  ```bash
  # SonarQube UI에서 User > My Account > Security > Generate Tokens
  curl -X POST -u admin:admin "https://sonarqube.local/api/user_tokens/generate" \
    -d "name=gitlab-token"
  ```

  - Host 주소 & SSH 키 생성:
    ```bash
    # 배포 서버 정보:
    # hostname: vm-app
    # ip: 172.16.10.40
    
    # 배포 서버에서 SSH 키 생성
    ssh-keygen -t ed25519 -C "devops@app-server"
    # default 위치(/home/devops/.ssh/id_ed25519)에 저장
    
    # 생성된 공개키를 배포 서버의 authorized_keys에 추가
    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    ```
- SSH_PRIVATE_KEY:
  ```bash
  # 배포 서버의 비공개키 내용 조회
  cat ~/.ssh/id_ed25519
  ```

- SSH_KNOWN_HOSTS:
  ```bash
  # 배포 서버의 known_hosts 생성 및 조회
  ssh-keyscan -p 22 172.16.10.40 > ~/.ssh/known_hosts
  cat ~/.ssh/known_hosts
  ```


  ### 3.2 GitLab Runner 작동 확인

  1. GitLab Runner 상태 확인:
  ```bash
  # Runner 상태 확인
  docker-compose ps gitlab-runner
  docker-compose logs gitlab-runner

  # Runner 등록 확인
  docker exec -it gitlab-runner gitlab-runner list
  ```

  2. 테스트용 `.gitlab-ci.yml` 작성:
  ```yaml
  test_job:
    script:
      - echo "Runner is working!"
  ```

  3. 파이프라인 실행 확인:
  ```bash
  # 테스트 커밋 및 푸시
  git add .gitlab-ci.yml
  git commit -m "test: Add test pipeline"
  git push origin main

  # GitLab UI에서 CI/CD > Pipelines에서 실행 상태 확인
  ```

  4. 문제 해결:
  ```bash
  # Runner 재시작
  docker-compose restart gitlab-runner

  # Runner 로그 확인
  docker-compose logs -f gitlab-runner
  ```

### 3.2 .gitlab-ci.yml 작성
```yaml
variables:
  DOCKER_REGISTRY: harbor.local
  DOCKER_IMAGE: $DOCKER_REGISTRY/python-demo/$CI_PROJECT_NAME
  DOCKER_TAG: $CI_COMMIT_SHA
  SSH_USER: devops
  APP_SERVER: 172.16.10.40

stages:
  - test
  - quality
  - build
  - security
  - deploy

test:
  stage: test
  image: python:3.12-slim
  before_script:
    - pip install -r requirements.txt
  script:
    - pytest tests/
    - pytest --cov=app tests/ --cov-report=xml
  coverage: '/TOTAL.+ ([0-9]{1,3}%)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

code_quality:
  stage: quality
  image: 
    name: sonarsource/sonar-scanner-cli:latest
    entrypoint: [""]
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    GIT_DEPTH: "0"
  script:
    - sonar-scanner
      -Dsonar.projectKey=python-demo
      -Dsonar.sources=app
      -Dsonar.host.url=https://sonarqube.local
      -Dsonar.login=$SONAR_TOKEN
      -Dsonar.python.coverage.reportPaths=coverage.xml
  dependencies:
    - test
  allow_failure: true
  only:
    - main

build:
  stage: build
  image: docker:stable
  services:
    - docker:dind
  before_script:
    - docker login $DOCKER_REGISTRY -u $HARBOR_USER -p $HARBOR_PASSWORD
  script:
    - docker build -t $DOCKER_IMAGE:$DOCKER_TAG .
    - docker push $DOCKER_IMAGE:$DOCKER_TAG
  only:
    - main

security_scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy image $DOCKER_IMAGE:$DOCKER_TAG
  only:
    - main

deploy:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - echo "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
  script:
    - ssh $SSH_USER@$APP_SERVER "
        cd /data/python &&
        docker login ${DOCKER_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PASSWORD} &&
        docker pull ${DOCKER_IMAGE}:${DOCKER_TAG} &&
        docker-compose down &&
        echo \"DOCKER_IMAGE=${DOCKER_IMAGE}\" > .env &&
        echo \"DOCKER_TAG=${DOCKER_TAG}\" >> .env &&
        docker-compose up -d &&
        docker image prune -f"
  environment:
    name: production
    url: https://python-demo.local
  only:
    - main
```

### 3.3 GitLab Runner 설정
1. GitLab UI에서 Settings > CI/CD > Runners 이동
2. Specific runners 섹션에서 등록 토큰 확인
3. GitLab Runner VM에서:
```bash
# Runner 등록
sudo gitlab-runner register \
  --url "https://gitlab.local/" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --description "docker-runner" \
  --executor "docker" \
  --docker-image "docker:stable" \
  --docker-privileged
```

## 4. 보안 설정

### 4.1 Protected Branches
1. Settings > Repository > Protected Branches 이동
2. main 브랜치 보호 설정:
   - Allowed to push: Maintainers
   - Allowed to merge: Developers + Maintainers
   - Code owner approval: 필요시 활성화

### 4.2 Container Registry 설정
1. Packages & Registries > Container Registry 이동
2. Expiration policy 설정:
   - 태그 없는 이미지: 14일 후 삭제
   - 오래된 버전: 30일 이상된 이미지 삭제

## 5. 웹훅 설정

### 5.1 Jenkins 웹훅
1. Settings > Webhooks 이동
2. 새 웹훅 추가:
   - URL: https://jenkins.local/gitlab-webhook/post
   - Secret Token: [Jenkins에서 생성한 토큰]
   - Trigger: Push events, Pipeline events
   - SSL verification: 활성화

### 5.2 모니터링 웹훅
1. 추가 웹훅 설정:
   - URL: https://grafana.local/api/webhooks/gitlab
   - Trigger: Pipeline events
   - SSL verification: 활성화

## 다음 단계
GitLab 설정이 완료되면, [Jenkins 파이프라인](./05-jenkins-pipeline.md) 가이드로 진행하세요.