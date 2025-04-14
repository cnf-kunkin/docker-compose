# WSL 설치 및 설정 가이드

## 1. 기존 WSL 제거

```powershell
# 관리자 권한으로 PowerShell 실행 후:

# 실행 중인 모든 WSL 인스턴스 종료
wsl --shutdown

# 모든 WSL 배포판 나열
wsl --list --verbose

# 기존 Ubuntu 배포판 제거 (있는 경우)
wsl --unregister Ubuntu

# WSL 완전 초기화 (선택사항)
wsl --unregister * 
```

## 2. WSL 설치 및 활성화

```powershell

# WSL 재시작
wsl --shutdown
wsl


# WSL 설치
wsl --install

# Windows 기능 활성화
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# 시스템 재시작 필요
```

## 3. Ubuntu 24.04 설치

```powershell
# Ubuntu 24.04 다운로드 및 설치
wsl --install -d Ubuntu-24.04

# WSL 버전 2로 설정
wsl --set-version Ubuntu-24.04 2

# 기본 배포판으로 설정
wsl --set-default Ubuntu-24.04


```

## 4. NVIDIA Container Toolkit 설치

Docker 컨테이너에서 CUDA를 사용하기 위해서는 WSL에 CUDA를 직접 설치할 필요가 없습니다. 대신, 다음 요구사항들이 필요합니다:

1. Windows 호스트에 NVIDIA GPU 드라이버 설치 (이미 설치되어 있어야 함)
2. WSL2 사용 (GPU 패스스루 지원)
3. WSL 내부에 NVIDIA Container Toolkit 설치

### 4.1 Windows NVIDIA 드라이버 확인
```powershell
# Windows에서 그래픽 카드 정보 확인
nvidia-smi
```

### 4.2 NVIDIA Container Toolkit 설치
```bash
# Ubuntu 터미널에서:

# 기존 nvidia-container-toolkit 저장소 파일 제거 (있는 경우)
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list

# NVIDIA 패키지 저장소 및 GPG 키 설정
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Ubuntu 24.04용 저장소 설정
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 패키지 목록 업데이트
sudo apt-get update

# NVIDIA Container Toolkit 설치
sudo apt-get install -y nvidia-container-toolkit

# Docker 런타임 설정
sudo nvidia-ctk runtime configure --runtime=docker


## D:\cicd\docker-compose\vm-ubuntu-installation-guide.md OS 기본 설정과 docker compose 설치 까지 진행 후 계속 




# Docker 서비스 재시작
sudo service docker restart

# 설치 확인 (아래 명령어가 GPU 정보를 표시하면 성공)
sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### 4.3 Container Toolkit 설정 확인
```bash
# Docker daemon이 NVIDIA Runtime을 인식하는지 확인
docker info | grep -i nvidia
```

## 7. 설치 확인 및 테스트

### 7.1 시스템 상태 확인
```bash
# WSL 버전 확인
wsl --version

# Ubuntu 버전 확인
cat /etc/os-release

# Docker 확인
docker --version
docker compose version

# NVIDIA-Docker 테스트
docker run --gpus all nvidia/cuda:12.0-base nvidia-smi
```

## 8. 문제 해결

### 8.1 일반적인 문제
- WSL이 시작되지 않는 경우: `wsl --shutdown` 후 재시작
- Docker 권한 문제: 로그아웃 후 재로그인하여 docker 그룹 적용
- CUDA 오류: NVIDIA 드라이버 재설치 또는 업데이트

### 8.2 성능 최적화
```bash
# WSL 메모리 제한 설정 (선택사항)
# %UserProfile%\.wslconfig 파일에 추가:
[wsl2]
memory=8GB
processors=4
swap=2GB
```

## 9. 참고 사항
- WSL2는 가상화를 사용하므로 BIOS에서 가상화 기능이 활성화되어 있어야 합니다.
- NVIDIA 드라이버는 정기적으로 업데이트하는 것이 좋습니다.
- Docker 이미지와 컨테이너는 디스크 공간을 많이 사용할 수 있으므로 주기적으로 정리가 필요합니다.

## 10. vLLM 서비스 설정 가이드

### 10.1 프로젝트 구조 생성
```bash
mkdir -p ~/vllm-service
cd ~/vllm-service
```

### 10.2 Docker Compose 설정

#### docker-compose.yml 생성
```bash
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  ai-service:
    build: 
      context: . 
      dockerfile: Dockerfile
    runtime: nvidia
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - ${HUGGING_FACE_CACHE:-~/.cache/huggingface}:/root/.cache/huggingface
    environment:
      - MODEL_NAME=${MODEL_NAME:-TheBloke/Llama-2-7B-Chat-GGUF}
      - EMBEDDING_MODEL=${EMBEDDING_MODEL:-BAAI/bge-large-en-v1.5}
      - NUM_GPUS=1
    command: python app.py

networks:
  default:
    name: vllm-network
EOF
```

### 10.3 통합 서비스 설정

#### Dockerfile 생성
```bash
cat << 'EOF' > Dockerfile
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
EOF
```

#### Requirements 설정
```bash
cat << 'EOF' > requirements.txt
vllm
transformers
sentencepiece
accelerate
torch
sentence-transformers
fastapi
uvicorn
EOF
```

#### 통합 API 서비스 구현
```bash
cat << 'EOF' > app.py
import os
from fastapi import FastAPI, HTTPException
from sentence_transformers import SentenceTransformer
import torch
from pydantic import BaseModel
from typing import List, Optional
from vllm import LLM, SamplingParams
import uvicorn

app = FastAPI()

# 모델 초기화
llm_model_name = os.getenv('MODEL_NAME', 'TheBloke/Llama-2-7B-Chat-GGUF')
embedding_model_name = os.getenv('EMBEDDING_MODEL', 'BAAI/bge-large-en-v1.5')

# LLM 모델 로드
llm = LLM(model=llm_model_name, gpu_memory_utilization=0.9)

# 임베딩 모델 로드
embedding_model = SentenceTransformer(embedding_model_name, device='cuda')

class CompletionRequest(BaseModel):
    prompt: str
    max_tokens: Optional[int] = 100
    temperature: Optional[float] = 0.7

class EmbeddingRequest(BaseModel):
    texts: List[str]

@app.post("/v1/completions")
async def create_completion(request: CompletionRequest):
    try:
        sampling_params = SamplingParams(
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )
        outputs = llm.generate([request.prompt], sampling_params)
        
        return {
            "id": "cmpl-" + os.urandom(12).hex(),
            "object": "text_completion",
            "created": int(time.time()),
            "model": llm_model_name,
            "choices": [{
                "text": outputs[0].outputs[0].text,
                "finish_reason": "length" if len(outputs[0].outputs[0].text) >= request.max_tokens else "stop"
            }]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/v1/embeddings")
async def create_embeddings(request: EmbeddingRequest):
    try:
        embeddings = embedding_model.encode(request.texts, convert_to_tensor=True)
        return {"embeddings": embeddings.tolist()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy", "models": {
        "llm": llm_model_name,
        "embedding": embedding_model_name
    }}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
```

### 10.4 환경 변수 설정
```bash
cat << 'EOF' > .env
MODEL_NAME=TheBloke/Llama-2-7B-Chat-GGUF
EMBEDDING_MODEL=BAAI/bge-large-en-v1.5
HUGGING_FACE_CACHE=~/.cache/huggingface
EOF
```

### 10.5 서비스 실행

```bash
# Docker Compose로 서비스 시작
docker compose up -d

# 로그 확인
docker compose logs -f
```

### 10.6 API 사용 예제

#### LLM API 호출
```python
import requests
import json

# LLM 추론 요청
response = requests.post(
    "http://localhost:8000/v1/completions",
    headers={"Content-Type": "application/json"},
    json={
        "prompt": "What is artificial intelligence?",
        "max_tokens": 100,
        "temperature": 0.7
    }
)
print(json.dumps(response.json(), indent=2))
```

#### 임베딩 API 호출
```python
import requests

# 임베딩 생성 요청
response = requests.post(
    "http://localhost:8000/v1/embeddings",
    json={
        "texts": ["Hello, world!", "This is a test sentence."]
    }
)
print(response.json())
```

### 10.7 성능 최적화 및 모니터링
- GPU 메모리는 두 모델이 공유하므로 적절한 모델 크기 선택 필요
- 헬스체크 엔드포인트(/health)를 통해 서비스 상태 모니터링 가능
- 대용량 요청 처리 시 배치 처리 권장

### 10.8 문제 해결
- GPU 메모리 부족: 더 작은 모델 사용 또는 메모리 사용량 조절
- CUDA 오류: NVIDIA 드라이버 버전 확인 및 업데이트
- API 타임아웃: 요청 타임아웃 설정 조정

### 10.9 보안 고려사항
- 프로덕션 환경에서는 API 인증 추가 필요
- 적절한 방화벽 규칙 설정
- 정기적인 보안 업데이트 수행