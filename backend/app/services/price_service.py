"""
가격 수집 서비스 — 기획서 4장 (3단계 폭포수)

키 설정 여부에 따라 자동 전환:
  NAVER_CLIENT_ID + NAVER_CLIENT_SECRET 설정 → 네이버 블로그 검색 실사용
  미설정 → restaurant.price (목업 데이터) 사용
"""
import re
import statistics
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session

import httpx

from app.config import get_settings
from app.models import PriceData, Restaurant
from app.schemas import PriceInfoOut

settings = get_settings()


# ─── 신뢰도 감쇠 계수 — 기획서 4.2 ──────────────────────────────
def apply_decay(confidence: float, collected_at: datetime) -> float:
    now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
    # PostgreSQL은 timezone-aware datetime을 반환할 수 있으므로 naive로 통일
    collected_naive = collected_at.replace(tzinfo=None) if collected_at.tzinfo else collected_at
    days = (now_naive - collected_naive).days
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
    TODO: 네이버 플레이스 ID 매핑 후 구현
    """
    return None


# ─── 2순위: 네이버 블로그 검색 + 가격 추출 ───────────────────────
def fetch_naver_blog_price(restaurant_name: str) -> Optional[dict]:
    """
    네이버 블로그 검색 API → 정규식 가격 키워드 추출
    NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 설정 시 동작.
    """
    if not settings.NAVER_CLIENT_ID or not settings.NAVER_CLIENT_SECRET:
        return None  # 키 없으면 스킵

    query = f"{restaurant_name} 메뉴 가격"
    url = "https://openapi.naver.com/v1/search/blog.json"
    headers = {
        "X-Naver-Client-Id": settings.NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": settings.NAVER_CLIENT_SECRET,
    }
    params = {"query": query, "display": 5, "sort": "sim"}

    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url, headers=headers, params=params)
        if resp.status_code != 200:
            return None
        items = resp.json().get("items", [])
    except Exception:
        return None

    prices = _extract_prices_from_items(items)
    if not prices:
        return None

    # 이상값 제거 후 중앙값 사용 (안정적)
    prices.sort()
    median_price = int(statistics.median(prices))
    return {
        "price": median_price,
        "confidence": 0.55,
        "source": "naver_blog",
    }


def _extract_prices_from_items(items: list) -> list[int]:
    """블로그 item description 에서 가격 패턴 추출"""
    prices = []
    # HTML 태그 제거 후 가격 패턴 검색
    for item in items:
        text = re.sub(r"<[^>]+>", "", item.get("description", ""))
        # 패턴 1: 12,000원 / 12000원
        for m in re.findall(r"([0-9]{1,2}[,][0-9]{3})\s*원", text):
            p = int(m.replace(",", ""))
            if 2_000 <= p <= 100_000:
                prices.append(p)
        # 패턴 2: 만원 단위 ("1만원", "1만5천원")
        for m in re.findall(r"([0-9]+)\s*만\s*([0-9]*)\s*천?\s*원", text):
            manwon = int(m[0]) * 10_000
            cheon = int(m[1]) * 1_000 if m[1] else 0
            p = manwon + cheon
            if 2_000 <= p <= 100_000:
                prices.append(p)
    return prices


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
    """
    3단계 폭포수로 가격 정보 반환.
    DB 캐시 → 네이버 블로그 → 목업 데이터 순.
    """
    # ① DB 에 저장된 기존 데이터 조회 (최신순)
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

    # ② DB 캐시가 없거나 신뢰도 낮으면 네이버 블로그 시도
    if best is None or best["confidence"] < 0.50:
        blog_result = fetch_naver_blog_price(restaurant.name)
        if blog_result:
            # DB 에 저장 (다음 요청부터는 캐시 사용)
            try:
                db.add(PriceData(
                    restaurant_id=restaurant.id,
                    source=blog_result["source"],
                    price_per_person=blog_result["price"],
                    confidence=blog_result["confidence"],
                    raw_text=f"naver_blog:{restaurant.name}",
                ))
                db.commit()
            except Exception:
                db.rollback()
            best = blog_result

    # ③ 여전히 없으면 restaurant.price 사용 (목업 기본값)
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
