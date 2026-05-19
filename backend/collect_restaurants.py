#!/usr/bin/env python3
"""
collect_restaurants.py — 카카오 로컬 API로 광주·전남 식당 수집

사용법:
  cd backend
  python collect_restaurants.py [--region gwangju|jeonnam|all] [--limit N] [--dry-run]

필수 환경변수 (backend/.env):
  KAKAO_REST_API_KEY=<카카오 REST API 키>

예시:
  python collect_restaurants.py --region gwangju --limit 200   # 테스트
  python collect_restaurants.py --region all                   # 전체 수집
"""
import sys
import os
import time
import json
import math
import argparse
from typing import Iterator, Optional

# app.* 임포트를 위해 backend 디렉토리를 sys.path 에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import httpx

from app.database import SessionLocal, engine, Base
from app.models import Restaurant
from app.config import get_settings

settings = get_settings()


# ──────────────────────────────────────────────────────────────
# 카테고리 매핑 — 카카오 category_name → 우리 카테고리
# ──────────────────────────────────────────────────────────────
_KEYWORD_MAP: list[tuple[str, str]] = [
    ("초밥", "일식"), ("스시", "일식"), ("라멘", "일식"), ("우동", "일식"),
    ("돈코츠", "일식"), ("이자카야", "일식"), ("오마카세", "일식"),
    ("짜장", "중식"), ("짬뽕", "중식"), ("마라", "중식"), ("탕수육", "중식"),
    ("딤섬", "중식"), ("중화", "중식"),
    ("파스타", "양식"), ("스테이크", "양식"), ("피자", "양식"), ("버거", "양식"),
    ("브런치", "양식"), ("샌드위치", "양식"), ("샐러드", "양식"), ("멕시칸", "양식"),
    ("분식", "분식"), ("떡볶이", "분식"), ("순대", "분식"), ("김밥", "분식"),
    ("라면", "분식"),
    ("카페", "카페"), ("디저트", "카페"), ("베이커리", "카페"), ("커피", "카페"),
    ("빵", "카페"), ("케이크", "카페"),
]

_ALCOHOL_KEYWORDS = {"치킨", "호프", "맥주", "삼겹살", "곱창", "막창", "족발", "보쌈", "갈매기살", "이자카야"}


def _infer_category(kakao_cat: str, group_code: str) -> str:
    """카카오 카테고리 문자열 → 우리 앱 카테고리"""
    for keyword, cat in _KEYWORD_MAP:
        if keyword in kakao_cat:
            return cat
    if group_code == "CE7":
        return "카페"
    return "한식"   # 음식점 기본값


def _has_alcohol(kakao_cat: str) -> bool:
    """카카오 카테고리에서 주류 제공 여부 추정"""
    for kw in _ALCOHOL_KEYWORDS:
        if kw in kakao_cat:
            return True
    return False


# ──────────────────────────────────────────────────────────────
# 카테고리별 기본값
# ──────────────────────────────────────────────────────────────
_DEFAULTS: dict[str, dict] = {
    "한식": {
        "price": 9000,  "icon": "stew",      "hue": 28,
        "tags": ["혼밥 가능"],
        "open_hour": 11, "close_hour": 21,
        "meal_times": '["점심","저녁"]',
    },
    "일식": {
        "price": 11000, "icon": "noodle",    "hue": 200,
        "tags": [],
        "open_hour": 11, "close_hour": 21,
        "meal_times": '["점심","저녁"]',
    },
    "중식": {
        "price": 8500,  "icon": "noodle",    "hue": 10,
        "tags": [],
        "open_hour": 11, "close_hour": 21,
        "meal_times": '["점심","저녁"]',
    },
    "양식": {
        "price": 13000, "icon": "meat",      "hue": 160,
        "tags": [],
        "open_hour": 11, "close_hour": 22,
        "meal_times": '["점심","저녁"]',
    },
    "분식": {
        "price": 5500,  "icon": "kimbap",    "hue": 50,
        "tags": ["혼밥 가능"],
        "open_hour": 10, "close_hour": 21,
        "meal_times": '["아침","점심","저녁"]',
    },
    "카페": {
        "price": 5000,  "icon": "rice-bowl", "hue": 30,
        "tags": [],
        "open_hour": 8,  "close_hour": 22,
        "meal_times": '["아침","점심"]',
    },
}


# ──────────────────────────────────────────────────────────────
# 수집 그리드 정의
# ──────────────────────────────────────────────────────────────
_GRIDS: dict[str, dict] = {
    "gwangju": {
        "lat_range": (35.05, 35.25),
        "lng_range": (126.78, 127.02),
        "step_km":  2.0,
        "radius":   1000,    # 카카오 반경 (m)
        "desc":     "광주광역시",
    },
    "jeonnam": {
        "lat_range": (34.20, 35.10),
        "lng_range": (126.20, 127.60),
        "step_km":  5.0,
        "radius":   2500,
        "desc":     "전라남도",
    },
}

_CATEGORY_CODES = ("FD6", "CE7")   # FD6=음식점, CE7=카페/디저트


def _grid_points(region: str) -> Iterator[tuple[float, float, int]]:
    """(위도, 경도, 반경_m) 격자 포인트 생성"""
    cfg = _GRIDS[region]
    step = cfg["step_km"]
    radius = cfg["radius"]
    lat_min, lat_max = cfg["lat_range"]
    lng_min, lng_max = cfg["lng_range"]

    lat = lat_min
    while lat <= lat_max + 1e-6:
        # 경도 1도 ≈ 111 * cos(lat) km
        lng_step = step / (111.0 * math.cos(math.radians(lat)))
        lat_step = step / 111.0

        lng = lng_min
        while lng <= lng_max + 1e-6:
            yield round(lat, 6), round(lng, 6), radius
            lng += lng_step
        lat += lat_step


def _fetch_page(
    client: httpx.Client,
    lat: float,
    lng: float,
    radius: int,
    code: str,
    page: int,
) -> Optional[dict]:
    """카카오 로컬 카테고리 검색 1페이지"""
    url = "https://dapi.kakao.com/v2/local/search/category.json"
    params = {
        "category_group_code": code,
        "x": lng,
        "y": lat,
        "radius": radius,
        "page": page,
        "size": 15,
        "sort": "distance",
    }
    try:
        resp = client.get(url, params=params, timeout=10.0)
        if resp.status_code == 200:
            return resp.json()
        if resp.status_code == 429:            # Rate limit
            print("  ⚠️  Rate-limit 감지 → 1초 대기")
            time.sleep(1.0)
        else:
            print(f"  HTTP {resp.status_code} at ({lat:.4f},{lng:.4f}) code={code}")
    except Exception as exc:
        print(f"  요청 오류: {exc}")
    return None


# ──────────────────────────────────────────────────────────────
# 메인 수집 함수
# ──────────────────────────────────────────────────────────────
def collect(
    regions: list[str],
    limit: Optional[int] = None,
    dry_run: bool = False,
) -> int:
    if not settings.KAKAO_REST_API_KEY:
        print("❌  KAKAO_REST_API_KEY 가 .env 에 설정되지 않았습니다.")
        print("   backend/.env 에 다음 줄을 추가하세요:")
        print("   KAKAO_REST_API_KEY=<카카오 개발자 콘솔 REST API 키>")
        return 0

    # 테이블 생성 (없으면 자동 생성)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    total_new = 0
    total_skip = 0
    commit_every = 50   # N개마다 커밋

    headers = {"Authorization": f"KakaoAK {settings.KAKAO_REST_API_KEY}"}

    try:
        with httpx.Client(headers=headers) as client:
            for region in regions:
                cfg = _GRIDS[region]
                pts = list(_grid_points(region))
                print(f"\n📍 {cfg['desc']} — 격자 {len(pts)}개 × {len(_CATEGORY_CODES)}코드")

                for pt_idx, (lat, lng, radius) in enumerate(pts):
                    if limit is not None and total_new >= limit:
                        break

                    for code in _CATEGORY_CODES:
                        for page in range(1, 4):    # 최대 3페이지 × 15 = 45개/포인트
                            data = _fetch_page(client, lat, lng, radius, code, page)
                            if not data:
                                break

                            docs = data.get("documents", [])
                            if not docs:
                                break

                            for doc in docs:
                                place_id = str(doc.get("id", "")).strip()
                                if not place_id:
                                    continue

                                rest_id = f"kakao_{place_id}"

                                # 중복 체크
                                if db.query(Restaurant).filter(
                                    Restaurant.id == rest_id
                                ).first():
                                    total_skip += 1
                                    continue

                                # 좌표 파싱
                                try:
                                    r_lat = float(doc["y"])
                                    r_lng = float(doc["x"])
                                except (KeyError, TypeError, ValueError):
                                    continue
                                if r_lat == 0 or r_lng == 0:
                                    continue

                                # 주소 (도로명 → 지번 순)
                                address = (
                                    doc.get("road_address_name") or
                                    doc.get("address_name") or ""
                                ).strip()
                                if not address:
                                    continue

                                kakao_cat = doc.get("category_name", "")
                                category  = _infer_category(kakao_cat, code)
                                defaults  = _DEFAULTS.get(category, _DEFAULTS["한식"])
                                has_alc   = _has_alcohol(kakao_cat)

                                # 주류 취급 식당은 술자리 meal_time 추가
                                if has_alc:
                                    meal_times = '["저녁","술자리"]'
                                    open_hour  = 17
                                    close_hour = 24
                                else:
                                    meal_times = defaults["meal_times"]
                                    open_hour  = defaults["open_hour"]
                                    close_hour = defaults["close_hour"]

                                r = Restaurant(
                                    id=rest_id,
                                    name=doc.get("place_name", "").strip(),
                                    category=category,
                                    address=address,
                                    lat=r_lat,
                                    lng=r_lng,
                                    phone=doc.get("phone", "").strip(),
                                    hours="",
                                    rating=0.0,
                                    review_count=0,
                                    walk_minutes=0,
                                    price=defaults["price"],
                                    price_confidence=0.2,
                                    crowd_level="보통",
                                    tags=json.dumps(defaults["tags"], ensure_ascii=False),
                                    features="[]",
                                    schedule_json="{}",
                                    hero_icon=defaults["icon"],
                                    hero_hue=defaults["hue"],
                                    has_alcohol=has_alc,
                                    meal_times=meal_times,
                                    open_hour=open_hour,
                                    close_hour=close_hour,
                                    naver_place_id="",
                                    photo_url="",
                                )

                                if not dry_run:
                                    db.add(r)

                                total_new += 1

                                # N개마다 중간 커밋
                                if not dry_run and total_new % commit_every == 0:
                                    db.commit()
                                    print(
                                        f"  [{pt_idx+1}/{len(pts)}] ✅ {total_new:,}개 저장 "
                                        f"(중복 건너뜀 {total_skip:,})"
                                    )

                                if limit is not None and total_new >= limit:
                                    break

                            # 마지막 페이지 확인
                            meta = data.get("meta", {})
                            if meta.get("is_end", True):
                                break

                            # API 부하 방지 (50ms)
                            time.sleep(0.05)

                        if limit is not None and total_new >= limit:
                            break

                    if limit is not None and total_new >= limit:
                        break

        # 마지막 커밋
        if not dry_run:
            db.commit()

    except KeyboardInterrupt:
        print("\n⛔  중단됨 — 지금까지 수집된 데이터를 저장합니다...")
        if not dry_run:
            db.commit()
    finally:
        db.close()

    action = "[DRY-RUN] 수집" if dry_run else "저장"
    print(f"\n✅  완료: 신규 {total_new:,}개 {action} · 중복 {total_skip:,}개 건너뜀")
    return total_new


# ──────────────────────────────────────────────────────────────
# CLI 진입점
# ──────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="카카오 로컬 API로 광주·전남 식당 수집",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  python collect_restaurants.py --region gwangju --limit 100 --dry-run
  python collect_restaurants.py --region gwangju
  python collect_restaurants.py --region all
        """,
    )
    parser.add_argument(
        "--region",
        choices=["gwangju", "jeonnam", "all"],
        default="all",
        help="수집 지역 (기본: all)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help="최대 신규 저장 건수 (테스트용)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="DB 저장 없이 수집 건수만 확인",
    )
    args = parser.parse_args()

    regions = ["gwangju", "jeonnam"] if args.region == "all" else [args.region]

    print("한끼로그 식당 수집기")
    print(f"  지역  : {', '.join(r for r in regions)}")
    print(f"  한도  : {args.limit or '무제한'}")
    print(f"  모드  : {'DRY-RUN' if args.dry_run else '실제 저장'}")
    print()

    collect(regions, limit=args.limit, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
