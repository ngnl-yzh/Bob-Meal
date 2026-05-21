# 한끼루트 변경 이력

---

## [1.4.3] — 2026-05-21

### 추천 품질 개선 + 식사 목적 추가

**Backend**
- `schemas.py`: `PurposeEnum`에 `"식사"` 추가 (2인+ 일반 식사)
- `recommender.py`: 4개 버그 수정
  - 예산 필터 완화: 대표 메뉴 중 **1개라도** 예산 내면 포함 (이전: 2개 이상 요구 → 과잉 필터링)
  - 좌표 미수집 식당 필터: `lat/lng = None 또는 0.0`인 식당 거리 계산 전 제외 (대규모 오거리 방지)
  - 결과 상한 확대: `8개` → `20개`
  - `meal_times=[]` 미수집 시 기본값 `["점심","저녁"]` 적용 (빈 배열 예외 처리)
  - `PURPOSE_WEIGHTS`에 `"식사"` 가중치 추가 (가성비·접근성 우선)

**Flutter**
- `screen_input.dart` (worktree + hankkirog): 식사 목적 UX 개선
  - 인원 1명: `혼밥 / 식사 / 친목 / 회식 / 소개팅 / 비즈니스`
  - 인원 2명+: `식사 / 친목 / 회식 / 소개팅 / 비즈니스` (혼밥 자동 숨김)
  - `+` 버튼으로 인원 늘리면 혼밥 → 식사 자동 전환
  - `-` 버튼으로 1인 되면 식사 → 혼밥 자동 전환

---

## [1.4.2] — 2026-05-21

### 네이버 플레이스 배치 보강 파이프라인 구축
**Backend**
- `open_hours_service.py`: 두 함수 추가
  - `fetch_naver_place_full(place_id)` — 영업시간·메뉴·이미지·좌표를 1회 API 호출로 일괄 반환
  - `search_naver_restaurants(query, ...)` — 네이버 로컬 검색으로 지역 식당 목록 수집
- `enrich_naver.py` 신규 생성 (배치 보강 스크립트)
  - `enrich()` — 기존 식당에 naver_place_id 확보 → 영업시간·메뉴·이미지·가격 일괄 주입
  - `collect()` — 26개 키워드로 네이버 로컬 검색, 광주 북구 bbox 필터 후 신규 저장
- `admin.py`: 네이버 보강 UI 섹션 및 API 추가
  - `POST /admin/enrich-naver` (mode: enrich | collect | both)
  - `GET /admin/enrich-naver/status`

> 데이터 파이프라인: Kakao(좌표·목록) → Naver(영업시간·메뉴·이미지) → App

---

## [1.4.0+5] — 2026-05-21

### 서비스 범위 확장: 용봉동 → 광주광역시 북구 + 추천 진단 도구

#### 진단 결과 — "3개만 나오는 이유" 전부 확인
| 원인 | 내용 |
|------|------|
| DB 식당 수 부족 | Kakao 수집 미실행·소량으로 실제 식당 데이터가 거의 없음 |
| 스키마 기본 좌표 버그 | `lat` 기본값이 충장로(동구, 35.1468) → 용봉동과 3.3km 이격 → 거리 필터 전멸 |
| `is_open` 하드 필터 | v1.3.2에서 수정됨 (영업시간 미수집 식당이 닫힘으로 판정되어 탈락) |
| `if lat and lng:` 버그 | lat=0.0 엣지케이스 방어 미흡 |

**Backend**
- `config.py`: 연구 범위 → **광주 북구** (35.13~35.28 / 126.83~127.02), 중심 35.185/126.912
- `schemas.py`: `lat/lng` 기본값 `충장로 좌표` → `None` (recommender 폴백 사용)
- `recommender.py`: `if lat and lng:` → `if lat is not None and lng is not None:`
- `recommend.py`: `GET /api/recommend/debug` 엔드포인트 추가
  - DB 현황, bbox 통계, 거리 필터 시뮬레이션, 식당 샘플 반환
- `collect_restaurants.py`: `bukgu` 그리드 추가 (35.13~35.28 / 126.83~127.02, step 0.8km)
  - 수집 기본 지역: `yongbong` → `bukgu`
- `admin.py`: 배너·탭·셀렉트·JS 필터 모두 북구로 업데이트

**Flutter**
- `config.dart`: `focusLat/Lng` → 북구 중심(35.185/126.912), `focusAreaName` → `광주 북구`
  - `focusRadiusM`: 2000m → 5000m (북구 커버)
- `pubspec.yaml`: `1.3.0+4` → `1.4.0+5`

> **운영 가이드**: 배포 후 관리자 UI에서 "광주 북구" 수집 실행 필요
> `/api/recommend/debug` 로 DB 현황과 필터 탈락 원인 실시간 확인 가능

---

## [1.3.2] — 2026-05-21

### 식당 노출 수 개선 (영업 여부 하드 필터 제거)
**Backend**
- `recommender.py`: `is_open` 하드 필터 제거 — 연구 단계에서는 영업 여부와 무관하게 모든 식당 노출
  - 닫힌 식당도 추천 카드에 포함되며, 카드 내 `is_open` 필드로 영업 여부 구분 표시
- `config.py`: 연구 범위 bbox ±0.004° 확장 (약 440m 추가)
  - 남쪽: 35.162 → 35.158 / 북쪽: 35.190 → 35.194
  - 서쪽: 126.888 → 126.884 / 동쪽: 126.930 → 126.934

> 배경: 영업시간 데이터가 수집되지 않은 식당은 `is_open=false`로 판정되어  
> 실제 존재하는 용봉동 식당들이 결과에서 누락되는 문제 해결

---

## [1.3.1] — 2026-05-21

### 예산 필터 유도리 개선
**Backend**
- `recommender.py`: 가격 오차 허용 범위 `±1,000` → `±2,000`원으로 확대
- 대표 메뉴 2개 이상인 경우 — 그 중 **2개 이상**이 예산 내에 있으면 포함 (기존: 1개라도 있으면)
- 대표 메뉴 1개뿐인 경우 — 그 1개가 예산 내면 포함 (동일)
- 메뉴 미수집 식당 — `restaurant.price` 기준 오차 `±2,000` 적용
- `_effective_price()` / `calc_price_fit()` 내부 오차도 동일하게 `±2,000`으로 통일

> 배경: 용봉동 연구 단계에서 메뉴 데이터 미수집 식당이 많아 필터가 과도하게 작동,  
> 실제 갈 수 있는 식당이 결과에서 빠지는 문제 개선

> 버전 형식: `Major.Minor.Patch+BuildNumber`  
> 앱(Flutter) 변경 시 `+BuildNumber` 증가, 기능 추가 시 `Minor` 증가, 호환성 변경 시 `Major` 증가.  
> 백엔드 변경은 `APP_VERSION`(`config.py`)과 동기화.

---

## [1.3.0+4] — 2026-05-21

### 연구 범위 축소 (광주 용봉동)
**Backend**
- `config.py`: 연구 범위 바운딩박스 상수 추가 (`RESEARCH_LAT/LNG_MIN/MAX/CENTER`)
- `recommender.py`: 추천 API — 용봉동 bbox 내 식당만 조회, GPS 미제공 시 용봉동 중심 폴백
- `restaurants.py`: `/nearby` 엔드포인트에 동일한 bbox 필터 적용
- `admin.py`: 관리자 UI — 연구 범위 배너, 수집 기본값 용봉동, 용봉동 탭 추가
- `collect_restaurants.py`: `yongbong` 격자 추가 (step 0.3km, radius 250m), 수집 기본 지역 변경

**Flutter**
- `config.dart`: `focusLat/Lng/AreaName/RadiusM` 상수 추가
- `screen_input.dart`: GPS 실패·거부 시 용봉동 중심 폴백, "광주 용봉동" 서비스 범위 배지
- `screen_map.dart`: 기본 중심 → 용봉동, 줌 15.0, 반경 2km, 지도 헤더 배지

---

## [1.2.0+3] — 2026-05-20

### 버그 수정 10개 (시니어 리뷰)
**Backend**
- `open_hours_service.py`: 비연속 요일 표시 오류 수정 (`월/수/금` → `"월·수·금"`, `_is_consecutive()` 추가)
- `restaurants.py`: GPS `0.0` 좌표 `is not None` 체크, Naver 영업시간 API TTL (재수집 방지), `_sync_naver_menus` → `PriceData` 테이블 동기화
- `recommender.py`: `rating=0` 신규 식당 중립값 0.6 (3점 상당) 처리
- `main.py`: `SECRET_KEY` 기본값 사용 시 시작 경고
- `users.py`: 로그인 브루트포스 방지 — IP당 분 10회 인메모리 레이트 리미터

**Flutter**
- `models/restaurant.dart`: `RestaurantMapItem` 클래스 추가 (지도 핀 모델 누락)
- `services/api_service.dart`: `getNearbyRestaurants()` + `validateToken()` 추가
- `screens/screen_map.dart`: Geolocator deprecated `desiredAccuracy` → `locationSettings`
- `screens/screen_detail.dart`: 로딩 스피너 → shimmer 스켈레톤으로 교체
- `main.dart`: `_checkAuth()` 로컬 토큰 확인 → 서버 검증(`validateToken`) 적용

---

## [1.1.0+2] — 2026-05-20

### 주요 기능 추가
**Backend**
- `admin.py`: 관리자 웹 UI (`/admin/ui`) — 통계 카드, 수집 제어, 식당 목록·정렬·페이지네이션
- `restaurants.py`: `/api/restaurant/nearby` 엔드포인트 추가 (Haversine 거리 기반)
- `collect_restaurants.py`: 폐업·이전 감지 (`mark_inactive`, `last_seen_at` 기반)
- `open_hours_service.py`: 네이버 플레이스 영업시간·메뉴 자동 수집 (백그라운드)
- 가격 필터 완화 (`±1,000원` 허용), 이동수단별 거리 계산 버그 수정

**Flutter**
- `screen_map.dart`: 지도 탭 추가 — 카테고리 필터, 마커 애니메이션, 선택 카드
- `models/restaurant.dart`: `RestaurantMapItem` 모델
- `services/api_service.dart`: `getNearbyRestaurants()` 추가

---

## [1.0.0+1] — 2026-05-19

### 초기 구조
**Backend (FastAPI)**
- 추천 엔진: 신분·목적·이동수단·시간대·예산 기반 점수 산식
- 식당 상세 API: 메뉴·혼잡도·가격 신뢰도
- JWT 인증: 회원가입·로그인·카카오 소셜 로그인
- 기상청 단기예보 API 연동
- 카카오 로컬 API 기반 식당 수집 스크립트

**Flutter**
- 조건 입력 화면: 신분·목적·시간대·인원·위치·이동수단·예산
- 추천 결과 화면: 카드 리스트, 정렬, 영업 상태 실시간 표시
- 식당 상세 화면: 갤러리·메뉴·혼잡도 차트·가격 신뢰도
- 카카오 로그인, JWT 토큰 관리, 자동 로그아웃

---

> **버전 업데이트 규칙**  
> - 앱 코드(Flutter) 변경 → `pubspec.yaml` `version` 업데이트 + `+BuildNumber` +1  
> - 백엔드 변경 → `backend/app/config.py` `APP_VERSION` 동기화  
> - 변경 내용은 이 파일 최상단에 새 섹션으로 추가  
> - APK 빌드 후 커밋·푸시
