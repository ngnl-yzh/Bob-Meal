// 앱 진입점 — 화면 전환 + 인증 상태 관리
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'models/conditions.dart';
import 'models/restaurant.dart';
import 'services/api_service.dart';
import 'screens/screen_input.dart';
import 'screens/screen_results.dart';
import 'screens/screen_detail.dart';
import 'screens/screen_login.dart';
import 'screens/screen_register.dart';
import 'screens/screen_mypage.dart';
import 'widgets/bottom_nav.dart';
import 'theme.dart';

// ─── Kakao Native App Key ─────────────────────────────────────
const _kakaoNativeAppKey = '3a836e8e5af56598f2b946bdae6f1dca';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      home: const AppRoot(),
    );
  }
}

// ─── 인증 상태 ────────────────────────────────────────────────
enum _AuthState { checking, unauthenticated, authenticated }

// ─── 메인 앱 화면 스택 ────────────────────────────────────────
enum _AppScreen { input, results, detail }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  // ── 인증
  _AuthState _authState = _AuthState.checking;
  bool _showRegister = false;

  // ── 메인 앱
  _AppScreen _screen = _AppScreen.input;
  Conditions _conditions = const Conditions();
  RecommendResponse? _response;
  String? _selectedId;
  bool _loading = false;
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
        _authState =
            loggedIn ? _AuthState.authenticated : _AuthState.unauthenticated;
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
    setState(() => _showRegister = false);
  }

  Future<void> _onLogout() async {
    await ApiService.instance.logout();
    setState(() {
      _authState = _AuthState.unauthenticated;
      _showRegister = false;
      _screen = _AppScreen.input;
      _navIndex = 0;
      _response = null;
      _selectedId = null;
    });
  }

  // ── 탭 전환 ─────────────────────────────────────────────────
  void _onNavTap(int i) {
    setState(() {
      _navIndex = i;
      // 홈 탭 누르면 항상 입력 화면으로
      if (i == 0) _screen = _AppScreen.input;
    });
  }

  // ─── 추천 요청 ───────────────────────────────────────────────
  Future<void> _onSubmit() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService.instance.recommend(_conditions);
      if (mounted) {
        setState(() {
          _response = resp;
          _screen = _AppScreen.results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showErrorSnack(e.toString());
      }
    }
  }

  void _showErrorSnack(String msg) {
    String friendly = msg;
    if (msg.contains('인터넷 연결')) friendly = '인터넷 연결을 확인해주세요.';
    if (msg.contains('응답이 너무 느려')) friendly = '서버 응답이 느려요. 잠시 후 다시 시도해주세요.';
    if (msg.contains('서버 오류') || msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      friendly = '서버에 일시적인 문제가 있어요. 잠시 후 다시 시도해주세요.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(friendly,
                  style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ─── 슬라이드 트랜지션 ────────────────────────────────────────
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
    // ── 스플래시 (토큰 확인 중) ───────────────────────────────
    if (_authState == _AuthState.checking) {
      return _buildSplash();
    }

    // ── 미인증: 로그인 / 회원가입 ─────────────────────────────
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

    // ── 인증 완료: 메인 앱 ────────────────────────────────────
    return Stack(
      children: [
        // ① 조건 입력 (홈)
        _buildTransition(
          visible: _navIndex == 0 && _screen == _AppScreen.input,
          fromRight: false,
          child: IgnorePointer(
            ignoring: !(_navIndex == 0 && _screen == _AppScreen.input),
            child: ScreenInput(
              conditions: _conditions,
              onChanged: (c) => setState(() => _conditions = c),
              onSubmit: _onSubmit,
              navIndex: _navIndex,
              onNavTap: _onNavTap,
            ),
          ),
        ),

        // ② 추천 결과
        if (_response != null)
          _buildTransition(
            visible: _navIndex == 0 && _screen == _AppScreen.results,
            fromRight: _screen == _AppScreen.input,
            child: IgnorePointer(
              ignoring: !(_navIndex == 0 && _screen == _AppScreen.results),
              child: ScreenResults(
                response: _response!,
                conditions: _conditions,
                onBack: () => setState(() => _screen = _AppScreen.input),
                onPick: (r) => setState(() {
                  _selectedId = r.id;
                  _screen = _AppScreen.detail;
                }),
                navIndex: _navIndex,
                onNavTap: _onNavTap,
              ),
            ),
          ),

        // ③ 식당 상세
        if (_selectedId != null)
          _buildTransition(
            visible: _navIndex == 0 && _screen == _AppScreen.detail,
            fromRight: true,
            child: IgnorePointer(
              ignoring: !(_navIndex == 0 && _screen == _AppScreen.detail),
              child: ScreenDetail(
                restaurantId: _selectedId!,
                onBack: () => setState(() => _screen = _AppScreen.results),
                navIndex: _navIndex,
                onNavTap: _onNavTap,
                conditions: _conditions,
              ),
            ),
          ),

        // ④ 찜 탭 (준비 중)
        if (_navIndex == 1)
          _buildPlaceholder(
            icon: Icons.favorite_rounded,
            title: '찜한 식당',
            subtitle: '마음에 든 식당을 찜해보세요\n곧 업데이트될 예정이에요',
          ),

        // ⑤ 기록 탭 (준비 중)
        if (_navIndex == 2)
          _buildPlaceholder(
            icon: Icons.receipt_long_rounded,
            title: '방문 기록',
            subtitle: '다녀온 식당을 기록해보세요\n곧 업데이트될 예정이에요',
          ),

        // ⑥ 내정보 탭
        if (_navIndex == 3)
          ScreenMyPage(
            onLogout: _onLogout,
            navIndex: _navIndex,
            onNavTap: _onNavTap,
          ),

        // ── 추천 로딩 오버레이 ──────────────────────────────
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kBrand, strokeWidth: 2.5),
                    SizedBox(height: 14),
                    Text('추천 식당 찾는 중...',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                          letterSpacing: -0.2,
                        )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── 스플래시 화면 ──────────────────────────────────────────
  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로고 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kBrand,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: kBrand.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text('끼',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
              ),
            ),
            const SizedBox(height: 20),
            // 앱 이름
            const Text('한끼루트',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 6),
            const Text('맞춤 식사 장소 추천',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kInk3,
                  letterSpacing: -0.1,
                )),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: kBrand, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── 준비 중 탭 플레이스홀더 ───────────────────────────────
  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          // 헤더
          Container(
            color: kCard,
            padding: EdgeInsets.fromLTRB(
                22, MediaQuery.of(context).padding.top + 14, 22, 16),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                      letterSpacing: -0.4,
                    )),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: kHair,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, size: 30, color: kInk3),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      color: kInk2,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
        ],
      ),
    );
  }
}
