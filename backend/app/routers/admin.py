"""
관리자 엔드포인트 — 식당 수집 등 운영 작업
"""
from fastapi import APIRouter, BackgroundTasks, HTTPException
from app.config import get_settings

router = APIRouter(prefix="/admin", tags=["관리자"])
settings = get_settings()

# 수집 상태 추적 (메모리 내)
_collect_status: dict = {"running": False, "last": None, "count": 0}


def _run_collect(region: str, limit: int | None):
    """백그라운드 수집 실행"""
    global _collect_status
    _collect_status["running"] = True
    try:
        import sys, os
        # collect_restaurants.py 가 backend/ 루트에 있음
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        from collect_restaurants import collect

        regions = ["gwangju", "jeonnam"] if region == "all" else [region]
        count = collect(regions, limit=limit)
        _collect_status["count"] = count
        _collect_status["last"] = f"완료: {count}개 수집"
    except Exception as e:
        _collect_status["last"] = f"오류: {e}"
    finally:
        _collect_status["running"] = False


@router.post("/collect", summary="식당 데이터 수집 시작")
def start_collect(
    background_tasks: BackgroundTasks,
    region: str = "all",   # gwangju / jeonnam / all
    limit: int | None = None,
):
    """
    카카오 로컬 API로 식당 데이터를 수집합니다.
    백그라운드로 실행되며 즉시 응답을 반환합니다.

    - **region**: gwangju / jeonnam / all (기본: all)
    - **limit**: 최대 수집 건수 (생략하면 무제한)
    """
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
def collect_status():
    """현재 수집 진행 상태를 반환합니다."""
    return _collect_status


@router.get("/stats", summary="DB 통계")
def db_stats():
    """식당/유저 수 등 간단한 통계"""
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
