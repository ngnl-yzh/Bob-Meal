// 앱 진입점 — 화면 전환 + 상태 관리
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/conditions.dart';
import 'models/restaurant.dart';
import 'services/api_service.dart';
import 'screens/screen_input.dart';
import 'screens/screen_results.dart';
import 'screens/screen_detail.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: '식당 추천',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppRoot(),
    );
  }
}

// ─── 화면 열거형 ──────────────────────────────────────────────
enum AppScreen { input, results, detail }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppScreen _screen = AppScreen.input;
  Conditions _conditions = const Conditions();
  RecommendResponse? _response;
  String? _selectedId;
  bool _loading = false;
  String? _error;
  int _navIndex = 0;

  // ─── 추천 요청 ─────────────────────────────────────────────
  Future<void> _onSubmit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService.instance.recommend(_conditions);
      setState(() {
        _response = resp;
        _screen = AppScreen.results;
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

  // ─── 화면 전환 슬라이드 애니메이션 ───────────────────────────
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
    return Stack(
      children: [
        // ① 조건 입력
        _buildTransition(
          visible: _screen == AppScreen.input,
          fromRight: false,
          child: IgnorePointer(
            ignoring: _screen != AppScreen.input,
            child: ScreenInput(
              conditions: _conditions,
              onChanged: (c) => setState(() => _conditions = c),
              onSubmit: _onSubmit,
              navIndex: _navIndex,
              onNavTap: (i) => setState(() => _navIndex = i),
            ),
          ),
        ),

        // ② 추천 결과
        if (_response != null)
          _buildTransition(
            visible: _screen == AppScreen.results,
            fromRight: _screen == AppScreen.input,
            child: IgnorePointer(
              ignoring: _screen != AppScreen.results,
              child: ScreenResults(
                response: _response!,
                conditions: _conditions,
                onBack: () => setState(() => _screen = AppScreen.input),
                onPick: (r) => setState(() {
                  _selectedId = r.id;
                  _screen = AppScreen.detail;
                }),
                navIndex: _navIndex,
                onNavTap: (i) => setState(() => _navIndex = i),
              ),
            ),
          ),

        // ③ 식당 상세
        if (_selectedId != null)
          _buildTransition(
            visible: _screen == AppScreen.detail,
            fromRight: true,
            child: IgnorePointer(
              ignoring: _screen != AppScreen.detail,
              child: ScreenDetail(
                restaurantId: _selectedId!,
                onBack: () => setState(() => _screen = AppScreen.results),
                navIndex: _navIndex,
                onNavTap: (i) => setState(() => _navIndex = i),
              ),
            ),
          ),

        // 로딩 오버레이
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
