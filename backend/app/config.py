from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache
from typing import List


class Settings(BaseSettings):
    # ─── 앱 기본 ──────────────────────────────────────────────
    APP_NAME: str = "한끼루트 API"
    APP_VERSION: str = "1.3.0"
    DEBUG: bool = False   # Railway 환경변수로 개발 시에만 True

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

    # ─── 관리자 API 키 ─────────────────────────────────────────
    # Railway 환경변수에 설정. 미설정 시 admin 엔드포인트 비활성화.
    ADMIN_SECRET_KEY: str = ""

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

    # ─── 연구 범위 (광주광역시 북구 용봉동) ────────────────────
    # 전남대학교 캠퍼스를 포함한 용봉동 및 인접 상권
    RESEARCH_AREA_NAME: str = "광주 용봉동"
    RESEARCH_LAT_CENTER: float = 35.1762   # 전남대 정문 기준
    RESEARCH_LNG_CENTER: float = 126.9097
    RESEARCH_LAT_MIN: float = 35.162       # 남쪽 경계
    RESEARCH_LAT_MAX: float = 35.190       # 북쪽 경계
    RESEARCH_LNG_MIN: float = 126.888      # 서쪽 경계
    RESEARCH_LNG_MAX: float = 126.930      # 동쪽 경계

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
