"""POST /api/recommend — 핵심 추천 엔드포인트"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import RecommendRequest, RecommendResponse
from app.services.recommender import recommend as run_recommend

router = APIRouter(prefix="/api", tags=["추천"])


@router.post("/recommend", response_model=RecommendResponse, summary="식당 추천")
def get_recommendations(req: RecommendRequest, db: Session = Depends(get_db)):
    """
    사용자 조건(신분·목적·인원·위치·이동수단·시간·예산)을 받아
    최적 식당 목록을 점수순으로 반환합니다.
    """
    result = run_recommend(db, req)
    return RecommendResponse(**result)
