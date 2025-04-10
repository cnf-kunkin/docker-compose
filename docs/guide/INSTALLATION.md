# MSA 개발 환경 설치 가이드

## 1. 사전 준비사항
### 1.1 필수 도구 설치
- VMware Workstation Pro 17 이상
- mkcert (로컬 인증서)
- OpenSSL

### 1.2 호스트 시스템 요구사항
| 항목 | 최소 사양 | 권장 사양 |
|------|-----------|-----------|
| CPU | 16코어 | 20코어 |
| 메모리 | 32GB | 64GB |
| 디스크 | 500GB | 1TB |
| OS | Windows 10/11 Pro | Windows 10/11 Pro |

## 2. VM 구성 정보
| VM 이름 | IP 주소 | CPU | 메모리 | 디스크 |
|---------|---------|-----|--------|---------|
| CI/CD | 172.16.10.10 | 6 | 12GB | 100GB |
| Harbor | 172.16.10.11 | 4 | 8GB | 80GB |
| Monitoring | 172.16.10.20 | 2 | 4GB | 60GB |
| Security | 172.16.10.30 | 2 | 4GB | 60GB |
| Application | 172.16.10.40 | 4 | 8GB | 80GB |

## 3. 설치 순서

### 3.1 기본 환경 구성
1. VM 생성 및 Ubuntu 설치
2. 네트워크 구성
3. Docker 설치
4. SSL 인증서 생성

### 3.2 서비스별 설치
1. CI/CD 환경 (GitLab, Jenkins)
2. Harbor 레지스트리
3. 모니터링 도구 (Grafana, Prometheus)
4. 보안 도구 (SonarQube, OWASP ZAP)
5. 애플리케이션 서비스

## 4. SSL 인증서 설정
```bash
# 인증서 생성
./generate-certs.sh

# 인증서 확인
ls -l /data/certs/combined/
```

## 5. 도메인 설정
| 서비스 | 도메인 |
|--------|--------|
| GitLab | https://gitlab.local |
| Jenkins | https://jenkins.local |
| Harbor | https://harbor.local |
| Grafana | https://grafana.local |
| SonarQube | https://sonarqube.local |
| Next.js | https://next-demo.local |
| Nest.js | https://nest-demo.local |

## 6. 설치 검증
각 서비스 설치 후 다음 URL에 접속하여 동작을 확인합니다:

1. CI/CD 서비스:
   - https://gitlab.local
   - https://jenkins.local
   
2. Harbor 레지스트리:
   - https://harbor.local
   
3. 모니터링:
   - https://grafana.local
   - https://prometheus.local
   
4. 보안:
   - https://sonarqube.local
   - https://security.local
   
5. 애플리케이션:
   - https://next-demo.local
   - https://nest-demo.local
   - https://python-demo.local
```

배포된 모든 서비스는 HTTPS로만 접근 가능하며, 자체 서명된 인증서를 사용합니다.
```

## 7. 문제 해결
일반적인 문제 해결 방법:

1. 인증서 오류
   ```bash
   # 인증서 재생성
   ./generate-certs.sh
   
   # nginx 설정 리로드
   sudo nginx -t
   sudo systemctl reload nginx
   ```

2. 네트워크 연결 문제
   ```bash
   # DNS 확인
   ping gitlab.local
   
   # 포트 확인
   netstat -tulpn | grep LISTEN
   ```

3. 도커 컨테이너 문제
   ```bash
   # 컨테이너 상태 확인
   docker ps -a
   
   # 로그 확인
   docker logs <container_id>
   ```
