"""FastAPI 메인 앱 진입점"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import get_settings
from app.database import engine, SessionLocal, Base
from app.models import *   # noqa: F401 — 모든 모델 import (테이블 생성용)
from app.mock_data import seed_database
from app.routers import recommend, restaurants, users, weather

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 시작 시: 테이블 생성 + 목업 데이터 시드
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
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
