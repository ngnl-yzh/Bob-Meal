"""
날씨 조회 — 기상청 초단기예보 API 연동
KMA_SERVICE_KEY 설정 시 실제 날씨 반환, 미설정 시 목업 반환.

기상청 오픈API 신청: https://www.data.go.kr/data/15084084/openapi.do
"""
import math
import datetime
from fastapi import APIRouter, Query
import httpx

from app.config import get_settings
from app.schemas import WeatherOut

router = APIRouter(prefix="/api", tags=["날씨"])
settings = get_settings()


# ─── 위경도 → 기상청 격자(nx, ny) 변환 ──────────────────────────
def _lat_lng_to_grid(lat: float, lng: float) -> tuple[int, int]:
    """Lambert Conformal Conic 투영법 — 기상청 표준 알고리즘"""
    RE = 6371.00877   # 지구 반경 (km)
    GRID = 5.0        # 격자 간격 (km)
    SLAT1 = 30.0      # 표준위도 1
    SLAT2 = 60.0      # 표준위도 2
    OLON = 126.0      # 기준 경도
    OLAT = 38.0       # 기준 위도
    XO = 43           # 기준점 X 격자
    YO = 136          # 기준점 Y 격자

    D = math.pi / 180.0
    re = RE / GRID
    s1 = SLAT1 * D
    s2 = SLAT2 * D
    olon_r = OLON * D
    olat_r = OLAT * D

    sn = math.log(math.cos(s1) / math.cos(s2)) / math.log(
        math.tan(math.pi * 0.25 + s2 * 0.5) / math.tan(math.pi * 0.25 + s1 * 0.5)
    )
    sf = (math.tan(math.pi * 0.25 + s1 * 0.5) ** sn) * math.cos(s1) / sn
    ro = re * sf / (math.tan(math.pi * 0.25 + olat_r * 0.5) ** sn)

    ra = re * sf / (math.tan(math.pi * 0.25 + lat * D * 0.5) ** sn)
    theta = lng * D - olon_r
    if theta > math.pi:
        theta -= 2.0 * math.pi
    if theta < -math.pi:
        theta += 2.0 * math.pi
    theta *= sn

    nx = int(ra * math.sin(theta) + XO + 0.5)
    ny = int(ro - ra * math.cos(theta) + YO + 0.5)
    return nx, ny


# ─── 초단기예보 base_date / base_time 계산 ───────────────────────
def _get_base_datetime() -> tuple[str, str]:
    """
    초단기예보는 매시 30분 이후 이용 가능.
    현재 분 < 30이면 1시간 전 발표 사용.
    """
    now = datetime.datetime.now()
    if now.minute < 30:
        now -= datetime.timedelta(hours=1)
    return now.strftime("%Y%m%d"), now.strftime("%H00")


# ─── 기상청 API 파싱 ─────────────────────────────────────────────
_SKY_MAP = {1: "맑음", 3: "구름많음", 4: "흐림"}
_PTY_MAP = {0: None, 1: "비", 2: "비/눈", 3: "눈", 4: "소나기"}

_ADVICE = {
    "비":    ("비가 와요. 우산을 챙기세요 ☔",           False),
    "비/눈": ("비와 눈이 섞여요. 이동에 주의하세요 🌨️",  False),
    "눈":    ("눈이 와요. 실내 위주로 추천드려요 ❄️",    False),
    "소나기":("소나기가 예보돼요. 우산을 챙기세요 🌦️",   False),
    "맑음":  ("날씨가 맑아요. 도보 이동도 좋아요 ☀️",    True),
    "구름많음":("구름이 많아요. 이동은 괜찮아요 ⛅",      True),
    "흐림":  ("흐린 날이에요. 가까운 곳 위주로 추천해요 ☁️", True),
}


def _fetch_kma_weather(lat: float, lng: float) -> WeatherOut | None:
    """기상청 초단기예보 API 호출. 실패 시 None 반환."""
    if not settings.KMA_SERVICE_KEY:
        return None

    nx, ny = _lat_lng_to_grid(lat, lng)
    base_date, base_time = _get_base_datetime()

    url = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtFcst"
    params = {
        "serviceKey": settings.KMA_SERVICE_KEY,
        "pageNo": 1,
        "numOfRows": 60,
        "dataType": "JSON",
        "base_date": base_date,
        "base_time": base_time,
        "nx": nx,
        "ny": ny,
    }

    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url, params=params)
        if resp.status_code != 200:
            return None

        body = resp.json().get("response", {}).get("body", {})
        if body.get("totalCount", 0) == 0:
            return None

        items = body.get("items", {}).get("item", [])
    except Exception:
        return None

    # 가장 가까운 예보 시각 데이터만 추출 (첫 번째 fcstTime)
    if not items:
        return None
    first_time = items[0]["fcstTime"]
    slot = {i["category"]: i["fcstValue"]
            for i in items if i["fcstTime"] == first_time}

    sky_code = int(slot.get("SKY", 1))
    pty_code = int(slot.get("PTY", 0))
    temp = float(slot.get("T1H", 20.0))

    # 강수 > 하늘 우선
    precip = _PTY_MAP.get(pty_code)
    condition = precip if precip else _SKY_MAP.get(sky_code, "맑음")
    advice_text, outdoor_ok = _ADVICE.get(condition, ("날씨 정보를 불러왔어요.", True))

    return WeatherOut(
        condition=condition,
        temperature=temp,
        is_outdoor_ok=outdoor_ok,
        advice=advice_text,
    )


# ─── 목업 폴백 ────────────────────────────────────────────────────
def _mock_weather() -> WeatherOut:
    return WeatherOut(
        condition="맑음",
        temperature=22.5,
        is_outdoor_ok=True,
        advice="날씨가 맑아요. 도보 이동도 좋아요 ☀️  (KMA_SERVICE_KEY 미설정 — 목업)",
    )


# ─── 라우터 ──────────────────────────────────────────────────────
@router.get("/weather", response_model=WeatherOut, summary="현재 날씨")
def get_weather(
    lat: float = Query(35.1468, description="위도"),
    lng: float = Query(126.9162, description="경도"),
):
    """
    현재 위치 날씨 조회.
    - **KMA_SERVICE_KEY 설정 시**: 기상청 초단기예보 실시간 데이터
    - **미설정 시**: 목업 데이터 반환
    """
    result = _fetch_kma_weather(lat, lng)
    return result if result is not None else _mock_weather()
