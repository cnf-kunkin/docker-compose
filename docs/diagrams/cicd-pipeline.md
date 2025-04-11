# CI/CD 파이프라인 흐름도

## 1. 전체 프로세스
```mermaid
flowchart TD
    DEV([개발자]):::developer
    GIT([GitLab]):::gitlab
    PIPE([Pipeline])
    
    DEV -->|1: Git Push| GIT
    GIT -->|2: Trigger| PIPE

    subgraph CI[CI Pipeline]
        direction TB
        TEST[Unit Tests]
        SONAR[SonarQube]
        BUILD[Docker Build]
        HARBOR[(Harbor Registry)]:::harbor
        TRIVY[Trivy Security]
        
        PIPE -->|3: Test| TEST
        TEST -->|4: Analysis| SONAR
        SONAR -->|5: Quality Gate| BUILD
        BUILD -->|6: Push| HARBOR
        HARBOR -->|7: Scan| TRIVY
    end

    subgraph CD[CD Pipeline]
        direction TB
        APP[Application VM]:::app
        COMPOSE[Docker Compose]
        SERVICES[Update Services]
        HEALTH[Health Check]
        
        TRIVY -->|8: Deploy| APP
        APP -->|9: Pull| HARBOR
        APP -->|10: Deploy| COMPOSE
        COMPOSE -->|11: Start| SERVICES
        SERVICES -->|12: Check| HEALTH
    end

    subgraph MON[Monitoring]
        direction TB
        PROM[(Prometheus)]
        GRAF[Grafana]
        ALERT[Alert Manager]
        
        HEALTH -->|13: Metrics| PROM
        PROM -->|14: Dashboard| GRAF
        GRAF -->|15: Alert| ALERT
    end

```

## 2. 단계별 세부 설명

### CI (Continuous Integration)
1. **코드 커밋**
   - 개발자가 GitLab에 코드 Push
   - `.gitlab-ci.yml` 파일 감지

2. **테스트 실행**
   - 단위 테스트
   - 통합 테스트
   - 커버리지 검사

3. **코드 품질 검사**
   - SonarQube 정적 분석
   - 코드 품질 메트릭 수집
   - Quality Gate 검사

4. **컨테이너 빌드**
   - Dockerfile 기반 이미지 생성
   - 멀티스테이지 빌드 최적화
   - 레이어 캐시 활용

5. **보안 검사**
   - Trivy 취약점 스캔
   - 컨테이너 이미지 검증
   - CVE 데이터베이스 확인

### CD (Continuous Deployment)
1. **배포 준비**
   - Harbor에서 이미지 Pull
   - 환경변수 구성
   - 볼륨 마운트 준비

2. **서비스 배포**
   - Docker Compose 실행
   - 무중단 배포 (Blue/Green)
   - 상태 확인 및 롤백 준비

3. **모니터링**
   - 메트릭 수집 (Prometheus)
   - 대시보드 표시 (Grafana)
   - 알림 설정 (Alert Manager)

## 3. 주요 통신 흐름
```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as GitLab
    participant CI as GitLab CI
    participant SQ as SonarQube
    participant HR as Harbor
    participant App as Application VM

    Dev->>Git: Push Code
    Git->>CI: Trigger Pipeline
    CI->>SQ: Code Analysis
    SQ-->>CI: Quality Report
    CI->>HR: Push Image
    HR-->>CI: Image Pushed
    CI->>App: Deploy Command
    App->>HR: Pull Image
    HR-->>App: Image Pulled
    App->>App: Docker Compose Up
    App-->>CI: Deploy Success
    Note over CI,App: Health Check Starts
    App-->>CI: Health Status
```
