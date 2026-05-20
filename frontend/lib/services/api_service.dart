// HTTP 클라이언트 — 백엔드 FastAPI 와 통신
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/conditions.dart';
import '../config.dart';

class ApiService {
  // debug 빌드 → localhost, release 빌드 → Railway URL (config.dart 에서 관리)
  static String get _baseUrl => AppConfig.baseUrl;

  static ApiService? _instance;
  ApiService._();
  static ApiService get instance => _instance ??= ApiService._();

  // ─── 토큰 관리 ─────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── 공통 요청 래퍼 (타임아웃 + 네트워크 오류 처리) ────────
  static const _timeout = Duration(seconds: 15);

  Future<http.Response> _get(String path, {bool auth = false, Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    try {
      final res = await http.get(uri, headers: await _headers(auth: auth)).timeout(_timeout);
      return res;
    } on TimeoutException {
      throw ApiException('서버 응답이 너무 느려요. 잠시 후 다시 시도해주세요.', 408);
    } on SocketException {
      throw ApiException('인터넷 연결을 확인해주세요.', 0);
    }
  }

  Future<http.Response> _post(String path, {bool auth = false, Object? body}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return res;
    } on TimeoutException {
      throw ApiException('서버 응답이 너무 느려요. 잠시 후 다시 시도해주세요.', 408);
    } on SocketException {
      throw ApiException('인터넷 연결을 확인해주세요.', 0);
    }
  }

  Future<http.Response> _delete(String path, {bool auth = false}) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl$path'),
        headers: await _headers(auth: auth),
      ).timeout(_timeout);
      return res;
    } on TimeoutException {
      throw ApiException('서버 응답이 너무 느려요. 잠시 후 다시 시도해주세요.', 408);
    } on SocketException {
      throw ApiException('인터넷 연결을 확인해주세요.', 0);
    }
  }

  // ─── 추천 ──────────────────────────────────────────────────
  Future<RecommendResponse> recommend(Conditions cond) async {
    final res = await _post('/api/recommend', body: cond.toJson());
    _checkStatus(res);
    return RecommendResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ─── 식당 상세 ─────────────────────────────────────────────
  Future<RestaurantDetail> getRestaurantDetail(
    String id, {
    double? userLat,
    double? userLng,
    String transport = '도보',
  }) async {
    final params = <String, String>{'transport': transport};
    if (userLat != null) params['user_lat'] = '$userLat';
    if (userLng != null) params['user_lng'] = '$userLng';

    final res = await _get('/api/restaurant/$id', query: params);
    _checkStatus(res);
    return RestaurantDetail.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ─── 주변 식당 (지도용) ─────────────────────────────────────
  Future<List<RestaurantMapItem>> getNearbyRestaurants({
    required double lat,
    required double lng,
    int radiusM = 10000,
  }) async {
    final res = await _get('/api/restaurant/nearby', query: {
      'lat': '$lat',
      'lng': '$lng',
      'radius_m': '$radiusM',
    });
    _checkStatus(res);
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((j) => RestaurantMapItem.fromJson(j)).toList();
  }

  // ─── 날씨 ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWeather(double lat, double lng) async {
    final res = await _get('/api/weather', query: {'lat': '$lat', 'lng': '$lng'});
    _checkStatus(res);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ─── 혼잡도 신고 ────────────────────────────────────────────
  Future<void> reportCrowd(String restaurantId, String level) async {
    final res = await _post(
      '/api/restaurant/crowd-report',
      auth: true,
      body: {'restaurant_id': restaurantId, 'level': level},
    );
    _checkStatus(res);
  }

  // ─── 찜 ────────────────────────────────────────────────────
  Future<void> addFavorite(String restaurantId) async {
    final res = await _post('/api/user/favorites/$restaurantId', auth: true);
    _checkStatus(res);
  }

  Future<void> removeFavorite(String restaurantId) async {
    final res = await _delete('/api/user/favorites/$restaurantId', auth: true);
    _checkStatus(res);
  }

  Future<List<dynamic>> getFavorites() async {
    final res = await _get('/api/user/favorites', auth: true);
    _checkStatus(res);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ─── 회원가입 / 로그인 ──────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nickname,
    required String identity,
  }) async {
    final res = await _post('/api/user/register', body: {
      'email': email,
      'password': password,
      'nickname': nickname,
      'identity': identity,
    });
    _checkStatus(res);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/api/user/login', body: {
      'email': email,
      'password': password,
    });
    _checkStatus(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token']);
    await _saveUserProfile(prefs, data);
    return data;
  }

  Future<Map<String, dynamic>> loginWithKakao(String kakaoAccessToken) async {
    final res = await _post('/api/user/kakao-login',
        body: {'kakao_access_token': kakaoAccessToken});
    _checkStatus(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token']);
    await _saveUserProfile(prefs, data);
    return data;
  }

  Future<void> _saveUserProfile(dynamic prefs, Map<String, dynamic> data) async {
    final nickname = data['nickname'] ?? data['user']?['nickname'];
    final identity = data['identity'] ?? data['user']?['identity'];
    if (nickname != null) await prefs.setString('user_nickname', nickname as String);
    if (identity != null) await prefs.setString('user_identity', identity as String);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  /// 서버에 토큰 유효성 검증 — 만료/변조된 토큰 감지
  /// 네트워크 장애 시 false 대신 예외를 전파해 호출측이 판단
  Future<bool> validateToken() async {
    if (!await isLoggedIn()) return false;
    try {
      final res = await _get('/api/user/me', auth: true)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false; // 네트워크 실패 → 유효하지 않은 것으로 처리
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_nickname');
    await prefs.remove('user_identity');
  }

  // ─── 에러 처리 ─────────────────────────────────────────────
  void _checkStatus(http.Response res) {
    if (res.statusCode == 401) {
      // 토큰 만료 → 자동 로그아웃
      logout();
      throw ApiException('로그인이 만료됐어요. 다시 로그인해주세요.', 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = '서버 오류 (${res.statusCode})';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        message = body['detail'] ?? message;
      } catch (_) {}
      throw ApiException(message, res.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
