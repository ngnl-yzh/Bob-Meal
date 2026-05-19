"""
혼잡도 예측 서비스 — 기획서 5장
1단계: 통계 기반 예측 (Google Popular Times mock)
2단계: 사용자 신고
"""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session

from app.models import Restaurant, CrowdReport, CrowdByHour
from app.schemas import CrowdLevelEnum, CrowdReportIn


# ─── 혼잡도 비율 → 레벨 변환 ──────────────────────────────────
def ratio_to_level(ratio: float) -> CrowdLevelEnum:
    if ratio < 0.45:
        return CrowdLevelEnum.한산
    elif ratio < 0.75:
        return CrowdLevelEnum.보통
    else:
        return CrowdLevelEnum.혼잡


# ─── 현재 시간 혼잡도 예측 ────────────────────────────────────
def get_current_crowd(db: Session, restaurant: Restaurant) -> dict:
    """
    현재 시각 기준 혼잡도 반환
    우선순위: 최근 30분 사용자 신고 → 시간대 통계
    """
    # 1) 최근 30분 사용자 신고 확인
    cutoff = datetime.utcnow() - timedelta(minutes=30)
    recent_reports = (
        db.query(CrowdReport)
        .filter(
            CrowdReport.restaurant_id == restaurant.id,
            CrowdReport.reported_at >= cutoff,
        )
        .all()
    )

    if recent_reports:
        # 최신 신고를 우선
        latest = max(recent_reports, key=lambda r: r.reported_at)
        delta = datetime.utcnow() - latest.reported_at
        minutes_ago = int(delta.total_seconds() / 60)
        return {
            "level": latest.level,
            "source": "user_report",
            "message": f"{minutes_ago}분 전 사용자 신고",
            "is_accurate": True,
        }

    # 2) 통계 기반: 현재 시각에 가장 가까운 crowd_by_hour 항목
    now_hour = datetime.now().hour
    crowd_rows = (
        db.query(CrowdByHour)
        .filter(CrowdByHour.restaurant_id == restaurant.id)
        .all()
    )

    # "지금" 항목 우선
    for row in crowd_rows:
        if row.hour_label == "지금":
            level = ratio_to_level(row.crowd_ratio)
            return {
                "level": level,
                "source": "statistical",
                "message": f"이 시간대 보통 {level.value}해요 (통계 기반)",
                "is_accurate": False,
            }

    # hour_value 가장 가까운 것
    best_row = min(
        [r for r in crowd_rows if r.hour_value is not None],
        key=lambda r: abs(r.hour_value - now_hour),
        default=None,
    )
    if best_row:
        level = ratio_to_level(best_row.crowd_ratio)
        return {
            "level": level,
            "source": "statistical",
            "message": f"이 시간대 보통 {level.value}해요 (통계 기반)",
            "is_accurate": False,
        }

    # fallback
    return {
        "level": restaurant.crowd_level,
        "source": "default",
        "message": "혼잡도 정보 없음",
        "is_accurate": False,
    }


# ─── 사용자 혼잡도 신고 ───────────────────────────────────────
def submit_crowd_report(
    db: Session, report_in: CrowdReportIn, user_id: Optional[int] = None
) -> CrowdReport:
    report = CrowdReport(
        restaurant_id=report_in.restaurant_id,
        level=report_in.level,
        user_id=user_id,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report
