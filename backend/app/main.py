"""FastAPI 메인 앱 진입점"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import get_settings
from app.database import engine, SessionLocal, Base
from app.models import *   # noqa: F401 — 모든 모델 import (테이블 생성용)
from app.mock_data import seed_database
from app.routers import recommend, restaurants, users, weather, admin

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 시작 시: 테이블 생성 + 목업 데이터 시드
    try:
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        try:
            seed_database(db)
        finally:
            db.close()
    except Exception as e:
        # DB 연결 실패해도 앱 자체는 기동 (healthcheck 통과)
        print(f"⚠️  DB 초기화 실패 (나중에 재시도됩니다): {e}")
    # 보안 경고: 기본 SECRET_KEY 사용 중이면 운영 환경에서 위험
    if settings.SECRET_KEY == "changeme-in-production-32chars!!":
        print("🚨 경고: SECRET_KEY 가 기본값 → JWT 보안 취약! Railway 환경변수를 설정하세요!")
    # DB 타입 명시 — 배포마다 데이터가 사라지면 SQLite 확인 필요
    if settings.DATABASE_URL.startswith("sqlite"):
        print("⚠️  DATABASE_URL = SQLite (컨테이너 재시작 시 데이터 초기화됨!)")
        print("    Railway PostgreSQL 연결을 확인하세요: Variables → DATABASE_URL")
    else:
        db_host = settings.DATABASE_URL.split("@")[-1].split("/")[0] if "@" in settings.DATABASE_URL else "unknown"
        print(f"✅  DATABASE_URL = PostgreSQL ({db_host})")
    print(f"🚀 {settings.APP_NAME} v{settings.APP_VERSION} 시작")
    yield
    print("👋 서버 종료")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
## 한끼루트 API

대학생·직장인 맞춤형 식사 장소 추천 서비스

### 핵심 기능
- `POST /api/recommend` — 조건 기반 식당 추천 (신분·목적·인원·위치·이동수단·시간·예산)
- `GET /api/restaurant/{id}` — 식당 상세 (메뉴·혼잡도·가격 신뢰도)
- `GET /api/weather` — 현재 날씨 / 기상청 초단기예보
- JWT 기반 회원가입·로그인 / 카카오 소셜 로그인
    """,
    lifespan=lifespan,
)

# CORS — Flutter 앱 및 개발 환경 허용
# 운영 환경에서는 .env 의 ALLOWED_ORIGINS 에 Railway URL 추가
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(recommend.router)
app.include_router(restaurants.router)
app.include_router(users.router)
app.include_router(weather.router)
app.include_router(admin.router)


@app.get("/", tags=["헬스체크"])
def root():
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health", tags=["헬스체크"])
def health():
    return {"status": "ok"}


@app.get("/health/db", tags=["헬스체크"])
def health_db():
    """DB 연결 타입 확인 — SQLite면 데이터가 배포마다 사라짐"""
    url = settings.DATABASE_URL
    is_sqlite = url.startswith("sqlite")
    return {
        "db_type": "sqlite" if is_sqlite else "postgresql",
        "persistent": not is_sqlite,
        "warning": "SQLite는 컨테이너 재시작 시 데이터 초기화됩니다. Railway Variables에 DATABASE_URL(PostgreSQL)을 설정하세요." if is_sqlite else None,
    }
