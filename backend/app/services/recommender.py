"""
추천 엔진 — 기획서 3.1 / 3.2 구현
탐색 반경 계산 + 추천 점수 산식
"""
import math
import json
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session

from sqlalchemy.orm import subqueryload

from app.config import get_settings
from app.models import Restaurant, Menu
from app.schemas import RecommendRequest, RestaurantCardOut, SortEnum
from app.services.open_hours_service import get_open_status

settings = get_settings()

# ─── 이동수단별 속도 (m/분) — 기획서 3.1 ────────────────────────
SPEED_MAP = {
    "도보": settings.SPEED_WALK,
    "자전거": settings.SPEED_BIKE,
    "대중교통": settings.SPEED_TRANSIT,
    "자동차": settings.SPEED_CAR,
}

# ─── 목적별 가중치 — 기획서 3.2 ──────────────────────────────────
# (분위기, 가성비, 접근성, 대화환경)
PURPOSE_WEIGHTS = {
    "혼밥":    {"atmosphere": 0.5,  "value": 1.5,  "access": 1.5, "social": 0.5},
    "친목":    {"atmosphere": 1.0,  "value": 1.0,  "access": 1.0, "social": 1.5},
    "소개팅":  {"atmosphere": 1.5,  "value": 0.5,  "access": 1.0, "social": 1.5},
    "회식":    {"atmosphere": 1.0,  "value": 1.0,  "access": 1.5, "social": 1.5},
    "비즈니스":{"atmosphere": 1.5,  "value": 0.5,  "access": 1.5, "social": 1.0},
}

# 소개팅/비즈니스 시 고급 카테고리 선호
HIGH_ATMOSPHERE_CATEGORIES = {"한식", "일식"}
# 혼밥 시 혼밥 가능 태그 보너스
SOLO_FRIENDLY_TAG = "혼밥 가능"

# 식사 시간대별 영업 시간 기준 — 기획서 추가
MEAL_TIME_HOURS = {
    "아침":   (6,  10),
    "점심":   (11, 14),
    "저녁":   (17, 21),
    "술자리": (18, 24),
}


def calc_radius_meters(transport: str, available_minutes: int) -> int:
    """
    탐색 반경 계산 — 기획서 3.1
    반경 = (가용시간 - 최소식사시간) / 2 × 속도
    """
    speed = SPEED_MAP.get(transport, settings.SPEED_WALK)
    effective_minutes = max(0, available_minutes - settings.MIN_MEAL_MINUTES)
    one_way_minutes = effective_minutes / 2
    return int(one_way_minutes * speed)


def calc_review_score(review_count: int) -> float:
    """리뷰 수를 0~1 점수로 정규화 (로그 스케일)"""
    if review_count <= 0:
        return 0.0
    return min(1.0, math.log10(review_count + 1) / math.log10(500))


def calc_purpose_fit(
    restaurant: Restaurant,
    purpose: str,
    party_size: int,
    calc_walk_minutes: Optional[int] = None,
) -> float:
    """목적 적합도 — 0.0 ~ 1.0

    calc_walk_minutes: 동적으로 계산된 도보 분 (없으면 DB 저장값 사용)
    """
    score = 0.5  # 기본값
    weights = PURPOSE_WEIGHTS.get(purpose, PURPOSE_WEIGHTS["혼밥"])
    tags = json.loads(restaurant.tags or "[]")
    features = json.loads(restaurant.features or "[]")
    all_features = tags + features

    # 혼밥 목적: 혼밥 가능 태그 보너스
    if purpose == "혼밥":
        if SOLO_FRIENDLY_TAG in all_features:
            score += 0.3
        if party_size == 1:
            score += 0.2

    # 회식/단체: 단체석 여부
    if purpose in ("회식", "친목") and party_size >= 4:
        if "단체석" in all_features:
            score += 0.3

    # 소개팅/비즈니스: 분위기 선호
    if purpose in ("소개팅", "비즈니스"):
        if restaurant.category in HIGH_ATMOSPHERE_CATEGORIES:
            score += 0.2
        if restaurant.crowd_level == "한산":
            score += 0.1

    # 접근성: 가까울수록 + (동적 계산값 우선 사용)
    walk = calc_walk_minutes if calc_walk_minutes is not None else restaurant.walk_minutes
    if walk <= 5:
        score += 0.1 * weights["access"]
    elif walk <= 10:
        score += 0.05 * weights["access"]

    return min(1.0, score)


def calc_meal_time_fit(restaurant: Restaurant, meal_time: str) -> float:
    """
    식사 시간대 적합도 — 0.0 or 1.0
    - meal_times 목록에 포함되어 있고 영업 시간 내이면 1.0
    - 술자리인데 has_alcohol=False 이면 0.0
    """
    if meal_time == "술자리" and not restaurant.has_alcohol:
        return 0.0

    meal_times = json.loads(restaurant.meal_times or '["점심","저녁"]')
    if meal_time not in meal_times:
        return 0.0

    # 영업 시간 체크
    open_h = restaurant.open_hour or 0
    close_h = restaurant.close_hour or 24
    meal_start, meal_end = MEAL_TIME_HOURS.get(meal_time, (11, 14))

    # 식사 시간대가 영업 구간과 겹치면 OK
    if open_h <= meal_end and close_h >= meal_start:
        return 1.0
    return 0.5  # 등록은 됐지만 영업 시간 경계에 걸릴 때 부분 점수


def _effective_price(restaurant: Restaurant, budget_cap: int) -> int:
    """
    가격 계산 기준 결정.
    대표 메뉴(is_representative=True)가 있으면 그 중 budget_cap+2000 이하인 것의
    최고 금액을 사용 (가장 비싸지만 예산 내). 없으면 restaurant.price 사용.
    """
    rep_menus = [m for m in (restaurant.menus or []) if m.is_representative]
    if rep_menus:
        affordable = [m.price for m in rep_menus if m.price <= budget_cap + 2000]
        if affordable:
            return max(affordable)
        # 대표 메뉴 전부 예산 초과 → 가장 싼 대표 메뉴
        return min(m.price for m in rep_menus)
    return restaurant.price


def calc_price_fit(restaurant: Restaurant, budget_cap: int) -> float:
    """가격 적합도 — 대표 메뉴 기준, 없으면 restaurant.price 기준"""
    price = _effective_price(restaurant, budget_cap)
    if price > budget_cap + 2000:
        return 0.0
    ratio = price / budget_cap if budget_cap > 0 else 1.0
    # 예산의 70~90% 범위가 최적
    if 0.7 <= ratio <= 0.9:
        return 1.0
    elif ratio < 0.7:
        return 0.7 + ratio * 0.3
    else:
        return max(0.0, 1.0 - (ratio - 0.9) * 5)


def calc_total_score(
    restaurant: Restaurant,
    purpose: str,
    party_size: int,
    budget_cap: int,
    meal_time: str = "점심",
    calc_walk_minutes: Optional[int] = None,
) -> float:
    """
    최종 점수 — 기획서 3.2 (식사 시간대 항목 추가)
    = (별점 × 0.25) + (리뷰수점수 × 0.15) + (목적적합도 × 0.25)
      + (가격적합도 × 0.15) + (식사시간대적합도 × 0.20)
    """
    # rating=0 은 "미수집" 상태 → 중립값(3점 = 0.6)으로 처리해 신규 식당 불이익 방지
    rating_score = (restaurant.rating / 5.0) if restaurant.rating > 0 else 0.6
    review_score = calc_review_score(restaurant.review_count)
    purpose_score = calc_purpose_fit(
        restaurant, purpose, party_size, calc_walk_minutes=calc_walk_minutes
    )
    price_score = calc_price_fit(restaurant, budget_cap)
    meal_time_score = calc_meal_time_fit(restaurant, meal_time)

    return (
        rating_score * 0.25
        + review_score * 0.15
        + purpose_score * 0.25
        + price_score * 0.15
        + meal_time_score * 0.20
    )


def get_budget_cap(identity: str, price_mode: str, price_max: Optional[int]) -> int:
    """예산 상한 결정 — 기본값은 신분 기반"""
    if price_mode == "custom" and price_max:
        return price_max
    return 8000 if identity == "학생" else 12000


def distance_meters(lat1, lng1, lat2, lng2) -> float:
    """Haversine 공식으로 두 좌표 간 거리(m) 계산"""
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def recommend(db: Session, req: RecommendRequest) -> dict:
    """추천 메인 로직"""
    from datetime import datetime
    from zoneinfo import ZoneInfo
    KST = ZoneInfo("Asia/Seoul")

    # 목표 시각 파싱 (없으면 현재 KST)
    if req.target_datetime:
        try:
            target_dt = datetime.strptime(req.target_datetime, "%Y-%m-%dT%H:%M").replace(tzinfo=KST)
        except ValueError:
            target_dt = datetime.now(KST)
    else:
        target_dt = datetime.now(KST)

    radius = calc_radius_meters(req.transport.value, req.available_minutes)
    budget_cap = get_budget_cap(req.identity.value, req.price_mode.value, req.price_max)

    # 1) 활성 식당 + 연구 범위(광주 북구) 필터 + 대표 메뉴 eager-load
    # 주소 기반(북구 포함) + bbox 이중 필터 → 인접구(서구·동구 등) 혼입 방지
    from sqlalchemy import or_, and_
    restaurants: List[Restaurant] = (
        db.query(Restaurant)
        .filter(
            Restaurant.is_active == True,
            or_(
                # ① 주소에 '북구' 포함 (가장 정확)
                Restaurant.address.contains("북구"),
                # ② 주소가 짧거나 미기입된 경우 bbox 좌표로 보조 (단, 타구 제외)
                and_(
                    Restaurant.lat >= settings.RESEARCH_LAT_MIN,
                    Restaurant.lat <= settings.RESEARCH_LAT_MAX,
                    Restaurant.lng >= settings.RESEARCH_LNG_MIN,
                    Restaurant.lng <= settings.RESEARCH_LNG_MAX,
                    ~Restaurant.address.contains("서구"),
                    ~Restaurant.address.contains("동구"),
                    ~Restaurant.address.contains("남구"),
                    ~Restaurant.address.contains("광산구"),
                ),
            ),
        )
        .options(subqueryload(Restaurant.menus))
        .all()
    )

    meal_time = req.meal_time.value  # "아침"/"점심"/"저녁"/"술자리"

    # 사용자 위치 미제공 시 북구 중심으로 폴백 (GPS 거부·실패 시)
    lat = req.lat if req.lat is not None else settings.RESEARCH_LAT_CENTER
    lng = req.lng if req.lng is not None else settings.RESEARCH_LNG_CENTER

    # 2) 필터링: 거리 + 예산 + 식사 시간대
    # filtered: (restaurant, travel_minutes, walk_minutes) 튜플 목록
    # - travel_minutes : 선택한 이동수단 기준 (필터/정렬 기준)
    # - walk_minutes   : 항상 도보 기준 (거리 감각 표시용)
    speed = SPEED_MAP.get(req.transport.value, settings.SPEED_WALK)
    max_one_way = (req.available_minutes - settings.MIN_MEAL_MINUTES) / 2

    filtered: List[Tuple[Restaurant, int, int]] = []
    for r in restaurants:
        # 거리 필터 (GPS 좌표 기반 Haversine — 폴백 포함 항상 유효)
        # ※ `if lat is not None` 체크: lat=0.0 같은 엣지케이스 방어
        if lat is not None and lng is not None:
            dist = distance_meters(lat, lng, r.lat, r.lng)
            travel_est = dist / speed                     # 이동수단 기준 (분) — 필터용
            walk_est   = dist / settings.SPEED_WALK       # 도보 환산 (분) — 표시용
        else:
            travel_est = float(r.walk_minutes)
            walk_est   = float(r.walk_minutes)

        # 이동수단 기준 거리 필터 (버그 수정: 이전에는 항상 도보로 계산)
        if travel_est > max_one_way:
            continue

        # 예산 필터 — 대표 메뉴 기준 (없으면 restaurant.price), 오차 ±2000원
        rep_menus = [m for m in (r.menus or []) if m.is_representative]
        if rep_menus:
            affordable = [m for m in rep_menus if m.price <= budget_cap + 2000]
            if len(rep_menus) >= 2:
                # 대표 메뉴가 2개 이상 → 그 중 2개 이상이 예산 내여야 포함
                if len(affordable) < 2:
                    continue
            else:
                # 대표 메뉴가 1개뿐 → 그 1개가 예산 내면 포함
                if not affordable:
                    continue
        else:
            # 메뉴 미수집 → restaurant.price 기준, 오차 ±2000원
            if r.price > budget_cap + 2000:
                continue

        # 술자리 하드 필터 — 주류 미판매 식당 제외
        if meal_time == "술자리" and not r.has_alcohol:
            continue

        # 영업 여부 — 연구 단계에서는 하드 필터링 안 함
        # (영업 중/닫힘 표시는 카드 is_open 필드에서 처리)

        filtered.append((r, int(round(travel_est)), int(round(walk_est))))

    # 3) 점수 산출
    # scored: (restaurant, score, travel_minutes, walk_minutes)
    scored: List[Tuple[Restaurant, float, int, int]] = []
    for r, travel_min, walk_min in filtered:
        score = calc_total_score(
            r, req.purpose.value, req.party_size, budget_cap,
            meal_time, calc_walk_minutes=travel_min,  # 이동수단 기준으로 접근성 점수 계산
        )
        scored.append((r, score, travel_min, walk_min))

    # 4) 정렬
    if req.sort == SortEnum.recommended:
        scored.sort(key=lambda x: x[1], reverse=True)
    elif req.sort == SortEnum.distance:
        scored.sort(key=lambda x: x[2])   # 이동수단 기준 이동 시간순
    elif req.sort == SortEnum.price:
        scored.sort(key=lambda x: x[0].price)

    # 5) 직렬화
    results = []
    for r, score, travel_min, walk_min in scored[:8]:
        tags = json.loads(r.tags or "[]")
        open_status = get_open_status(r.schedule_json or "{}", target_dt=target_dt)  # target_dt 반드시 전달
        results.append(RestaurantCardOut(
            id=r.id,
            name=r.name,
            category=r.category,
            is_open=open_status["is_open"],
            today_hours=open_status["today_hours"],
            closes_soon=open_status["closes_soon"],
            crowd_level=r.crowd_level,
            rating=r.rating,
            review_count=r.review_count,
            walk_minutes=walk_min,        # 도보 기준 분 (거리 감각 표시)
            price=r.price,
            price_confidence=r.price_confidence,
            tags=tags,
            photo_url=r.photo_url,
            hero_icon=r.hero_icon,
            hero_hue=r.hero_hue,
            score=round(score, 4),
        ))

    # 요약 문구
    time_label = {30: "30분", 60: "1시간", 90: "1.5시간", 120: "2시간+"}.get(
        req.available_minutes, f"{req.available_minutes}분"
    )
    summary = (
        f"{req.transport.value} {time_label} 이내 · "
        f"~{budget_cap:,}원 · {meal_time} {req.purpose.value} {req.party_size}인"
    )

    return {
        "total": len(results),
        "radius_meters": radius,
        "budget_cap": budget_cap,
        "summary": summary,
        "results": results,
    }
