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