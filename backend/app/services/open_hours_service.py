"""
영업시간 서비스 — KST 기준 실시간 영업 여부 판단 + 네이버 플레이스 연동

schedule_json 형식 (Text 컬럼에 저장):
{
  "mon": "11:00-21:00",   ← HH:MM-HH:MM  또는  null (휴무)
  "tue": "11:00-21:00",
  "wed": "11:00-21:00",
  "thu": "11:00-21:00",
  "fri": "11:00-21:00",
  "sat": "11:00-20:00",
  "sun": null,
  "break": "15:00-17:00", ← 브레이크타임 (없으면 null)
  "note": "매주 일요일 정기휴무"
}
"""
import json
import re
from datetime import datetime, time as dt_time
from zoneinfo import ZoneInfo
from typing import Optional

import httpx

from app.config import get_settings

settings = get_settings()
KST = ZoneInfo("Asia/Seoul")

_DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
_DAY_KO = {
    "mon": "월", "tue": "화", "wed": "수",
    "thu": "목", "fri": "금", "sat": "토", "sun": "일",
}


# ─── KST 현재 시각 ────────────────────────────────────────────────
def now_kst() -> datetime:
    return datetime.now(KST)


# ─── 시간 문자열 파싱 ────────────────────────────────────────────
def _parse_hhmm(s: str) -> dt_time:
    """'HH:MM' → datetime.time. 24:00 은 23:59 로 처리."""
    h, m = map(int, s.strip().split(":"))
    if h >= 24:
        h, m = 23, 59
    return dt_time(h, m)


def _parse_range(range_str: str) -> tuple[dt_time, dt_time]:
    """'11:00-21:00' → (open_time, close_time)"""
    open_s, close_s = range_str.split("-")
    return _parse_hhmm(open_s), _parse_hhmm(close_s)


# ─── 영업 여부 판단 ───────────────────────────────────────────────
def get_open_status(schedule_json_str: str, target_dt=None) -> dict:
    """
    지정된 시각(또는 현재 KST) 기준으로 영업 상태를 반환.

    Args:
        schedule_json_str: schedule_json 문자열
        target_dt: 기준 datetime (없으면 현재 KST)
    Returns:
        is_open: bool
        today_hours: str  예) "11:00 ~ 21:00"  or  "오늘 휴무"
        closes_soon: bool  (1시간 이내 마감)
        break_now: bool
        note: str         정기휴무 안내
    """
    try:
        schedule = json.loads(schedule_json_str or "{}")
    except Exception:
        return _default_status()

    if not schedule:
        return _default_status()

    now = target_dt if target_dt is not None else now_kst()
    today_key = _DAY_KEYS[now.weekday()]   # 0=mon … 6=sun
    cur_time = now.time().replace(second=0, microsecond=0)

    day_val = schedule.get(today_key)
    note = schedule.get("note", "")

    # ① 오늘 휴무
    if day_val is None:
        return {
            "is_open": False,
            "today_hours": "오늘 휴무",
            "closes_soon": False,
            "break_now": False,
            "note": note,
        }

    open_t, close_t = _parse_range(day_val)
    today_label = f"{open_t.strftime('%H:%M')} ~ {close_t.strftime('%H:%M')}"

    # ② 영업 시간 전/후
    if not (open_t <= cur_time < close_t):
        return {
            "is_open": False,
            "today_hours": today_label,
            "closes_soon": False,
            "break_now": False,
            "note": note,
        }

    # ③ 브레이크 타임 확인
    break_val = schedule.get("break")
    in_break = False
    if break_val:
        try:
            b_open, b_close = _parse_range(break_val)
            if b_open <= cur_time < b_close:
                in_break = True
        except Exception:
            pass

    # ④ 1시간 이내 마감 여부
    from datetime import timedelta
    closes_soon = (
        not in_break
        and (datetime.combine(now.date(), close_t) - now.replace(tzinfo=None)).total_seconds() < 3600
    )

    return {
        "is_open": not in_break,
        "today_hours": today_label,
        "closes_soon": closes_soon,
        "break_now": in_break,
        "note": note,
    }


def _default_status() -> dict:
    return {
        "is_open": True,
        "today_hours": "영업시간 정보 없음",
        "closes_soon": False,
        "break_now": False,
        "note": "",
    }


# ─── 주간 스케줄 → 표시용 문자열 ─────────────────────────────────
def build_hours_display(schedule_json_str: str) -> str:
    """
    schedule_json → 한 줄 요약 문자열
    예) "월~금 11:00~21:00 · 토 11:00~20:00 · 일 휴무"
    """
    try:
        schedule = json.loads(schedule_json_str or "{}")
    except Exception:
        return ""

    if not schedule:
        return ""

    # 같은 시간대끼리 묶기
    groups: dict[str, list[str]] = {}
    for key in _DAY_KEYS:
        val = schedule.get(key)
        label = val if val else "휴무"
        groups.setdefault(label, []).append(_DAY_KO[key])

    parts = []
    for time_range, days in groups.items():
        day_str = "·".join(days) if len(days) == 1 else f"{days[0]}~{days[-1]}"
        if time_range == "휴무":
            parts.append(f"{day_str} 휴무")
        else:
            open_s, close_s = time_range.split("-")
            parts.append(f"{day_str} {open_s}~{close_s}")

    break_val = schedule.get("break")
    if break_val:
        open_s, close_s = break_val.split("-")
        parts.append(f"브레이크 {open_s}~{close_s}")

    return " · ".join(parts)


# ─── 네이버 지역 검색 — 플레이스 ID 조회 ────────────────────────
def search_naver_place_id(restaurant_name: str, address: str = "") -> Optional[str]:
    """
    네이버 지역 검색 API → 플레이스 ID 반환.
    NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 필요.
    """
    if not settings.NAVER_CLIENT_ID or not settings.NAVER_CLIENT_SECRET:
        return None

    query = f"{restaurant_name} {address}".strip()
    url = "https://openapi.naver.com/v1/search/local.json"
    headers = {
        "X-Naver-Client-Id": settings.NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": settings.NAVER_CLIENT_SECRET,
    }
    params = {"query": query, "display": 1, "sort": "comment"}

    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url, headers=headers, params=params)
        if resp.status_code != 200:
            return None
        items = resp.json().get("items", [])
        if not items:
            return None

        link = items[0].get("link", "")
        # "https://map.naver.com/v5/entry/place/12345678" 형태에서 ID 추출
        m = re.search(r"place/(\d+)", link)
        return m.group(1) if m else None
    except Exception:
        return None


# ─── 네이버 플레이스 영업시간 파싱 ───────────────────────────────
def fetch_naver_place_schedule(place_id: str) -> Optional[dict]:
    """
    네이버 플레이스 내부 API에서 영업시간 정보 파싱.
    결과를 schedule_json 형식의 dict 로 반환.
    """
    if not place_id:
        return None

    try:
        url = f"https://map.naver.com/v5/api/sites/summary/{place_id}?lang=ko"
        with httpx.Client(
            timeout=5.0,
            headers={
                "referer": "https://map.naver.com/",
                "user-agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 Chrome/124 Safari/537.36"
                ),
            },
        ) as client:
            resp = client.get(url)

        if resp.status_code != 200:
            return None

        data = resp.json()
        biz_hour = data.get("bizHour", {})
        if not biz_hour:
            return None

        return _parse_naver_biz_hour(biz_hour)
    except Exception:
        return None


def _parse_naver_biz_hour(biz_hour: dict) -> dict:
    """네이버 bizHour 구조 → schedule_json 형식 변환"""
    schedule: dict = {k: None for k in _DAY_KEYS}

    periods = biz_hour.get("periods", []) or biz_hour.get("businessHours", [])
    for period in periods:
        raw_from = str(period.get("from", "") or period.get("open", ""))
        raw_to = str(period.get("to", "") or period.get("close", ""))
        if len(raw_from) == 4:
            raw_from = f"{raw_from[:2]}:{raw_from[2:]}"
        if len(raw_to) == 4:
            raw_to = f"{raw_to[:2]}:{raw_to[2:]}"

        # 적용 요일
        holiday_type = period.get("holidayType", "")
        if holiday_type in ("WEEKDAY", "MON_FRI"):
            days = ["mon", "tue", "wed", "thu", "fri"]
        elif holiday_type in ("WEEKEND", "SAT_SUN"):
            days = ["sat", "sun"]
        elif holiday_type == "SAT":
            days = ["sat"]
        elif holiday_type == "SUN":
            days = ["sun"]
        else:
            days = _DAY_KEYS  # 전체

        for d in days:
            schedule[d] = f"{raw_from}-{raw_to}"

    # 휴무일
    for closed in biz_hour.get("closingDays", []):
        dow = closed.get("dayOfWeek", "").lower()[:3]
        if dow in schedule:
            schedule[dow] = None

    # 브레이크타임
    break_time = biz_hour.get("breakTime", {})
    if break_time:
        b_from = str(break_time.get("from", ""))
        b_to = str(break_time.get("to", ""))
        if len(b_from) == 4:
            b_from = f"{b_from[:2]}:{b_from[2:]}"
        if len(b_to) == 4:
            b_to = f"{b_to[:2]}:{b_to[2:]}"
        if b_from and b_to:
            schedule["break"] = f"{b_from}-{b_to}"

    # 정기휴무 안내
    note_parts = []
    for closed in biz_hour.get("closingDays", []):
        dow = closed.get("dayOfWeek", "")
        dow_ko = {"MON": "월", "TUE": "화", "WED": "수", "THU": "목",
                  "FRI": "금", "SAT": "토", "SUN": "일"}.get(dow, dow)
        if dow_ko:
            note_parts.append(f"매주 {dow_ko}요일 정기휴무")
    if note_parts:
        schedule["note"] = " · ".join(note_parts)

    return schedule
