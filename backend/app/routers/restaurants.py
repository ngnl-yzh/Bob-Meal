"""식당 상세 / 리뷰 / 가격 / 혼잡도 신고"""
import json
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.models import Restaurant, Review, CrowdByHour
from app.schemas import (
    RestaurantDetailOut, ReviewOut, PriceInfoOut,
    CrowdReportIn, MenuOut, CrowdByHourOut,
)
from app.config import get_settings
from app.services.price_service import get_price_info
from app.services.crowd_service import get_current_crowd, submit_crowd_report
from app.services.auth_service import get_current_user
from app.services.open_hours_service import (
    get_open_status, build_hours_display,
    search_naver_place_id, fetch_naver_place_schedule,
)
from app.models import User

router = APIRouter(prefix="/api/restaurant", tags=["식당"])
settings = get_settings()


def _get_or_404(db: Session, restaurant_id: str) -> Restaurant:
    r = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="식당을 찾을 수 없습니다")
    return r


# ─── 네이버 플레이스 영업시간 백그라운드 수집 ───────────────────
def _sync_naver_hours(restaurant_id: str, restaurant_name: str,
                      restaurant_address: str, existing_naver_id: str,
                      existing_hours: str):
    """
    네이버 플레이스에서 영업시간을 가져와 DB 업데이트 (백그라운드 실행).
    ※ 백그라운드 태스크는 반드시 독립 세션을 사용해야 함 (요청 세션은 이미 닫힐 수 있음)
    """
    from app.database import SessionLocal
    db = SessionLocal()
    try:
        place_id = existing_naver_id or ""

        # 플레이스 ID 없으면 검색
        if not place_id:
            place_id = search_naver_place_id(restaurant_name, restaurant_address) or ""
            if place_id:
                try:
                    db.query(Restaurant).filter(Restaurant.id == restaurant_id).update(
                        {"naver_place_id": place_id}
                    )
                    db.commit()
                except Exception:
                    db.rollback()

        if not place_id:
            return

        # 영업시간 파싱
        schedule = fetch_naver_place_schedule(place_id)
        if not schedule:
            return

        schedule_json_str = json.dumps(schedule, ensure_ascii=False)
        hours_display = build_hours_display(schedule_json_str)

        try:
            db.query(Restaurant).filter(Restaurant.id == restaurant_id).update(
                {
                    "schedule_json": schedule_json_str,
                    "hours": hours_display or existing_hours,
                }
            )
            db.commit()
        except Exception:
            db.rollback()
    finally:
        db.close()


# ─── 상세 조회 ────────────────────────────────────────────────
@router.get("/{restaurant_id}", response_model=RestaurantDetailOut, summary="식당 상세")
def get_restaurant_detail(
    restaurant_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user_lat: Optional[float] = Query(None, description="사용자 위도 (이동 시간 동적 계산용)"),
    user_lng: Optional[float] = Query(None, description="사용자 경도"),
    transport: str = Query("도보", description="이동수단 (도보/자전거/대중교통/자동차)"),
):
    r = _get_or_404(db, restaurant_id)

    # KST 기준 실시간 영업 상태
    open_status = get_open_status(r.schedule_json or "{}")
    # hours 표시 문자열 — DB에 없으면 schedule_json으로 생성
    hours_display = r.hours or build_hours_display(r.schedule_json or "{}")

    # 도보 이동 시간 동적 계산 (user_lat/lng 제공 시)
    if user_lat and user_lng and r.lat and r.lng:
        from app.services.recommender import distance_meters, SPEED_MAP
        dist = distance_meters(user_lat, user_lng, r.lat, r.lng)
        speed = SPEED_MAP.get(transport, settings.SPEED_WALK)
        calc_walk = int(round(dist / speed))
    else:
        calc_walk = r.walk_minutes  # DB 저장값 (카카오 수집분은 0)

    # 백그라운드: 네이버 플레이스 영업시간 최신화 (세션 분리 버그 수정)
    background_tasks.add_task(
        _sync_naver_hours,
        r.id, r.name, r.address or "", r.naver_place_id or "", r.hours or "",
    )

    menus = [
        MenuOut(
            name=m.name, price=m.price, photo_url=m.photo_url,
            icon=m.icon, hue=m.hue, is_representative=m.is_representative,
        )
        for m in sorted(r.menus, key=lambda m: (not m.is_representative, m.id))
    ]

    crowd_rows = sorted(r.crowd_by_hour, key=lambda c: c.id)
    crowd_out = [
        CrowdByHourOut(
            hour_label=row.hour_label,
            crowd_ratio=row.crowd_ratio,
            is_now=(row.hour_label == "지금"),
        )
        for row in crowd_rows
    ]

    price_info = get_price_info(db, r)

    return RestaurantDetailOut(
        id=r.id,
        name=r.name,
        category=r.category,
        address=r.address,
        lat=r.lat,
        lng=r.lng,
        hours=hours_display,
        is_open=open_status["is_open"],
        today_hours=open_status["today_hours"],
        closes_soon=open_status["closes_soon"],
        break_now=open_status["break_now"],
        hours_note=open_status["note"],
        phone=r.phone,
        rating=r.rating,
        review_count=r.review_count,
        walk_minutes=calc_walk,
        price=r.price,
        price_confidence=r.price_confidence,
        crowd_level=r.crowd_level,
        tags=json.loads(r.tags or "[]"),
        features=json.loads(r.features or "[]"),
        photo_url=r.photo_url,
        hero_icon=r.hero_icon,
        hero_hue=r.hero_hue,
        menus=menus,
        crowd_by_hour=crowd_out,
        price_info=price_info,
        naver_place_id=r.naver_place_id or "",
    )


@router.get("/{restaurant_id}/reviews", response_model=List[ReviewOut], summary="리뷰 목록")
def get_reviews(
    restaurant_id: str,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    _get_or_404(db, restaurant_id)
    reviews = (
        db.query(Review)
        .filter(Review.restaurant_id == restaurant_id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [
        ReviewOut(
            id=rv.id,
            author_name=rv.author_name,
            content=rv.content,
            rating=rv.rating,
            source=rv.source,
            created_at=rv.created_at.isoformat() if rv.created_at else "",
        )
        for rv in reviews
    ]


@router.get("/{restaurant_id}/price", response_model=PriceInfoOut, summary="가격 정보")
def get_price(restaurant_id: str, db: Session = Depends(get_db)):
    r = _get_or_404(db, restaurant_id)
    return get_price_info(db, r)


@router.get("/{restaurant_id}/crowd", summary="현재 혼잡도")
def get_crowd(restaurant_id: str, db: Session = Depends(get_db)):
    r = _get_or_404(db, restaurant_id)
    return get_current_crowd(db, r)


@router.post("/crowd-report", status_code=status.HTTP_201_CREATED, summary="혼잡도 신고")
def report_crowd(
    report_in: CrowdReportIn,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user),
):
    _get_or_404(db, report_in.restaurant_id)
    submit_crowd_report(db, report_in, user_id=current_user.id if current_user else None)
    return {"message": "신고 감사합니다!"}
