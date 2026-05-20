// 화면 1 — 조건 입력
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/conditions.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/chip_widget.dart';
import '../widgets/bottom_nav.dart';

class ScreenInput extends StatefulWidget {
  final Conditions conditions;
  final ValueChanged<Conditions> onChanged;
  final VoidCallback onSubmit;
  final int navIndex;
  final ValueChanged<int> onNavTap;

  const ScreenInput({
    super.key,
    required this.conditions,
    required this.onChanged,
    required this.onSubmit,
    required this.navIndex,
    required this.onNavTap,
  });

  @override
  State<ScreenInput> createState() => _ScreenInputState();
}

class _ScreenInputState extends State<ScreenInput> {
  late Conditions _c;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _c = widget.conditions;
    // GPS 모드이고 좌표가 없으면 자동으로 위치 가져오기
    // addPostFrameCallback: 위젯이 완전히 마운트된 후 실행 (context 안전 사용)
    if (_c.locationType == 'gps' && _c.lat == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGps());
    }
  }

  Future<void> _fetchGps() async {
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        // GPS 권한 거부 → 용봉동 중심으로 폴백
        _set(_c.copyWith(
          lat: AppConfig.focusLat,
          lng: AppConfig.focusLng,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('위치 권한 없음 — ${AppConfig.focusAreaName} 기준으로 검색합니다'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _set(_c.copyWith(lat: pos.latitude, lng: pos.longitude));
    } catch (e) {
      // GPS 오류 → 용봉동 중심으로 폴백
      _set(_c.copyWith(
        lat: AppConfig.focusLat,
        lng: AppConfig.focusLng,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치를 가져오지 못했어요 — ${AppConfig.focusAreaName} 기준으로 검색합니다'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  void _set(Conditions updated) {
    setState(() => _c = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ─── 스크롤 본문 ─────────────────────────────────────
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 200),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildIdentity(),
                    _buildPurpose(),
                    _buildTargetTime(),
                    _buildMealTime(),
                    _buildPartySize(),
                    _buildLocation(),
                    _buildTransport(),
                    _buildTime(),
                    _buildBudget(),
                  ]),
                ),
              ),
            ],
          ),

          // ─── 하단 고정 CTA ───────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        kBg,
                        kBg.withOpacity(0.0),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        shadowColor: kBrand.withOpacity(0.32),
                      ).copyWith(
                        elevation: WidgetStateProperty.all(8),
                        shadowColor: WidgetStateProperty.all(kBrand.withOpacity(0.32)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('추천 식당 찾기',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              )),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 헤더 ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 16, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('식사 추천',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kBrand,
                    letterSpacing: 0.08 * 13,
                  )),
              GestureDetector(
                onTap: () => _set(const Conditions()),
                child: const Text('초기화',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kInk3,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('어디서 드실까요?',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kInk,
                letterSpacing: -0.7,
                height: 1.15,
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: kBrand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kBrand.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.location_on_rounded, size: 12, color: kBrand),
                    SizedBox(width: 4),
                    Text(AppConfig.focusAreaName,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kBrand,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _c.identity == '학생'
                    ? '~8,000원 자동 적용'
                    : '~12,000원 자동 적용',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: kInk2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 섹션 라벨 ────────────────────────────────────────────
  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kInk,
              letterSpacing: -0.1,
            )),
      );

  Widget _section(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_sectionLabel(label), child],
        ),
      );

  // ─── 신분 ─────────────────────────────────────────────────
  Widget _buildIdentity() => _section(
        '신분',
        Row(
          children: ['학생', '직장인'].map((opt) {
            return Expanded(
              child: Padding(
                padding: opt == '학생'
                    ? const EdgeInsets.only(right: 4)
                    : const EdgeInsets.only(left: 4),
                child: GridSelectButton(
                  label: opt,
                  active: _c.identity == opt,
                  onTap: () => _set(_c.copyWith(identity: opt)),
                ),
              ),
            );
          }).toList(),
        ),
      );

  // ─── 식사 목적 ────────────────────────────────────────────
  Widget _buildPurpose() => _section(
        '식사 목적',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['혼밥', '친목', '회식', '소개팅', '비즈니스'].map((opt) {
            return SelectChip(
              label: opt,
              active: _c.purpose == opt,
              onTap: () => _set(_c.copyWith(purpose: opt)),
            );
          }).toList(),
        ),
      );

  // ─── 식사 시간대 ──────────────────────────────────────────
  Widget _buildMealTime() {
    const options = ['아침', '점심', '저녁', '술자리'];
    const icons = ['☀️', '🍱', '🌙', '🍺'];
    return _section(
      '식사 시간대',
      Row(
        children: List.generate(options.length, (i) {
          final opt = options[i];
          final active = _c.mealTime == opt;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == options.length - 1 ? 0 : 4,
              ),
              child: GestureDetector(
                onTap: () => _set(_c.copyWith(mealTime: opt)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? kBrand : kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? kBrand : kHair,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icons[i], style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        opt,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.white : kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── 인원 ─────────────────────────────────────────────────
  Widget _buildPartySize() => _section(
        '인원',
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kHair),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _stepperBtn(
                Icons.remove,
                () => _set(_c.copyWith(partySize: (_c.partySize - 1).clamp(1, 20))),
              ),
              Expanded(
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_c.partySize}',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const TextSpan(
                          text: ' 명',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kInk3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _stepperBtn(
                Icons.add,
                () => _set(_c.copyWith(partySize: (_c.partySize + 1).clamp(1, 20))),
              ),
            ],
          ),
        ),
      );

  Widget _stepperBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: kInk2),
        ),
      );

  // ─── 위치 ─────────────────────────────────────────────────
  Widget _buildLocation() => _section(
        '위치',
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GridSelectButton(
                    label: '현재 위치',
                    active: _c.locationType == 'gps',
                    onTap: () {
                      _set(_c.copyWith(locationType: 'gps'));
                      _fetchGps();
                    },
                    leading: _gpsLoading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kBrand),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GridSelectButton(
                    label: '직접 검색',
                    active: _c.locationType == 'search',
                    onTap: () => _set(_c.copyWith(locationType: 'search')),
                    leading: const Icon(Icons.search_rounded, size: 16),
                  ),
                ),
              ],
            ),
            if (_c.locationType == 'gps') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kBrand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: kBrand, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _gpsLoading
                          ? '위치 가져오는 중...'
                          : _c.lat != null
                              ? 'GPS 위치 확인됨 (${_c.lat!.toStringAsFixed(4)}, ${_c.lng!.toStringAsFixed(4)})'
                              : 'GPS 위치를 가져올 수 없습니다',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kBrandDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  // ─── 이동수단 ─────────────────────────────────────────────
  Widget _buildTransport() => _section(
        '이동수단',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['도보', '자전거', '대중교통', '자동차'].map((opt) {
            return SelectChip(
              label: opt,
              active: _c.transport == opt,
              onTap: () => _set(_c.copyWith(transport: opt)),
            );
          }).toList(),
        ),
      );

  // ─── 식사 가능 시간 ────────────────────────────────────────
  // ─── 식사 시각 ────────────────────────────────────────────────
  Widget _buildTargetTime() {
    final dt = _c.targetDateTime;
    final isNow = dt == null;
    return _section(
      '언제 드실 건가요?',
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _set(_c.copyWith(clearTargetDateTime: true)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isNow ? kBrand : kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isNow ? kBrand : kHair),
                    ),
                    child: Center(
                      child: Text('지금 바로',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                            color: isNow ? Colors.white : kInk,
                          )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dt ?? now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 7)),
                      locale: const Locale('ko'),
                    );
                    if (picked == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(dt ?? now),
                    );
                    if (time == null || !mounted) return;
                    _set(_c.copyWith(
                      targetDateTime: DateTime(
                        picked.year, picked.month, picked.day,
                        time.hour, time.minute,
                      ),
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: !isNow ? kBrand : kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: !isNow ? kBrand : kHair),
                    ),
                    child: Center(
                      child: Text(
                        !isNow
                            ? '${dt!.month}/${dt.day} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                            : '시간 설정',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: !isNow ? FontWeight.w700 : FontWeight.w500,
                          color: !isNow ? Colors.white : kInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTime() => _section(
        '식사 가능 시간',
        Row(
          children: ['30분', '1시간', '1.5시간', '2시간+'].asMap().entries.map((e) {
            final minutes = [30, 60, 90, 120][e.key];
            final label = e.value;
            final active = _c.availableMinutes == minutes;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: e.key == 0 ? 0 : 4,
                  right: e.key == 3 ? 0 : 4,
                ),
                child: GestureDetector(
                  onTap: () => _set(_c.copyWith(availableMinutes: minutes)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: active ? kBrand : kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? kBrand : kHair,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.white : kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  // ─── 예산 ─────────────────────────────────────────────────
  Widget _buildBudget() => _section(
        '예산',
        Column(
          children: [
            Row(
              children: ['기본값', '직접 설정'].map((opt) {
                final active = _c.priceMode == (opt == '기본값' ? 'default' : 'custom');
                return Expanded(
                  child: Padding(
                    padding: opt == '기본값'
                        ? const EdgeInsets.only(right: 4)
                        : const EdgeInsets.only(left: 4),
                    child: GridSelectButton(
                      label: opt,
                      active: active,
                      onTap: () => _set(_c.copyWith(
                          priceMode: opt == '기본값' ? 'default' : 'custom')),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            if (_c.priceMode == 'default')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kHair),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('1인 예산',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: kInk2,
                        )),
                    Text(
                      '~${_c.identity == '학생' ? '8,000' : '12,000'}원',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kHair),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('1인 예산',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              color: kInk2,
                            )),
                        Text(
                          '~${_formatPrice(_c.priceMax ?? 10000)}원',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kBrand,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: kBrand,
                        inactiveTrackColor: kHair,
                        thumbColor: kBrand,
                        overlayColor: kBrand.withOpacity(0.12),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: 4000,
                        max: 30000,
                        divisions: 52,
                        value: (_c.priceMax ?? 10000).toDouble(),
                        onChanged: (v) =>
                            _set(_c.copyWith(priceMax: v.round())),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  String _formatPrice(int price) =>
      price.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
