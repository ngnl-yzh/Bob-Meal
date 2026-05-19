"""
mock_data.py — 예시 데이터 없음
실제 식당 데이터는 collect_restaurants.py 로 수집합니다.
"""

# 기존 예시 데이터의 ID 목록 (DB에 남아있으면 자동 삭제)
_LEGACY_MOCK_IDS = [
    "cheonggukjang", "donkatsu", "kimbap", "sundubu",
    "jjajang", "udon", "gukbap", "bibimbap",
]


def seed_database(db):
    """예시 데이터가 DB에 남아 있으면 제거합니다."""
    from app.models import Restaurant

    deleted = (
        db.query(Restaurant)
        .filter(Restaurant.id.in_(_LEGACY_MOCK_IDS))
        .delete(synchronize_session=False)
    )
    if deleted:
        db.commit()
        print(f"🗑️  예시 식당 {deleted}개 삭제 완료")
