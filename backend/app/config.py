from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # 앱 기본
    APP_NAME: str = "식당 추천 API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # 데이터베이스
    DATABASE_URL: str = "sqlite:///./restaurant.db"  # 개발용 SQLite (운영: PostgreSQL)

    # JWT
    SECRET_KEY: str = "changeme-in-production-32chars!!"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7일

    # Redis (선택)
    REDIS_URL: str = "redis://localhost:6379"
    USE_REDIS: bool = False

    # 외부 API (Phase 2 에서 실제 키 설정)
    NAVER_CLIENT_ID: str = ""
    NAVER_CLIENT_SECRET: str = ""
    KAKAO_REST_API_KEY: str = ""
    GOOGLE_MAPS_API_KEY: str = ""
    KMA_SERVICE_KEY: str = ""  # 기상청

    # 이동수단별 평균 속도 (m/분) — 기획서 3.1
    SPEED_WALK: int = 67
    SPEED_BIKE: int = 200
    SPEED_TRANSIT: int = 333
    SPEED_CAR: int = 500
    MIN_MEAL_MINUTES: int = 20  # 최소 식사 시간 공제

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
