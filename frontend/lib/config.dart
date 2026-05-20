// 앱 환경 설정 — 빌드 타깃에 따라 URL 자동 전환
import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  // ─── 백엔드 URL ─────────────────────────────────────────────
  // [로컬 개발]  flutter run  →  kDebugMode = true  →  _devUrl 사용
  // [앱 배포]   flutter build apk/ios  →  kDebugMode = false  →  _prodUrl 사용
  //
  // Railway 배포 후 _prodUrl 을 실제 URL 로 교체하세요:
  //   예) https://bob-meal-production.up.railway.app
  static const String _devUrl  = 'http://127.0.0.1:8000';
  static const String _prodUrl = 'https://bob-meal-production.up.railway.app';

  static String get baseUrl => kDebugMode ? _devUrl : _prodUrl;

  // ─── 실기기 Wi-Fi 테스트용 ────────────────────────────────────
  // PC IP 확인: ipconfig (Windows) / ifconfig (Mac)
  // 예) static const String _lanUrl = 'http://192.168.0.10:8000';
  // baseUrl 을 _lanUrl 로 임시 교체 후 테스트

  // ─── 연구 범위: 광주광역시 북구 용봉동 ───────────────────────
  // 전남대학교 정문 기준 중심 좌표
  static const double focusLat = 35.1762;
  static const double focusLng = 126.9097;
  static const String focusAreaName = '광주 용봉동';
  static const String focusAreaDetail = '광주광역시 북구 용봉동';
  // 지도 기본 반경 (m) — 연구 단계는 2km로 축소
  static const int focusRadiusM = 2000;
}
