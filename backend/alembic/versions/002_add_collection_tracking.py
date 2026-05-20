"""add collection tracking columns (last_seen_at, is_active)

Revision ID: 002
Revises: 001
Create Date: 2026-05-20

주기적 재수집 시 폐업·이전 식당을 감지하기 위한 컬럼 추가.
  - last_seen_at : 마지막으로 카카오 API에서 확인된 시각 (NULL = 아직 재수집 미실행)
  - is_active    : False = 폐업·이전 추정 (추천 결과에서 제외)

기존 DB에 이미 컬럼이 있으면 건너뜀 (멱등성 보장).
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    # restaurants 테이블이 존재하지 않으면 건너뜀 (001 이 처리)
    if "restaurants" not in inspector.get_table_names():
        return

    existing_cols = {c["name"] for c in inspector.get_columns("restaurants")}

    if "last_seen_at" not in existing_cols:
        op.add_column(
            "restaurants",
            sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        )

    if "is_active" not in existing_cols:
        op.add_column(
            "restaurants",
            sa.Column(
                "is_active",
                sa.Boolean(),
                nullable=False,
                server_default="true",
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "restaurants" not in inspector.get_table_names():
        return
    existing_cols = {c["name"] for c in inspector.get_columns("restaurants")}
    if "is_active" in existing_cols:
        op.drop_column("restaurants", "is_active")
    if "last_seen_at" in existing_cols:
        op.drop_column("restaurants", "last_seen_at")
