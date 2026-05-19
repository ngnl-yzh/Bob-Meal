"""
관리자 엔드포인트 — 식당 수집 등 운영 작업

보안:
  모든 관리자 API는 X-Admin-Key 헤더 검증 필요.
  Railway 환경변수 ADMIN_SECRET_KEY 에 임의 비밀값을 설정하세요.
  미설정 시 관리자 기능 비활성화.
"""
import json
import httpx
from fastapi import APIRouter, BackgroundTasks, HTTPException, Header
from fastapi.responses import JSONResponse
from app.config import get_settings

router = APIRouter(prefix="/admin", tags=["관리자"])
settings = get_settings()

# 수집 상태 추적 (메모리 + DB 영속화)
_collect_status: dict = {"running": False, "last": None, "count": 0}


def _load_collect_status():
    """서버 시작 시 DB에서 마지막 수집 상태 복원. 수집 중이었으면 '중단됨'으로 표시."""
    global _collect_status
    try:
        from app.database import SessionLocal
        from app.models import SystemSetting
        import json
        db = SessionLocal()
        try:
            row = db.query(SystemSetting).filter(SystemSetting.key == "last_collect").first()
            if row:
                saved = json.loads(row.value)
                # 이전에 "수집 중"이었으면 중단된 것
                last = saved.get("status", "")
                if last.startswith("수집 중:"):
                    last = f"⚠️ 중단됨: 배포/재시작으로 중단 (마지막 저장: {saved.get('count', 0):,}개)"
                _collect_status["last"] = last
                _collect_status["count"] = saved.get("count", 0)
        finally:
            db.close()
    except Exception:
        pass


# ─── 관리자 키 검증 ───────────────────────────────────────────────
def _verify_admin(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """
    X-Admin-Key 헤더로 관리자 인증.
    ADMIN_SECRET_KEY 환경변수가 설정돼 있어야 함.
    """
    if not settings.ADMIN_SECRET_KEY:
        raise HTTPException(
            status_code=503,
            detail=(
                "관리자 기능이 비활성화돼 있습니다. "
                "Railway 환경변수에 ADMIN_SECRET_KEY 를 설정하세요."
            ),
        )
    if x_admin_key != settings.ADMIN_SECRET_KEY:
        raise HTTPException(status_code=403, detail="관리자 키가 올바르지 않습니다.")


def _save_collect_status(status: str, count: int):
    """수집 상태를 DB에 저장 (서버 재시작 후에도 유지)"""
    try:
        from app.database import SessionLocal
        from app.models import SystemSetting
        db = SessionLocal()
        try:
            import json
            val = json.dumps({"status": status, "count": count}, ensure_ascii=False)
            row = db.query(SystemSetting).filter(SystemSetting.key == "last_collect").first()
            if row:
                row.value = val
            else:
                db.add(SystemSetting(key="last_collect", value=val))
            db.commit()
        finally:
            db.close()
    except Exception:
        pass  # DB 저장 실패해도 수집은 계속


def _run_collect(region: str, limit: int | None):
    """백그라운드 수집 실행"""
    global _collect_status
    _collect_status["running"] = True
    _collect_status["count"] = 0
    _collect_status["last"] = "수집 시작 중..."
    try:
        import sys, os
        # Railway: 실행 디렉토리가 backend/ 이므로 collect_restaurants.py 가 cwd에 있음
        backend_dir = os.getcwd()  # uvicorn 실행 위치 = backend/
        if backend_dir not in sys.path:
            sys.path.insert(0, backend_dir)

        # 혹시 모듈 캐시에 남아있으면 제거 후 재임포트
        if "collect_restaurants" in sys.modules:
            del sys.modules["collect_restaurants"]

        from collect_restaurants import collect

        regions = ["gwangju", "jeonnam"] if region == "all" else [region]
        count = collect(regions, limit=limit, progress_status=_collect_status)
        _collect_status["count"] = count
        _collect_status["last"] = f"✅ 완료: {count:,}개 수집"
        _save_collect_status(f"✅ 완료: {count:,}개 수집", count)
    except Exception as e:
        import traceback
        msg = f"❌ 오류: {e} | {traceback.format_exc()[-300:]}"
        _collect_status["last"] = msg
        _save_collect_status(msg, _collect_status.get("count", 0))
    finally:
        _collect_status["running"] = False


@router.post("/collect", summary="식당 데이터 수집 시작")
def start_collect(
    background_tasks: BackgroundTasks,
    region: str = "all",   # gwangju / jeonnam / all
    limit: int | None = None,
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
):
    """
    카카오 로컬 API로 식당 데이터를 수집합니다.
    백그라운드로 실행되며 즉시 응답을 반환합니다.

    - **region**: gwangju / jeonnam / all (기본: all)
    - **limit**: 최대 수집 건수 (생략하면 무제한)

    헤더: `X-Admin-Key: {ADMIN_SECRET_KEY 값}`
    """
    _verify_admin(x_admin_key)

    if not settings.KAKAO_REST_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="KAKAO_REST_API_KEY 가 설정되지 않았습니다. Railway 환경변수를 확인하세요."
        )
    if _collect_status["running"]:
        raise HTTPException(status_code=409, detail="이미 수집 중입니다. /admin/collect/status 확인")

    background_tasks.add_task(_run_collect, region, limit)
    return {
        "message": f"수집 시작 ({region})",
        "status_url": "/admin/collect/status",
    }


@router.get("/collect/status", summary="수집 상태 확인")
def collect_status(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """현재 수집 진행 상태를 반환합니다. 서버 재시작 후에도 마지막 결과를 표시합니다."""
    _verify_admin(x_admin_key)
    if not _collect_status["running"] and _collect_status["last"] is None:
        _load_collect_status()
    return _collect_status


@router.get("/stats", summary="DB 통계")
def db_stats(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """식당/유저 수 등 간단한 통계"""
    _verify_admin(x_admin_key)
    from app.database import SessionLocal
    from app.models import Restaurant, User
    db = SessionLocal()
    try:
        return {
            "restaurants": db.query(Restaurant).count(),
            "users": db.query(User).count(),
        }
    finally:
        db.close()


@router.get("/test-kakao", summary="카카오 API 키 테스트")
def test_kakao(x_admin_key: str = Header(..., alias="X-Admin-Key")):
    """
    카카오 로컬 API 키가 올바른지 테스트합니다.
    광주 중심부 1개 좌표로 실제 API 호출 후 전체 응답을 반환합니다.
    """
    _verify_admin(x_admin_key)

    if not settings.KAKAO_REST_API_KEY:
        return {"error": "KAKAO_REST_API_KEY 미설정"}

    url = "https://dapi.kakao.com/v2/local/search/category.json"
    params = {
        "category_group_code": "FD6",
        "x": 126.9162,
        "y": 35.1468,
        "radius": 500,
        "page": 1,
        "size": 3,
    }
    headers = {"Authorization": f"KakaoAK {settings.KAKAO_REST_API_KEY}"}

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(url, params=params, headers=headers)
        return {
            "status_code": resp.status_code,
            "kakao_key_used": settings.KAKAO_REST_API_KEY[:8] + "...",  # 앞 8자리만 표시
            "response_body": resp.json() if resp.headers.get("content-type", "").startswith("application/json") else resp.text[:500],
        }
    except Exception as e:
        return {"error": str(e)}


@router.get("/backup/restaurants", summary="식당 데이터 JSON 백업")
def backup_restaurants(
    x_admin_key: str = Header(..., alias="X-Admin-Key"),
    limit: int = 10000,
):
    """
    식당 데이터를 JSON 형태로 내보냅니다. (데이터 보존용)
    Railway 재배포 전 이 엔드포인트로 백업하세요.

    헤더: `X-Admin-Key: {ADMIN_SECRET_KEY 값}`
    """
    _verify_admin(x_admin_key)
    from app.database import SessionLocal
    from app.models import Restaurant
    db = SessionLocal()
    try:
        rows = db.query(Restaurant).limit(limit).all()
        data = []
        for r in rows:
            data.append({
                "id": r.id,
                "name": r.name,
                "category": r.category,
                "address": r.address,
                "lat": r.lat,
                "lng": r.lng,
                "phone": r.phone or "",
                "hours": r.hours or "",
                "open_hour": r.open_hour,
                "close_hour": r.close_hour,
                "has_alcohol": r.has_alcohol,
                "meal_times": r.meal_times,
                "rating": r.rating,
                "review_count": r.review_count,
                "price": r.price,
                "price_confidence": r.price_confidence,
                "crowd_level": r.crowd_level,
                "tags": r.tags,
                "features": r.features,
                "schedule_json": r.schedule_json,
                "hero_icon": r.hero_icon,
                "hero_hue": r.hero_hue,
                "photo_url": r.photo_url or "",
                "naver_place_id": r.naver_place_id or "",
            })
        return JSONResponse(
            content={"count": len(data), "restaurants": data},
            headers={"Content-Disposition": "attachment; filename=restaurants_backup.json"},
        )
    finally:
        db.close()
