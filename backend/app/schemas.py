"""Pydantic 스키마"""
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional, List
from enum import Enum


# ─── 열거형 ───────────────────────────────────────────────────
class IdentityEnum(str, Enum):
    학생 = "학생"
    직장인 = "직장인"

class PurposeEnum(str, Enum):
    혼밥 = "혼밥"
    친목 = "친목"
    회식 = "회식"
    소개팅 = "소개팅"
    비즈니스 = "비즈니스"

class MealTimeEnum(str, Enum):
    아침 = "아침"
    점심 = "점심"
    저녁 = "저녁"
    술자리 = "술자리"

class TransportEnum(str, Enum):
    도보 = "도보"
    자전거 = "자전거"
    대중교통 = "대중교통"
    자동차 = "자동차"

class LocationTypeEnum(str, Enum):
    gps = "gps"
    search = "search"
    area = "area"

class PriceModeEnum(str, Enum):
    default = "default"
    custom = "custom"

class CrowdLevelEnum(str, Enum):
    한산 = "한산"
    보통 = "보통"
    혼잡 = "혼잡"

class SortEnum(str, Enum):
    recommended = "추천순"
    distance = "거리순"
    price = "가격순"


# ─── 추천 요청 ────────────────────────────────────────────────
class RecommendRequest(BaseModel):
    identity: IdentityEnum = IdentityEnum.학생
    purpose: PurposeEnum = PurposeEnum.혼밥
    meal_time: MealTimeEnum = MealTimeEnum.점심   # 아침/점심/저녁/술자리
    party_size: int = 1
    location_type: LocationTypeEnum = LocationTypeEnum.gps
    lat: Optional[float] = None   # None이면 recommender가 RESEARCH_LAT_CENTER로 폴백
    lng: Optional[float] = None
    transport: TransportEnum = TransportEnum.도보
    available_minutes: int = 60       # 30 / 60 / 90 / 120
    price_mode: PriceModeEnum = PriceModeEnum.default
    price_max: Optional[int] = None   # custom 시 사용
    sort: SortEnum = SortEnum.recommended
    target_datetime: Optional[str] = None  # "YYYY-MM-DDTHH:MM" 형식, 없으면 현재 시각

    @field_validator("party_size")
    @classmethod
    def check_party_size(cls, v):
        if v < 1 or v > 20:
            raise ValueError("인원은 1~20명 사이여야 합니다")
        return v

    @field_validator("available_minutes")
    @classmethod
    def check_minutes(cls, v):
        if v < 30 or v > 120:
            raise ValueError("가용 시간은 30~120분 사이여야 합니다")
        return v


# ─── 메뉴 ─────────────────────────────────────────────────────
class MenuOut(BaseModel):
    name: str
    price: int
    photo_url: str
    icon: str
    hue: int
    is_representative: bool

    class Config:
        from_attributes = True


# ─── 혼잡도 시간대 ────────────────────────────────────────────
class CrowdByHourOut(BaseModel):
    hour_label: str
    crowd_ratio: float
    is_now: bool = False

    class Config:
        from_attributes = True


# ─── 가격 정보 ────────────────────────────────────────────────
class PriceInfoOut(BaseModel):
    price_per_person: int
    confidence: float
    display_mode: str   # "exact" / "range" / "unknown"
    display_text: str   # "약 12,000원" / "10,000~15,000원 추정" / "정보 없음"
    source: str


# ─── 식당 (리스트 카드) ────────────────────────────────────────
class RestaurantCardOut(BaseModel):
    id: str
    name: str
    category: str
    is_open: bool = True            # KST 기준 실시간 영업 여부
    today_hours: str = ""           # "11:00 ~ 21:00" or "오늘 휴무"
    closes_soon: bool = False       # 1시간 이내 마감
    crowd_level: CrowdLevelEnum
    rating: float
    review_count: int
    walk_minutes: int
    price: int
    price_confidence: float
    tags: List[str]
    photo_url: str
    hero_icon: str
    hero_hue: int
    score: Optional[float] = None   # 추천 점수

    class Config:
        from_attributes = True


# ─── 지도용 (좌표 포함 간략 정보) ────────────────────────────
class RestaurantMapOut(BaseModel):
    id: str
    name: str
    category: str
    lat: float
    lng: float
    is_open: bool = True
    crowd_level: CrowdLevelEnum
    price: int
    rating: float
    photo_url: str
    hero_icon: str
    hero_hue: int
    tags: List[str]

    class Config:
        from_attributes = True


# ─── 식당 상세 ────────────────────────────────────────────────
class RestaurantDetailOut(BaseModel):
    id: str
    name: str
    category: str
    address: str
    lat: float
    lng: float
    hours: str                      # 한 줄 요약 (예: "월~금 11:00~21:00 · 일 휴무")
    is_open: bool
    today_hours: str = ""           # 오늘 영업시간 ("11:00 ~ 21:00" or "오늘 휴무")
    closes_soon: bool = False
    break_now: bool = False         # 현재 브레이크타임 여부
    hours_note: str = ""            # "매주 일요일 정기휴무" 등
    phone: Optional[str]
    rating: float
    review_count: int
    walk_minutes: int
    price: int
    price_confidence: float
    crowd_level: CrowdLevelEnum
    tags: List[str]
    features: List[str]
    photo_url: str
    hero_icon: str
    hero_hue: int
    menus: List[MenuOut]
    crowd_by_hour: List[CrowdByHourOut]
    price_info: Optional[PriceInfoOut] = None
    naver_place_id: str = ""

    class Config:
        from_attributes = True


# ─── 추천 응답 ────────────────────────────────────────────────
class RecommendResponse(BaseModel):
    total: int
    radius_meters: int
    budget_cap: int
    summary: str
    results: List[RestaurantCardOut]


# ─── 리뷰 ─────────────────────────────────────────────────────
class ReviewOut(BaseModel):
    id: int
    author_name: str
    content: str
    rating: float
    source: str
    created_at: str

    class Config:
        from_attributes = True


# ─── 혼잡도 신고 ──────────────────────────────────────────────
class CrowdReportIn(BaseModel):
    restaurant_id: str
    level: CrowdLevelEnum


# ─── 사용자 ───────────────────────────────────────────────────
class UserRegisterIn(BaseModel):
    email: EmailStr
    password: str
    nickname: str
    identity: IdentityEnum = IdentityEnum.학생

class UserLoginIn(BaseModel):
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: int
    email: str
    nickname: str
    identity: str
    is_active: bool

    class Config:
        from_attributes = True

class KakaoLoginIn(BaseModel):
    kakao_access_token: str

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ─── 날씨 ─────────────────────────────────────────────────────
class WeatherOut(BaseModel):
    condition: str      # "맑음" / "흐림" / "비" / "눈"
    temperature: float
    is_outdoor_ok: bool
    advice: str
    source: str = "기상청"   # 저작자 표시 의무 (공공누리 1유형)
