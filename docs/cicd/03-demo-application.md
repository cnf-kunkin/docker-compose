# Python 데모 애플리케이션 개발 가이드

## 1. 프로젝트 구조

### 1.1 기본 디렉토리 구조
```plaintext
python-demo/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   └── api/
│       ├── __init__.py
│       └── routes.py
├── tests/
│   ├── __init__.py
│   └── test_api.py
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── README.md
└── sonar-project.properties
```

## 2. 애플리케이션 코드 작성

### 2.1 main.py
```python
from fastapi import FastAPI
from app.api.routes import router
import uvicorn
from prometheus_client import make_asgi_app
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="Python Demo API")

# Prometheus 메트릭 설정
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
Instrumentator().instrument(app).expose(app)

# API 라우터 등록
app.include_router(router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### 2.2 api/routes.py
```python
from fastapi import APIRouter, HTTPException
from typing import List, Dict

router = APIRouter()

# 간단한 메모리 저장소
items: List[Dict] = []

@router.get("/items")
async def get_items():
    return {"items": items}

@router.post("/items")
async def create_item(item: Dict):
    items.append(item)
    return {"status": "success", "item": item}

@router.get("/items/{item_id}")
async def get_item(item_id: int):
    if item_id < 0 or item_id >= len(items):
        raise HTTPException(status_code=404, detail="Item not found")
    return {"item": items[item_id]}
```

### 2.3 config.py
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Python Demo API"
    DEBUG: bool = False
    VERSION: str = "0.1.0"
    
    # Prometheus 설정
    METRICS_PORT: int = 8000
    METRICS_PATH: str = "/metrics"

settings = Settings()
```

### 2.4 tests/test_api.py
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_create_item():
    item = {"name": "test", "value": 123}
    response = client.post("/api/v1/items", json=item)
    assert response.status_code == 200
    assert response.json()["status"] == "success"

def test_get_items():
    response = client.get("/api/v1/items")
    assert response.status_code == 200
    assert "items" in response.json()
```

## 3. 도커 설정

### 3.1 Dockerfile
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY . .

# 포트 설정
EXPOSE 8000

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 실행 명령
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 3.2 requirements.txt
```text
fastapi>=0.103.0
uvicorn>=0.23.0
pytest>=7.4.0
httpx>=0.24.1
prometheus-client>=0.17.0
prometheus-fastapi-instrumentator>=6.0.0
pydantic>=2.3.0
pydantic-settings>=2.0.3
```

### 3.3 docker-compose.yml
```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    environment:
      - DEBUG=false
    networks:
      - app_network

networks:
  app_network:
    external: true
```

### 3.4 sonar-project.properties
```properties
sonar.projectKey=python-demo
sonar.projectName=Python Demo Application
sonar.sources=app
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.version=3.12
```

## 4. 로컬 테스트

### 4.1 환경 설정
```bash
# 가상환경 생성 및 활성화

### Python venv 사용
```bash
# 가상환경 생성
python -m venv venv
# 활성화
source venv/bin/activate  # Windows: venv\Scripts\activate
# 비활성화
deactivate
```

### Anaconda 사용
```bash
### PowerShell에서 Anaconda 활성화
```powershell
# PowerShell 실행 권한 설정 (관리자 권한으로 실행)
Set-ExecutionPolicy RemoteSigned

### Git Bash에서 Anaconda 활성화
```bash
# Git Bash에서 Anaconda 사용을 위한 설정
notepad ~/.bashrc

# Anaconda 설정
export CONDA_ROOT="/c/ProgramData/anaconda3"
. "$CONDA_ROOT/etc/profile.d/conda.sh"

# Conda 초기화
if [ -f "$CONDA_ROOT/etc/profile.d/conda.sh" ]; then
    . "$CONDA_ROOT/etc/profile.d/conda.sh"
else
    export PATH="$CONDA_ROOT/bin:$PATH"
fi

source ~/.bashrc

# Git Bash 재시작 후 확인
conda --version
```


# Anaconda PowerShell 초기화
conda init powershell

# PowerShell 재시작 후 아래 명령어 실행

# 가상환경 생성
conda create -n pythondemo python=3.12
# 활성화
conda activate pythondemo
# 비활성화
conda deactivate
# 가상환경 리스트 조회
conda env list
```


# 의존성 설치
```
cd D:\cicd\docker-compose\vm-application\services\python-demo\

conda install -c conda-forge fastapi uvicorn pytest httpx prometheus-client pydantic -y
pip install pytest-cov

pip install -r requirements.txt
```

### 4.2 테스트 실행
```bash
# 단위 테스트 실행
pytest tests/

# 커버리지 리포트 생성
pytest --cov=app tests/ --cov-report=xml
```

### 4.3 로컬 실행
```bash
# 애플리케이션 실행
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# API 테스트
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/v1/items -H "Content-Type: application/json" -d '{"name":"test","value":123}'
curl http://localhost:8000/api/v1/items
```

## 5. API 문서

### 5.1 Swagger UI
- URL: http://localhost:8000/docs
- 자동 생성된 API 문서 제공
- 모든 엔드포인트 직접 테스트 가능

### 5.2 ReDoc
- URL: http://localhost:8000/redoc
- 보다 자세한 API 문서 제공

## 6. 모니터링 엔드포인트

### 6.1 메트릭
- URL: http://localhost:8000/metrics
- Prometheus 형식의 메트릭 제공:
  - 요청 수
  - 응답 시간
  - HTTP 상태 코드
  - 시스템 메트릭

### 6.2 헬스체크
- URL: http://localhost:8000/health
- 애플리케이션 상태 확인

## 다음 단계
애플리케이션 개발이 완료되면, [GitLab 설정](./04-gitlab-setup.md) 가이드로 진행하세요.