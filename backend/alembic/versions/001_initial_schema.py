"""initial schema

Revision ID: 001
Revises:
Create Date: 2025-05-19

이 마이그레이션은 초기 스키마를 생성합니다.
Railway PostgreSQL 에 이미 create_all() 로 테이블이 있다면:
  alembic stamp 001
  (마이그레이션 실행 없이 현재 상태를 001 로 마킹)

신규 배포 시에는 자동으로 실행됩니다.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 이미 테이블이 존재하면 건너뜀 (create_all 과 공존)
    bind = op.get_bind()
    inspector = inspect(bind)
    existing = set(inspector.get_table_names())

    if "restaurants" not in existing:
        op.create_table(
            "restaurants",
            sa.Column("id", sa.String(), nullable=False),
            sa.Column("name", sa.String(), nullable=False),
            sa.Column("category", sa.String(), nullable=False),
            sa.Column("address", sa.String(), nullable=False),
            sa.Column("lat", sa.Float(), nullable=False),
            sa.Column("lng", sa.Float(), nullable=False),
            sa.Column("hours", sa.String(), nullable=True),
            sa.Column("is_open", sa.Boolean(), nullable=True),
            sa.Column("phone", sa.String(), nullable=True),
            sa.Column("open_hour", sa.Integer(), nullable=True),
            sa.Column("close_hour", sa.Integer(), nullable=True),
            sa.Column("has_alcohol", sa.Boolean(), nullable=True),
            sa.Column("meal_times", sa.Text(), nullable=True),
            sa.Column("rating", sa.Float(), nullable=True),
            sa.Column("review_count", sa.Integer(), nullable=True),
            sa.Column("walk_minutes", sa.Integer(), nullable=True),
            sa.Column("price", sa.Integer(), nullable=True),
            sa.Column("price_confidence", sa.Float(), nullable=True),
            sa.Column(
                "crowd_level",
                sa.Enum("한산", "보통", "혼잡", name="crowdlevel"),
                nullable=True,
            ),
            sa.Column("tags", sa.Text(), nullable=True),
            sa.Column("features", sa.Text(), nullable=True),
            sa.Column("schedule_json", sa.Text(), nullable=True),
            sa.Column("naver_place_id", sa.String(), nullable=True),
            sa.Column("photo_url", sa.String(), nullable=True),
            sa.Column("hero_icon", sa.String(), nullable=True),
            sa.Column("hero_hue", sa.Integer(), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
            ),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_restaurants_id", "restaurants", ["id"], unique=False)

    if "users" not in existing:
        op.create_table(
            "users",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("email", sa.String(), nullable=True),
            sa.Column("hashed_password", sa.String(), nullable=True),
            sa.Column("kakao_id", sa.String(), nullable=True),
            sa.Column("nickname", sa.String(), nullable=True),
            sa.Column("identity", sa.String(), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
            ),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_users_email", "users", ["email"], unique=True)
        op.create_index("ix_users_kakao_id", "users", ["kakao_id"], unique=True)

    for tbl in ["menus", "crowd_by_hour", "price_data",
                "visit_history", "favorites", "reviews", "crowd_reports"]:
        if tbl not in existing:
            # 나머지 테이블은 create_all 이 생성하므로 여기서는 skip
            # (미래 마이그레이션을 위한 placeholder)
            pass


def downgrade() -> None:
    # 롤백: 주의해서 사용
    for tbl in ["crowd_reports", "reviews", "favorites", "visit_history",
                "price_data", "crowd_by_hour", "menus", "users", "restaurants"]:
        op.drop_table(tbl)
