from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    app_name: str = "FastAPI Dagobah"
    version: str = "0.1.0"
    debug: bool = False

    # Database
    database_url: Optional[str] = None

    # APISIX Integration
    apisix_consumer_header: str = "X-Consumer-Username"
    apisix_user_id_header: str = "X-User-ID"

    # API Settings
    api_v1_prefix: str = "/api/v1"

    class Config:
        env_file = ".env"


settings = Settings()