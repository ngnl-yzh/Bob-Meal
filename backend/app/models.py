"""SQLAlchemy ORM 모델"""
from sqlalchemy import (
    Column, Integer, Float, String, Boolean,
    DateTime, ForeignKey, Text, Enum as SAEnum
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from app.database import Base


class CrowdLevel(str, enum.Enum):
    한산 = "한산"
    보통 = "보통"
    혼잡 = "혼잡"


class TransportType(str, enum.Enum):
    도보 = "도보"
    자전거 = "자전거"
    대중교통 = "대중교통"
    자동차 = "자동차"


class Restaurant(Base):
    __tablename__ = "restaurants"

    id = Column(String, primary_key=True, index=True)  # 'cheonggukjang' 형태
    name = Column(String, nullable=False)
    category = Column(String, nullable=False)        # 한식/일식/중식/분식
    address = Column(String, nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)

    # 영업
    hours = Column(String)
    is_open = Column(Boolean, default=True)
    phone = Column(String)
    open_hour = Column(Integer, default=11)   # 영업 시작 시각 (0~23)
    close_hour = Column(Integer, default=21)  # 영업 종료 시각 (0~23)
    has_alcohol = Column(Boolean, default=False)  # 주류 판매 여부
    meal_times = Column(Text, default='["점심","저녁"]')  # JSON: 적합한 식사 시간대

    # 평점/리뷰
    rating = Column(Float, default=0.0)
    review_count = Column(Integer, default=0)

    # 거리 (mock: 도보 기준 분)
    walk_minutes = Column(Integer, default=0)

    # 가격 (1인 기준)
    price = Column(Integer, default=0)
    price_confidence = Column(Float, default=0.5)

    # 혼잡도
    crowd_level = Column(SAEnum(CrowdLevel), default=CrowdLevel.보통)

    # 특징 태그 (JSON 문자열로 저장)
    tags = Column(Text, default="[]")        # ["혼밥 가능", "주차 가능"]
    features = Column(Text, default="[]")    # 상세 특징

    # 사진
    photo_url = Column(String, default="")
    hero_icon = Column(String, default="stew")  # stew/katsu/kimbap/noodle/rice-bowl/meat
    hero_hue = Column(Integer, default=28)

    # 메타
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # 관계
    menus = relationship("Menu", back_populates="restaurant", cascade="all, delete-orphan")
    crowd_by_hour = relationship("CrowdByHour", back_populates="restaurant", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="restaurant", cascade="all, delete-orphan")
    price_data = relationship("PriceData", back_populates="restaurant", cascade="all, delete-orphan")


class Menu(Base):
    __tablename__ = "menus"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    name = Column(String, nullable=False)
    price = Column(Integer, nullable=False)
    photo_url = Column(String, default="")
    icon = Column(String, default="stew")
    hue = Column(Integer, default=28)
    is_representative = Column(Boolean, default=False)

    restaurant = relationship("Restaurant", back_populates="menus")


class CrowdByHour(Base):
    __tablename__ = "crowd_by_hour"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    hour_label = Column(String, nullable=False)   # "11시", "13시", "지금"
    hour_value = Column(Integer, nullable=True)   # 실제 시각 (11, 13 …)
    crowd_ratio = Column(Float, nullable=False)   # 0.0 ~ 1.0

    restaurant = relationship("Restaurant", back_populates="crowd_by_hour")


class PriceData(Base):
    """3단계 폭포수 가격 수집 결과"""
    __tablename__ = "price_data"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    source = Column(String, nullable=False)       # naver_place / naver_blog / category_est / user_input
    price_per_person = Column(Integer, nullable=False)
    confidence = Column(Float, nullable=False)
    collected_at = Column(DateTime(timezone=True), server_default=func.now())
    raw_text = Column(Text, default="")

    restaurant = relationship("Restaurant", back_populates="price_data")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    nickname = Column(String, default="")
    identity = Column(String, default="학생")   # 학생 / 직장인
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    history = relationship("VisitHistory", back_populates="user", cascade="all, delete-orphan")
    favorites = relationship("Favorite", back_populates="user", cascade="all, delete-orphan")


class VisitHistory(Base):
    __tablename__ = "visit_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    visited_at = Column(DateTime(timezone=True), server_default=func.now())
    rating_given = Column(Float, nullable=True)
    memo = Column(Text, default="")

    user = relationship("User", back_populates="history")


class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="favorites")


class Review(Base):
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    author_name = Column(String, default="익명")
    content = Column(Text, nullable=False)
    rating = Column(Float, nullable=False)
    source = Column(String, default="app")   # app / naver / kakao
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    restaurant = relationship("Restaurant", back_populates="reviews")


class CrowdReport(Base):
    """사용자 혼잡도 신고 (기획서 5단계 2단계)"""
    __tablename__ = "crowd_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    restaurant_id = Column(String, ForeignKey("restaurants.id"), nullable=False)
    level = Column(SAEnum(CrowdLevel), nullable=False)
    reported_at = Column(DateTime(timezone=True), server_default=func.now())
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
