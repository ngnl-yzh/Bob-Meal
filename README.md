# 식사 장소 추천 앱

대학생·직장인 맞춤형 식당 추천 모바일 앱 · Phase 1

## 구조

```
식당추천앱/
├── backend/          FastAPI 백엔드
│   ├── app/
│   │   ├── main.py           진입점
│   │   ├── config.py         환경 설정
│   │   ├── database.py       SQLAlchemy 연결
│   │   ├── models.py         DB 모델
│   │   ├── schemas.py        Pydantic 스키마
│   │   ├── mock_data.py      목업 데이터 (8개 식당)
│   │   ├── routers/          API 엔드포인트
│   │   │   ├── recommend.py  POST /api/recommend ★ 핵심
│   │   │   ├── restaurants.py GET /api/restaurant/{id}
│   │   │   ├── users.py      회원가입·로그인·찜·기록
│   │   │   └── weather.py    GET /api/weather
│   │   └── services/
│   │       ├── recommender.py  추천 점수 알고리즘
│   │       ├── price_service.py 3단계 폭포수 가격
│   │       ├── crowd_service.py 혼잡도 예측
│   │       └── auth_service.py  JWT 인증
│   ├── requirements.txt
│   ├── .env.example
│   └── run.bat               서버 실행 스크립트
└── frontend/         Flutter 앱
    ├── pubspec.yaml
    └── lib/
        ├── main.dart           진입점 + 화면 전환
        ├── theme.dart          디자인 시스템 (브랜드 컬러)
        ├── models/             데이터 모델
        │   ├── restaurant.dart
        │   └── conditions.dart
        ├── services/
        │   └── api_service.dart HTTP 클라이언트
        ├── widgets/            공통 UI 컴포넌트
        │   ├── chip_widget.dart
        │   ├── crowd_badge.dart
        │   ├── bottom_nav.dart
        │   ├── smart_photo.dart
        │   └── restaurant_card.dart
        └── screens/            3개 화면
            ├── screen_input.dart   ① 조건 입력
            ├── screen_results.dart ② 추천 결과
            └── screen_detail.dart  ③ 식당 상세
```

## 백엔드 실행

```bash
cd backend
# Windows
run.bat

# 또는 직접 실행
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

- 서버 주소: http://127.0.0.1:8000
- API 문서 (Swagger): http://127.0.0.1:8000/docs

## Flutter 앱 실행

```bash
cd frontend
flutter pub get
flutter run
```

백엔드 서버를 먼저 실행한 후 앱을 실행하세요.
실제 기기에서 테스트할 경우 `api_service.dart`의 `_baseUrl`을 PC IP로 변경하세요.

## 주요 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | /api/recommend | 조건 → 식당 추천 목록 |
| GET | /api/restaurant/{id} | 식당 상세 |
| GET | /api/restaurant/{id}/crowd | 현재 혼잡도 |
| POST | /api/restaurant/crowd-report | 혼잡도 신고 |
| POST | /api/user/register | 회원가입 |
| POST | /api/user/login | 로그인 |
| GET | /api/user/favorites | 찜 목록 |
| GET | /api/weather | 현재 날씨 |

## Phase 2 — 추가 예정 API

`.env` 파일에 키 설정 후 자동 활성화:

```env
NAVER_CLIENT_ID=...
NAVER_CLIENT_SECRET=...
KAKAO_REST_API_KEY=...
GOOGLE_MAPS_API_KEY=...
KMA_SERVICE_KEY=...
```

| API | 용도 |
|-----|------|
| 네이버 플레이스 | 가격 정보 1순위 수집 |
| 네이버 블로그 | 가격 정보 2순위 수집 |
| 카카오 모빌리티 | 실제 경로 기반 이동 시간 |
| Google Popular Times | 혼잡도 통계 |
| 기상청 단기예보 | 날씨 기반 이동수단 권고 |
