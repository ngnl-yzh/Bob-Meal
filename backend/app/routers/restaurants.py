"""식당 상세 / 리뷰 / 가격 / 혼잡도 신고"""
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.models import Restaurant, Review, CrowdByHour
from app.schemas import (
    RestaurantDetailOut, ReviewOut, PriceInfoOut,
    CrowdReportIn, MenuOut, CrowdByHourOut,
)
from app.services.price_service import get_price_info
from app.services.crowd_service import get_current_crowd, submit_crowd_report
from app.services.auth_service import get_current_user
from app.models import User

router = APIRouter(prefix="/api/restaurant", tags=["식당"])


def _get_or_404(db: Session, restaurant_id: str) -> Restaurant:
    r = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="식당을 찾을 수 없습니다")
    return r


@router.get("/{restaurant_id}", response_model=RestaurantDetailOut, summary="식당 상세")
def get_restaurant_detail(restaurant_id: str, db: Session = Depends(get_db)):
    r = _get_or_404(db, restaurant_id)

    menus = [
        MenuOut(
            name=m.name, price=m.price, photo_url=m.photo_url,
            icon=m.icon, hue=m.hue, is_representative=m.is_representative,
        )
        for m in sorted(r.menus, key=lambda m: (not m.is_representative, m.id))
    ]

    crowd_rows = sorted(r.crowd_by_hour, key=lambda c: c.id)
    now_hour = datetime.now().hour
    crowd_out = []
    for row in crowd_rows:
        is_now = row.hour_label == "지금"
        crowd_out.append(CrowdByHourOut(
            hour_label=row.hour_label,
            crowd_ratio=row.crowd_ratio,
            is_now=is_now,
        ))

    price_info = get_price_info(db, r)

    return RestaurantDetailOut(
        id=r.id,
        name=r.name,
        category=r.category,
        address=r.address,
        lat=r.lat,
        lng=r.lng,
        hours=r.hours or "",
        is_open=r.is_open,
        phone=r.phone,
        rating=r.rating,
        review_count=r.review_count,
        walk_minutes=r.walk_minutes,
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
