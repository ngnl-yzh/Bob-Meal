#!/usr/bin/env python3
"""
enrich_naver.py — 네이버 플레이스 데이터 일괄 보강

두 가지 기능:
  1. enrich   : 기존 식당 → 네이버에서 영업시간·메뉴·이미지·좌표 보강
  2. collect  : 네이버 로컬 검색으로 새 식당 발견 (카카오 수집 보완)

사용법:
  cd backend
  python enrich_naver.py enrich              # 전체 보강
  python enrich_naver.py enrich --limit 50   # 50개만
  python enrich_naver.py collect             # 북구 키워드 수집
  python enrich_naver.py collect --dry-run   # DB 저장 없이 확인
"""
import sys
import os
import re
import time
import json
import argparse
from datetime import datetime, timezone
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal, engine, Base
from app.models import Restaurant, Menu, PriceData
from app.config import get_settings
from app.services.open_hours_service import (
    fetch_naver_place_full,
    search_naver_restaurants,
    search_naver_place_id,
    fetch_naver_place_menus,
    derive_price_from_menus,
)

settings = get_settings()

# ──────────────────────────────────────────────────────────────
# 카테고리 매핑 (네이버 category_raw → 앱 카테고리)
# ──────────────────────────────────────────────────────────────
_KEYWORD_MAP: list[tuple[str, str]] = [
    ("초밥", "일식"), ("스시", "일식"), ("라멘", "일식"), ("우동", "일식"),
    ("돈코츠", "일식"), ("이자카야", "일식"), ("오마카세", "일식"),
    ("짜장", "중식"), ("짬뽕", "중식"), ("마라", "중식"), ("탕수육", "중식"),
    ("딤섬", "중식"), ("중화", "중식"), ("중국", "중식"),
    ("파스타", "양식"), ("스테이크", "양식"), ("피자", "양식"), ("버거", "양식"),
    ("브런치", "양식"), ("샌드위치", "양식"), ("샐러드", "양식"),
    ("분식", "분식"), ("떡볶이", "분식"), ("순대", "분식"), ("김밥", "분식"),
    ("라면", "분식"),
    ("카페", "카페"), ("디저트", "카페"), ("베이커리", "카페"), ("커피", "카페"),
    ("빵", "카페"), ("케이크", "카페"),
]
_ALCOHOL_KW = {"치킨", "호프", "맥주", "삼겹살", "곱창", "막창", "족발", "보쌈", "이자카야",
              "술집", "주점", "포장마차", "막걸리", "와인", "소주", "안주", "펍", "바"}
_DEFAULTS = {
    "한식": {"price": 9000, "icon": "stew", "hue": 28, "open_hour": 11, "close_hour": 21, "meal_times": '["점심","저녁"]'},
    "일식": {"price": 12000, "icon": "katsu", "hue": 200, "open_hour": 11, "close_hour": 22, "meal_times": '["점심","저녁"]'},
    "중식": {"price": 10000, "icon": "noodle", "hue": 0, "open_hour": 11, "close_hour": 22, "meal_times": '["점심","저녁"]'},
    "양식": {"price": 13000, "icon": "rice-bowl", "hue": 220, "open_hour": 11, "close_hour": 22, "meal_times": '["점심","저녁"]'},
    "분식": {"price": 5500, "icon": "kimbap", "hue": 50, "open_hour": 10, "close_hour": 21, "meal_times": '["아침","점심","저녁"]'},
    "카페": {"price": 5000, "icon": "rice-bowl", "hue": 30, "open_hour": 8, "close_hour": 22, "meal_times": '["아침","점심"]'},
}


def _infer_category(raw: str) -> str:
    for kw, cat in _KEYWORD_MAP:
        if kw in raw:
            return cat
    if "카페" in raw or "커피" in raw:
        return "카페"
    return "한식"


def _has_alcohol(raw: str) -> bool:
    return any(kw in raw for kw in _ALCOHOL_KW)


def _in_bbox(lat: float, lng: float) -> bool:
    return (
        settings.RESEARCH_LAT_MIN <= lat <= settings.RESEARCH_LAT_MAX
        and settings.RESEARCH_LNG_MIN <= lng <= settings.RESEARCH_LNG_MAX
    )


# ──────────────────────────────────────────────────────────────
# 1) 기존 식당 네이버 보강
# ──────────────────────────────────────────────────────────────
def enrich(
    limit: Optional[int] = None,
    dry_run: bool = False,
    progress_status: Optional[dict] = None,
) -> dict:
    """
    DB에 있는 식당 중 naver_place_id 없는 항목을 네이버에서 보강.
    반환: {"searched": int, "id_found": int, "enriched": int, "skipped": int}
    """
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # 보강 대상:
        #  ① naver_place_id 없음 → 검색으로 ID 확보 후 전체 데이터 수집
        #  ② naver_place_id 있지만 photo_url 없음 → collect()로 추가됐으나 full 데이터 미수집
        from sqlalchemy import or_ as _or
        query = db.query(Restaurant).filter(
            Restaurant.is_active == True,
            _or(
                Restaurant.naver_place_id == None,
                Restaurant.naver_place_id == "",
                Restaurant.photo_url == None,
                Restaurant.photo_url == "",
            ),
        )
        targets = query.limit(limit).all() if limit else query.all()

        total = len(targets)
        print(f"🔍 네이버 보강 대상: {total:,}개 (naver_place_id 미확보 또는 사진 미수집)")
        if not settings.NAVER_CLIENT_ID:
            print("⚠️  NAVER_CLIENT_ID 미설정 → 네이버 오픈API 검색 불가 (내부 API 기반 보강만 가능)")

        searched = id_found = enriched = skipped = 0

        for idx, r in enumerate(targets, 1):
            if progress_status is not None:
                progress_status["last"] = f"보강 중: {idx}/{total} ({r.name})"
                progress_status["count"] = enriched

            # ① 네이버 Place ID — 이미 있으면 재사용, 없으면 검색
            place_id = r.naver_place_id or ""
            if not place_id:
                if settings.NAVER_CLIENT_ID:
                    searched += 1
                    place_id = search_naver_place_id(r.name, r.address) or ""
                    if place_id:
                        id_found += 1

            if not place_id:
                skipped += 1
                time.sleep(0.05)
                continue

            # ② full summary 수집 (영업시간 + 메뉴 + 이미지 + 좌표)
            full = fetch_naver_place_full(place_id)
            if not full:
                skipped += 1
                time.sleep(0.1)
                continue

            if not dry_run:
                update_fields: dict = {"naver_place_id": place_id}

                # 영업시간
                if full.get("schedule"):
                    update_fields["schedule_json"] = json.dumps(full["schedule"], ensure_ascii=False)

                # 이미지
                if full.get("photo_url"):
                    update_fields["photo_url"] = full["photo_url"]

                # 좌표 (보강 — 카카오 좌표가 더 정확하면 유지)
                if full.get("lat") and full.get("lng") and (not r.lat or not r.lng):
                    update_fields["lat"] = full["lat"]
                    update_fields["lng"] = full["lng"]

                # 전화
                if full.get("phone") and not r.phone:
                    update_fields["phone"] = full["phone"]

                db.query(Restaurant).filter(Restaurant.id == r.id).update(
                    update_fields, synchronize_session=False
                )

                # 메뉴 저장
                menus = full.get("menus") or []
                if not menus:
                    menus = fetch_naver_place_menus(place_id)  # fallback

                if menus:
                    # 기존 메뉴 삭제 후 재삽입
                    db.query(Menu).filter(Menu.restaurant_id == r.id).delete()
                    for m in menus:
                        db.add(Menu(
                            restaurant_id=r.id,
                            name=m["name"],
                            price=m["price"],
                            photo_url=m.get("photo_url", ""),
                            is_representative=m.get("is_representative", False),
                        ))

                    # 가격 갱신
                    derived = derive_price_from_menus(menus)
                    if derived:
                        db.query(Restaurant).filter(Restaurant.id == r.id).update(
                            {"price": derived, "price_confidence": 0.8},
                            synchronize_session=False,
                        )
                        db.add(PriceData(
                            restaurant_id=r.id,
                            source="naver_place",
                            price_per_person=derived,
                            confidence=0.8,
                        ))

                db.commit()

            enriched += 1
            print(f"  ✅ [{idx}/{total}] {r.name} → place_id={place_id}"
                  f"{' (건식)' if dry_run else ''}")
            time.sleep(0.15)  # 네이버 API 부하 방지

        print(f"\n보강 완료 — 검색:{searched} | ID확보:{id_found} | 보강:{enriched} | 스킵:{skipped}")
        return {"searched": searched, "id_found": id_found, "enriched": enriched, "skipped": skipped}

    finally:
        db.close()


# ──────────────────────────────────────────────────────────────
# 2) 네이버 로컬 검색으로 새 식당 발견
# ──────────────────────────────────────────────────────────────
_SEARCH_KEYWORDS = [
    # 음식 종류
    "광주 북구 한식", "광주 북구 중식", "광주 북구 일식", "광주 북구 분식",
    "광주 북구 카페", "광주 북구 양식", "광주 북구 치킨", "광주 북구 피자",
    "광주 북구 족발", "광주 북구 삼겹살", "광주 북구 고기집", "광주 북구 곱창",
    "광주 북구 순대국", "광주 북구 국밥", "광주 북구 냉면", "광주 북구 회",
    "광주 북구 초밥", "광주 북구 라멘", "광주 북구 파스타", "광주 북구 버거",
    "광주 북구 쌀국수", "광주 북구 돈가스", "광주 북구 덮밥", "광주 북구 쌈밥",
    # 술집·주점
    "광주 북구 호프", "광주 북구 술집", "광주 북구 주점", "광주 북구 이자카야",
    "광주 북구 포장마차", "광주 북구 막걸리", "광주 북구 와인바",
    "용봉동 호프", "용봉동 술집", "중흥동 술집",
    # 동네별
    "용봉동 맛집", "중흥동 맛집", "운암동 맛집", "일곡동 맛집", "두암동 맛집",
    "오치동 맛집", "풍향동 맛집", "각화동 맛집", "문화동 맛집",
    "임동 맛집", "신안동 맛집", "우산동 맛집", "동림동 맛집",
]


def collect(
    keywords: Optional[list[str]] = None,
    limit: Optional[int] = None,
    dry_run: bool = False,
    progress_status: Optional[dict] = None,
) -> int:
    """
    네이버 로컬 검색으로 광주 북구 식당을 발견, DB에 저장.
    NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 필요.
    """
    if not settings.NAVER_CLIENT_ID or not settings.NAVER_CLIENT_SECRET:
        print("❌ NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET 이 설정되지 않았습니다.")
        return 0

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # 기존 ID 로딩
    print("🔍 기존 식당 ID 로딩...", end=" ", flush=True)
    existing_ids: set[str] = set(row[0] for row in db.query(Restaurant.id).all())
    existing_naver_ids: set[str] = set(
        row[0] for row in db.query(Restaurant.naver_place_id).filter(
            Restaurant.naver_place_id != "", Restaurant.naver_place_id.isnot(None)
        ).all()
    )
    print(f"{len(existing_ids):,}개 로드 완료")

    kws = keywords or _SEARCH_KEYWORDS
    total_new = 0

    try:
        for kw in kws:
            if limit is not None and total_new >= limit:
                break

            if progress_status is not None:
                progress_status["last"] = f"네이버 수집 중: '{kw}'"
                progress_status["count"] = total_new

            print(f"\n🔎 '{kw}' 검색 중...")
            results = search_naver_restaurants(kw, display=5, max_results=100)

            for item in results:
                if limit is not None and total_new >= limit:
                    break

                lat, lng = item.get("lat", 0.0), item.get("lng", 0.0)
                # 좌표 유효성 + bbox 필터
                if not lat or not lng or not _in_bbox(lat, lng):
                    continue

                place_id = item.get("naver_place_id", "")
                # 네이버 ID 중복 체크
                if place_id and place_id in existing_naver_ids:
                    continue

                # DB ID 생성 (naver_ 접두어)
                rest_id = f"naver_{place_id}" if place_id else f"naver_name_{re.sub(r'[^a-zA-Z0-9가-힣]', '', item['name'])[:20]}"
                if rest_id in existing_ids:
                    continue

                raw_cat = item.get("category_raw", "")
                category = _infer_category(raw_cat)
                defaults = _DEFAULTS.get(category, _DEFAULTS["한식"])
                has_alc = _has_alcohol(raw_cat)
                meal_times = '["저녁","술자리"]' if has_alc else defaults["meal_times"]

                if not dry_run:
                    r = Restaurant(
                        id=rest_id,
                        name=item["name"],
                        category=category,
                        address=item["address"],
                        lat=lat,
                        lng=lng,
                        phone=item.get("phone", ""),
                        hours="",
                        rating=0.0,
                        review_count=0,
                        walk_minutes=0,
                        price=defaults["price"],
                        price_confidence=0.2,
                        crowd_level="보통",
                        tags=json.dumps(["혼밥 가능"] if category in ("분식", "카페") else [], ensure_ascii=False),
                        features="[]",
                        schedule_json="{}",
                        hero_icon=defaults["icon"],
                        hero_hue=defaults["hue"],
                        has_alcohol=has_alc,
                        meal_times=meal_times,
                        open_hour=defaults["open_hour"],
                        close_hour=defaults["close_hour"],
                        naver_place_id=place_id,
                        photo_url="",
                        last_seen_at=datetime.now(timezone.utc).replace(tzinfo=None),
                        is_active=True,
                    )
                    db.add(r)
                    existing_ids.add(rest_id)
                    if place_id:
                        existing_naver_ids.add(place_id)

                total_new += 1
                print(f"  ➕ {item['name']} ({category}) — {item['address']}")

                if not dry_run and total_new % 30 == 0:
                    db.commit()

            time.sleep(0.2)  # 키워드 간 대기

        if not dry_run:
            db.commit()

    finally:
        db.close()

    print(f"\n✅ 네이버 수집 완료: {total_new:,}개 신규 저장")
    return total_new


# ──────────────────────────────────────────────────────────────
# CLI 진입점
# ──────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="네이버 플레이스 데이터 보강 도구")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_enrich = sub.add_parser("enrich", help="기존 식당에 네이버 데이터 보강")
    p_enrich.add_argument("--limit", type=int, default=None, metavar="N")
    p_enrich.add_argument("--dry-run", action="store_true")

    p_collect = sub.add_parser("collect", help="네이버 검색으로 새 식당 발견")
    p_collect.add_argument("--limit", type=int, default=None, metavar="N")
    p_collect.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    if args.cmd == "enrich":
        enrich(limit=args.limit, dry_run=args.dry_run)
    elif args.cmd == "collect":
        collect(limit=args.limit, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
