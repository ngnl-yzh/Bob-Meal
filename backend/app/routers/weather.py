"""날씨 조회 — Phase 2 에서 기상청 API 연동"""
from fastapi import APIRouter, Query
from app.schemas import WeatherOut

router = APIRouter(prefix="/api", tags=["날씨"])


@router.get("/weather", response_model=WeatherOut, summary="현재 날씨")
def get_weather(
    lat: float = Query(35.1468, description="위도"),
    lng: float = Query(126.9162, description="경도"),
):
    """
    현재 위치 날씨 조회.
    Phase 2에서 기상청 단기예보 API(KMA_SERVICE_KEY) 연동 예정.
    현재는 '맑음' 목업 반환.
    날씨에 따라 이동수단 권고 조정 (비/눈 → 실내 우선, 도보 반경 축소 적용 예정)
    """
    # TODO: KMA API 연동
    return WeatherOut(
        condition="맑음",
        temperature=22.5,
        is_outdoor_ok=True,
        advice="날씨가 맑아요. 도보 이동도 좋아요 ☀️",
    )
