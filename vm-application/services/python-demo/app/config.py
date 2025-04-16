from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Python Demo API"
    DEBUG: bool = False
    VERSION: str = "0.1.0"
    
    # Prometheus 설정
    METRICS_PORT: int = 8000
    METRICS_PATH: str = "/metrics"

settings = Settings()