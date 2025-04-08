from fastapi import FastAPI
import sys
import platform

# FastAPI 애플리케이션 인스턴스 생성
app = FastAPI(
    title="Python 데모 API",
    description="FastAPI를 사용한 데모 API 서버",
    version="1.0.0"
)

@app.get("/")
async def root():
    """
    루트 엔드포인트
    - Python 버전 정보 반환
    - 실행 환경 정보 반환
    """
    return {
        "message": "Python 데모 애플리케이션",
        "info": {
            "python_version": platform.python_version(),  # Python 버전
            "environment": sys.prefix                    # 실행 환경 정보
        }
    }

@app.get("/health")
async def health():
    """
    헬스 체크 엔드포인트
    - 컨테이너 상태 모니터링에 사용
    """
    return {"status": "healthy"}
