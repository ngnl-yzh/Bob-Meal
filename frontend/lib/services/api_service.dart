// HTTP 클라이언트 — 백엔드 FastAPI 와 통신
import 'dart:convert';
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

  // ─── 추천 ──────────────────────────────────────────────────
  Future<RecommendResponse> recommend(Conditions cond) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/recommend'),
      headers: await _headers(),
      body: jsonEncode(cond.toJson()),
    );
    _checkStatus(res);
    return RecommendResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ─── 식당 상세 ─────────────────────────────────────────────
  Future<RestaurantDetail> getRestaurantDetail(String id) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/restaurant/$id'),
      headers: await _headers(),
    );
    _checkStatus(res);
    return RestaurantDetail.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // ─── 날씨 ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWeather(double lat, double lng) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/weather?lat=$lat&lng=$lng'),
      headers: await _headers(),
    );
    _checkStatus(res);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ─── 혼잡도 신고 ────────────────────────────────────────────
  Future<void> reportCrowd(String restaurantId, String level) async {
    await http.post(
      Uri.parse('$_baseUrl/api/restaurant/crowd-report'),
      headers: await _headers(auth: true),
      body: jsonEncode({'restaurant_id': restaurantId, 'level': level}),
    );
  }

  // ─── 찜 ────────────────────────────────────────────────────
  Future<void> addFavorite(String restaurantId) async {
    await http.post(
      Uri.parse('$_baseUrl/api/user/favorites/$restaurantId'),
      headers: await _headers(auth: true),
    );
  }

  Future<void> removeFavorite(String restaurantId) async {
    await http.delete(
      Uri.parse('$_baseUrl/api/user/favorites/$restaurantId'),
      headers: await _headers(auth: true),
    );
  }

  Future<List<dynamic>> getFavorites() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/user/favorites'),
      headers: await _headers(auth: true),
    );
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
    final res = await http.post(
      Uri.parse('$_baseUrl/api/user/register'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
        'identity': identity,
      }),
    );
    _checkStatus(res);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/user/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    // 토큰 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token']);
    return data;
  }

  Future<Map<String, dynamic>> loginWithKakao(String kakaoAccessToken) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/user/kakao-login'),
      headers: await _headers(),
      body: jsonEncode({'kakao_access_token': kakaoAccessToken}),
    );
    _checkStatus(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    // JWT 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token']);
    return data;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // ─── 에러 처리 ─────────────────────────────────────────────
  void _checkStatus(http.Response res) {
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
