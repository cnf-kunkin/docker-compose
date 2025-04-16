# 사용자 계정 설정 가이드

## 1. GitLab 계정 설정

### 1.1 초기 접속
1. 웹 브라우저에서 https://gitlab.local 접속
2. 초기 root 비밀번호 확인:
```bash
sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```
3. root 계정으로 로그인

### 1.2 일반 사용자 계정 생성
1. 좌측 메뉴 Admin Area (렌치 아이콘) 클릭
2. 좌측 Users 메뉴 > New user 클릭
3. 사용자 정보 입력:
   - Name: Kunkin
   - Username: kunkin
   - Email: kunkin@local.domain
   - 'Create user' 클릭

### 1.3 사용자 권한 설정
1. Admin Area > Users에서 생성한 사용자 선택
2. Edit 버튼 클릭
3. Access level 설정:
   - Can create group: 활성화
   - Can create project: 활성화
   - Admin 체크박스: 비활성화
4. Permissions 탭에서:
   - Maintainer 권한 부여

## 2. Jenkins 계정 설정

### 2.1 초기 접속
1. https://jenkins.local 접속
2. 초기 관리자 비밀번호 확인:
```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
3. 추천 플러그인 설치 선택
4. 관리자 계정 생성 (admin)

### 2.2 일반 사용자 계정 생성
1. Jenkins 관리 > Security > Manage Users 이동
2. Create User 클릭
3. 사용자 정보 입력:
   - Username: kunkin
   - Password: [안전한 비밀번호]
   - Full name: Kunkin
   - E-mail: kunkin@local.domain

### 2.3 권한 설정
1. Jenkins 관리 > Security > Configure Global Security 이동
2. Authorization 섹션에서:
    - Matrix-based security 선택: 사용자별 세부 권한 설정 가능
    - Add user 'kunkin' 추가
    - Overall Read: Jenkins 시스템 정보 조회 권한
    - Job 권한:
      * Build: 작업 실행 권한
      * Read: 작업 조회 권한
      * Configure: 작업 설정 변경 권한
    - View 권한:
      * Read: 뷰 조회 권한
      * Configure: 뷰 설정 변경 권한

## 3. Harbor 계정 설정

### 3.1 초기 접속
1. https://harbor.local 접속
2. 기본 계정으로 로그인:
   - Username: admin
   - Password: Harbor12345

### 3.2 일반 사용자 생성
1. Administration > Users 메뉴 이동
2. NEW USER 클릭
3. 사용자 정보 입력:
   - Username: kunkin
   - Email: kunkin@local.domain
   - Full Name: Kunkin
   - Password: [안전한 비밀번호]

### 3.3 프로젝트 및 권한 설정
1. Projects > NEW PROJECT
2. 프로젝트 생성:
   - Project Name: python-demo
   - Access Level: Private
3. 프로젝트 멤버 추가:
   - Members > ADD USER
   - Name: kunkin
   - Role: Project Admin

## 4. SonarQube 계정 설정

### 4.1 초기 접속
1. https://sonarqube.local 접속
2. 기본 계정으로 로그인:
   - Username: admin
   - Password: admin
3. 새 비밀번호로 변경

### 4.2 일반 사용자 생성
1. Administration > Security > Users
2. Create User 클릭
3. 사용자 정보 입력:
   - Login: kunkin
   - Name: Kunkin
   - Email: kunkin@local.domain
   - Password: [안전한 비밀번호]

### 4.3 권한 설정
1. Administration > Security > Global Permissions
2. kunkin 사용자에게 권한 부여:
   - Execute Analysis
   - Create Projects
   - Create Applications
   - Create Portfolios

## 5. Grafana 계정 설정

### 5.1 초기 접속
1. https://grafana.local 접속
2. 기본 계정으로 로그인:
   - Username: admin
   - Password: admin
3. 새 비밀번호로 변경

### 5.2 일반 사용자 생성
1. Configuration > Users 메뉴 이동
2. Invite 클릭
3. 사용자 정보 입력:
   - Email: kunkin@local.domain
   - Name: Kunkin
   - Username: kunkin
4. Add User 클릭

### 5.3 권한 설정
1. Configuration > Users에서 kunkin 선택
2. 권한 설정:
   - Organization role: Editor
   - Add role: Viewer

## 6. 계정 정보 정리

### 6.1 서비스별 로그인 정보
| 서비스 | URL | 계정 | 비고 |
|--------|-----|------|------|
| GitLab | https://gitlab.local | kunkin | maintainer 권한 |
| Jenkins | https://jenkins.local | kunkin | 작업 관리 권한 |
| Harbor | https://harbor.local | kunkin | python-demo 프로젝트 관리자 |
| SonarQube | https://sonarqube.local | kunkin | 분석 및 프로젝트 생성 권한 |
| Grafana | https://grafana.local | kunkin | Editor 권한 |

### 6.2 비밀번호 관리
- 모든 서비스의 비밀번호는 안전하게 관리
- 정기적인 비밀번호 변경 권장
- 2단계 인증 설정 권장 (지원하는 서비스의 경우)

## 다음 단계
모든 서비스의 계정 설정이 완료되면, [Python 데모 애플리케이션](./03-demo-application.md) 가이드로 진행하세요.