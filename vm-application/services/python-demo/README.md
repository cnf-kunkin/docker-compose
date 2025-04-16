# Python Demo Application

FastAPI 기반의 데모 애플리케이션입니다.

## 기능
- RESTful API 엔드포인트
- 헬스 체크
- Prometheus 메트릭
- 단위 테스트

## 요구사항
- Python 3.12+
- Docker
- Docker Compose

## 로컬 개발 환경 설정

### 1. 가상환경 설정
```bash
# 가상환경 생성
python -m venv venv

# 가상환경 활성화
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt
```

### 2. 애플리케이션 실행
```bash
# 개발 모드로 실행
uvicorn app.main:app --reload

# 프로덕션 모드로 실행
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 3. 테스트 실행
```bash
# 모든 테스트 실행
pytest

# 커버리지 리포트 생성
pytest --cov=app tests/ --cov-report=xml
```

## Docker 환경 실행

### 1. 이미지 빌드 및 실행
```bash
# 이미지 빌드
docker-compose build

# 컨테이너 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f
```

### 2. 컨테이너 중지
```bash
docker-compose down
```

## API 엔드포인트

### 헬스 체크
- GET /health
  - 애플리케이션 상태 확인

### 아이템 관리
- GET /api/v1/items
  - 모든 아이템 조회
- POST /api/v1/items
  - 새 아이템 생성
- GET /api/v1/items/{item_id}
  - 특정 아이템 조회

### 모니터링
- GET /metrics
  - Prometheus 메트릭 조회

## 품질 관리
- SonarQube를 통한 정적 분석
- 테스트 커버리지 리포트 생성
- 도커 이미지 취약점 스캔