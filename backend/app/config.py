from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache
from typing import List


class Settings(BaseSettings):
    # ─── 앱 기본 ──────────────────────────────────────────────
    APP_NAME: str = "한끼로그 API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # ─── 데이터베이스 ──────────────────────────────────────────
    # 로컬: sqlite:///./restaurant.db
    # Railway: 자동으로 DATABASE_URL 환경변수 주입 (postgresql://...)
    DATABASE_URL: str = "sqlite:///./restaurant.db"

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def fix_postgres_scheme(cls, v: str) -> str:
        """Railway는 'postgres://'를 제공하지만 SQLAlchemy는 'postgresql://'이 필요"""
        if isinstance(v, str) and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    # ─── JWT ──────────────────────────────────────────────────
    SECRET_KEY: str = "changeme-in-production-32chars!!"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7일

    # ─── CORS ─────────────────────────────────────────────────
    # 운영: 실제 Flutter 앱 도메인 또는 "*" (개발용)
    # 예: ALLOWED_ORIGINS=https://myapp.com,https://www.myapp.com
    ALLOWED_ORIGINS: str = "*"

    @property
    def cors_origins(self) -> List[str]:
        if self.ALLOWED_ORIGINS.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    # ─── Redis (선택) ─────────────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379"
    USE_REDIS: bool = False

    # ─── 외부 API 키 ───────────────────────────────────────────
    # .env 파일에 입력하세요. 비워두면 목업 데이터로 동작합니다.
    NAVER_CLIENT_ID: str = ""        # 네이버 오픈API (블로그 검색)
    NAVER_CLIENT_SECRET: str = ""
    KAKAO_REST_API_KEY: str = ""     # 카카오 모빌리티 (경로 시간)
    GOOGLE_MAPS_API_KEY: str = ""    # Google Popular Times (혼잡도)
    KMA_SERVICE_KEY: str = ""        # 기상청 단기예보 API

    # ─── 이동수단별 평균 속도 (m/분) — 기획서 3.1 ─────────────
    SPEED_WALK: int = 67
    SPEED_BIKE: int = 200
    SPEED_TRANSIT: int = 333
    SPEED_CAR: int = 500
    MIN_MEAL_MINUTES: int = 20

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
