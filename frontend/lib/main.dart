// 앱 진입점 — 화면 전환 + 인증 상태 관리
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'models/conditions.dart';
import 'models/restaurant.dart';
import 'services/api_service.dart';
import 'screens/screen_input.dart';
import 'screens/screen_results.dart';
import 'screens/screen_detail.dart';
import 'screens/screen_login.dart';
import 'screens/screen_register.dart';
import 'theme.dart';

// ─── Kakao Native App Key (카카오 개발자 콘솔에서 발급) ─────────
// https://developers.kakao.com/console/app → 내 애플리케이션 → 앱 키 → 네이티브 앱 키
const _kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: _kakaoNativeAppKey);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한끼루트',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppRoot(),
    );
  }
}

// ─── 인증 상태 ────────────────────────────────────────────────
enum _AuthState { checking, unauthenticated, authenticated }

// ─── 메인 화면 ────────────────────────────────────────────────
enum _AppScreen { input, results, detail }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  // ── 인증
  _AuthState _authState = _AuthState.checking;
  bool _showRegister = false;   // true → 회원가입 화면

  // ── 메인 앱
  _AppScreen _screen = _AppScreen.input;
  Conditions _conditions = const Conditions();
  RecommendResponse? _response;
  String? _selectedId;
  bool _loading = false;
  String? _error;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await ApiService.instance.isLoggedIn();
    if (mounted) {
      setState(() {
        _authState = loggedIn ? _AuthState.authenticated : _AuthState.unauthenticated;
      });
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _authState = _AuthState.authenticated;
      _showRegister = false;
    });
  }

  void _onRegisterSuccess() {
    // 회원가입 성공 후 곧바로 로그인 화면으로
    setState(() => _showRegister = false);
  }

  Future<void> _onLogout() async {
    await ApiService.instance.logout();
    setState(() {
      _authState = _AuthState.unauthenticated;
      _showRegister = false;
      _screen = _AppScreen.input;
      _response = null;
      _selectedId = null;
    });
  }

  // ─── 추천 요청 ───────────────────────────────────────────────
  Future<void> _onSubmit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService.instance.recommend(_conditions);
      setState(() {
        _response = resp;
        _screen = _AppScreen.results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '추천을 불러오지 못했어요: ${e.toString()}';
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ─── 화면 슬라이드 트랜지션 ──────────────────────────────────
  Widget _buildTransition({
    required Widget child,
    required bool visible,
    required bool fromRight,
  }) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: const Cubic(0.32, 0.72, 0, 1),
      offset: visible
          ? Offset.zero
          : (fromRight ? const Offset(1.0, 0) : const Offset(-0.3, 0)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: visible ? 1.0 : 0.0,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 토큰 확인 중: 스플래시 ───────────────────────────────────
    if (_authState == _AuthState.checking) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: kBrand,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('끼',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: kBrand, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    // ── 미인증: 로그인 / 회원가입 ────────────────────────────────
    if (_authState == _AuthState.unauthenticated) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _showRegister
            ? ScreenRegister(
                key: const ValueKey('register'),
                onRegisterSuccess: _onRegisterSuccess,
                onGoToLogin: () => setState(() => _showRegister = false),
              )
            : ScreenLogin(
                key: const ValueKey('login'),
                onLoginSuccess: _onLoginSuccess,
                onGoToRegister: () => setState(() => _showRegister = true),
              ),
      );
    }

    // ── 인증 완료: 메인 앱 ────────────────────────────────────────
    return Stack(
      children: [
        // ① 조건 입력
        _buildTransition(
          visible: _screen == _AppScreen.input,
          fromRight: false,
          child: IgnorePointer(
            ignoring: _screen != _AppScreen.input,
            child: ScreenInput(
              conditions: _conditions,
              onChanged: (c) => setState(() => _conditions = c),
              onSubmit: _onSubmit,
              navIndex: _navIndex,
              onNavTap: (i) {
                setState(() => _navIndex = i);
                if (i == 2) _onLogout(); // 마이페이지 탭 → 임시: 로그아웃
              },
            ),
          ),
        ),

        // ② 추천 결과
        if (_response != null)
          _buildTransition(
            visible: _screen == _AppScreen.results,
            fromRight: _screen == _AppScreen.input,
            child: IgnorePointer(
              ignoring: _screen != _AppScreen.results,
              child: ScreenResults(
                response: _response!,
                conditions: _conditions,
                onBack: () => setState(() => _screen = _AppScreen.input),
                onPick: (r) => setState(() {
                  _selectedId = r.id;
                  _screen = _AppScreen.detail;
                }),
                navIndex: _navIndex,
                onNavTap: (i) => setState(() => _navIndex = i),
              ),
            ),
          ),

        // ③ 식당 상세
        if (_selectedId != null)
          _buildTransition(
            visible: _screen == _AppScreen.detail,
            fromRight: true,
            child: IgnorePointer(
              ignoring: _screen != _AppScreen.detail,
              child: ScreenDetail(
                restaurantId: _selectedId!,
                onBack: () => setState(() => _screen = _AppScreen.results),
                navIndex: _navIndex,
                onNavTap: (i) => setState(() => _navIndex = i),
              ),
            ),
          ),

        // ── 로딩 오버레이
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16))),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: kBrand),
                      SizedBox(height: 12),
                      Text('추천 식당 찾는 중...',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
