"""
Alembic 환경 설정
- DATABASE_URL 을 app.config 에서 읽어 자동 사용
- 모델은 app.models 에서 자동 감지 (autogenerate 지원)
"""
import sys
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# backend/ 디렉토리를 sys.path 에 추가 (app.* 임포트 허용)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import get_settings
from app.database import Base
import app.models  # noqa: F401 — 모든 모델 로드 (autogenerate 감지용)

settings = get_settings()

# Alembic Config 객체
alembic_cfg = context.config

# alembic.ini 의 sqlalchemy.url 을 환경변수 기반 URL 로 덮어쓰기
alembic_cfg.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# 로그 설정
if alembic_cfg.config_file_name is not None:
    fileConfig(alembic_cfg.config_file_name)

# 마이그레이션 대상 메타데이터
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """오프라인 모드: URL 만 사용 (DB 연결 없음)"""
    url = alembic_cfg.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """온라인 모드: 실제 DB 연결"""
    connectable = engine_from_config(
        alembic_cfg.get_section(alembic_cfg.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,   # 컬럼 타입 변경도 감지
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
