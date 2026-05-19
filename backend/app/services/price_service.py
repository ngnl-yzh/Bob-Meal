"""
가격 수집 서비스 — 기획서 4장 (3단계 폭포수)
현재: 목업 / Phase 2에서 실제 API 연동
"""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session

from app.models import PriceData, Restaurant
from app.schemas import PriceInfoOut


# ─── 신뢰도 감쇠 계수 — 기획서 4.2 ──────────────────────────────
def apply_decay(confidence: float, collected_at: datetime) -> float:
    days = (datetime.utcnow() - collected_at).days
    if days <= 30:
        return confidence
    elif days <= 90:
        return confidence * 0.85
    elif days <= 180:
        return confidence * 0.65
    elif days <= 365:
        return confidence * 0.40
    else:
        return confidence * 0.15


# ─── 표시 모드 결정 — 기획서 4.3 ────────────────────────────────
def get_display_mode(confidence: float) -> str:
    if confidence >= 0.8:
        return "exact"
    elif confidence >= 0.5:
        return "range"
    else:
        return "unknown"


def build_display_text(price: int, mode: str) -> str:
    if mode == "exact":
        return f"약 {price:,}원"
    elif mode == "range":
        lo = int(price * 0.85 // 500) * 500
        hi = int(price * 1.15 // 500 + 1) * 500
        return f"{lo:,}~{hi:,}원 추정"
    else:
        return "가격 정보 부족 · 방문 후 알려주세요!"


# ─── 1순위: 네이버 플레이스 (Phase 2) ───────────────────────────
def fetch_naver_place_price(restaurant_id: str) -> Optional[dict]:
    """
    네이버 플레이스 내부 API 파싱
    Phase 2 에서 구현 — NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 필요
    """
    return None  # TODO


# ─── 2순위: 네이버 블로그 NLP (Phase 2) ─────────────────────────
def fetch_naver_blog_price(restaurant_name: str) -> Optional[dict]:
    """
    네이버 블로그 검색 → 정규식 + NLP 가격 키워드 추출
    Phase 2 에서 구현
    """
    return None  # TODO


# ─── 3순위: 카테고리 추정 ────────────────────────────────────────
CATEGORY_PRICE_MAP = {
    "한식": {"price": 9000,  "confidence": 0.20},
    "일식": {"price": 11000, "confidence": 0.20},
    "중식": {"price": 8000,  "confidence": 0.20},
    "양식": {"price": 14000, "confidence": 0.20},
    "분식": {"price": 6000,  "confidence": 0.20},
    "카페": {"price": 5500,  "confidence": 0.20},
}

def estimate_by_category(category: str) -> dict:
    return CATEGORY_PRICE_MAP.get(category, {"price": 10000, "confidence": 0.20})


# ─── 메인: 가격 정보 조회 ────────────────────────────────────────
def get_price_info(db: Session, restaurant: Restaurant) -> PriceInfoOut:
    """3단계 폭포수로 가격 정보 반환"""

    # DB 에 저장된 기존 가격 데이터 조회 (최신순)
    price_records = (
        db.query(PriceData)
        .filter(PriceData.restaurant_id == restaurant.id)
        .order_by(PriceData.collected_at.desc())
        .all()
    )

    best = None
    for rec in price_records:
        effective_conf = apply_decay(rec.confidence, rec.collected_at)
        if best is None or effective_conf > best["confidence"]:
            best = {
                "price": rec.price_per_person,
                "confidence": effective_conf,
                "source": rec.source,
            }

    # DB 에 데이터 없으면 restaurant.price / confidence 사용
    if best is None:
        best = {
            "price": restaurant.price,
            "confidence": restaurant.price_confidence,
            "source": "mock",
        }

    mode = get_display_mode(best["confidence"])
    return PriceInfoOut(
        price_per_person=best["price"],
        confidence=round(best["confidence"], 3),
        display_mode=mode,
        display_text=build_display_text(best["price"], mode),
        source=best["source"],
    )
