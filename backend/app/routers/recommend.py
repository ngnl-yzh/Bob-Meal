"""POST /api/recommend — 핵심 추천 엔드포인트"""
import math
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import RecommendRequest, RecommendResponse
from app.services.recommender import recommend as run_recommend, distance_meters, SPEED_MAP
from app.config import get_settings

router = APIRouter(prefix="/api", tags=["추천"])
settings = get_settings()


@router.post("/recommend", response_model=RecommendResponse, summary="식당 추천")
def get_recommendations(req: RecommendRequest, db: Session = Depends(get_db)):
    """
    사용자 조건(신분·목적·인원·위치·이동수단·시간·예산)을 받아
    최적 식당 목록을 점수순으로 반환합니다.
    """
    result = run_recommend(db, req)
    return RecommendResponse(**result)


@router.get("/recommend/debug", summary="추천 필터 진단 (디버그)")
def recommend_debug(db: Session = Depends(get_db)):
    """
    DB 현황과 필터 단계별 탈락 수를 반환합니다.
    식당이 적게 나오는 원인 파악용 — 인증 불필요.
    """
    from app.models import Restaurant

    # ── 1. DB 전체 현황 ────────────────────────────────────────
    total_all    = db.query(Restaurant).count()
    total_active = db.query(Restaurant).filter(Restaurant.is_active == True).count()
    total_inactive = total_all - total_active

    # ── 2. 연구 범위 bbox 내 식당 ──────────────────────────────
    bbox_q = db.query(Restaurant).filter(
        Restaurant.is_active == True,
        Restaurant.lat >= settings.RESEARCH_LAT_MIN,
        Restaurant.lat <= settings.RESEARCH_LAT_MAX,
        Restaurant.lng >= settings.RESEARCH_LNG_MIN,
        Restaurant.lng <= settings.RESEARCH_LNG_MAX,
    )
    in_bbox = bbox_q.count()

    # ── 3. 데이터 품질 현황 ────────────────────────────────────
    price_zero = db.query(Restaurant).filter(
        Restaurant.is_active == True, Restaurant.price == 0,
    ).count()
    has_schedule = db.query(Restaurant).filter(
        Restaurant.is_active == True,
        Restaurant.schedule_json.notin_(["", "{}"]),
        Restaurant.schedule_json.isnot(None),
    ).count()
    has_naver_id = db.query(Restaurant).filter(
        Restaurant.is_active == True,
        Restaurant.naver_place_id != "",
        Restaurant.naver_place_id.isnot(None),
    ).count()

    # ── 4. 거리 필터 시뮬레이션 (bbox 중심 기준, 학생 도보) ───
    center_lat = settings.RESEARCH_LAT_CENTER
    center_lng = settings.RESEARCH_LNG_CENTER
    SPEED_WALK = 67  # m/분

    bbox_restaurants = bbox_q.all()
    def _pass(r, max_one_way_min):
        d = distance_meters(center_lat, center_lng, r.lat, r.lng)
        return (d / SPEED_WALK) <= max_one_way_min

    within_30 = sum(1 for r in bbox_restaurants if _pass(r, 5))    # (30-20)/2=5분
    within_60 = sum(1 for r in bbox_restaurants if _pass(r, 20))   # (60-20)/2=20분
    within_90 = sum(1 for r in bbox_restaurants if _pass(r, 35))   # (90-20)/2=35분
    within_120 = sum(1 for r in bbox_restaurants if _pass(r, 50))  # (120-20)/2=50분

    # ── 5. bbox 내 식당 샘플 ──────────────────────────────────
    sample = bbox_q.limit(30).all()

    return {
        "db_stats": {
            "total_restaurants": total_all,
            "active": total_active,
            "inactive_deactivated": total_inactive,
            "in_research_bbox": in_bbox,
            "price_zero_count": price_zero,
            "has_schedule_count": has_schedule,
            "has_naver_id_count": has_naver_id,
        },
        "bbox": {
            "area_name": settings.RESEARCH_AREA_NAME,
            "lat": f"{settings.RESEARCH_LAT_MIN} ~ {settings.RESEARCH_LAT_MAX}",
            "lng": f"{settings.RESEARCH_LNG_MIN} ~ {settings.RESEARCH_LNG_MAX}",
            "center": f"{center_lat}, {center_lng}",
        },
        "distance_simulation": {
            "note": "bbox 중심에서 도보 기준, 가용 시간별 통과 수",
            "available_30min_walk": within_30,
            "available_60min_walk": within_60,
            "available_90min_walk": within_90,
            "available_120min_walk": within_120,
        },
        "sample_in_bbox": [
            {
                "name": r.name,
                "address": r.address,
                "lat": r.lat,
                "lng": r.lng,
                "price": r.price,
                "schedule_collected": bool(r.schedule_json and r.schedule_json not in ("{}", "")),
                "naver_linked": bool(r.naver_place_id),
            }
            for r in sample
        ],
    }
