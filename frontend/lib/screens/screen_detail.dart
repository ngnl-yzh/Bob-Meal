// 화면 3 — 식당 상세
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant.dart';
import '../models/conditions.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/smart_photo.dart';
import '../widgets/crowd_badge.dart';
import '../widgets/bottom_nav.dart';

class ScreenDetail extends StatefulWidget {
  final String restaurantId;
  final VoidCallback onBack;
  final int navIndex;
  final ValueChanged<int> onNavTap;
  final Conditions? conditions; // 위치·이동수단 전달 (walk_minutes 동적 계산용)

  const ScreenDetail({
    super.key,
    required this.restaurantId,
    required this.onBack,
    required this.navIndex,
    required this.onNavTap,
    this.conditions,
  });

  @override
  State<ScreenDetail> createState() => _ScreenDetailState();
}

class _ScreenDetailState extends State<ScreenDetail> {
  RestaurantDetail? _detail;
  bool _loading = true;
  String? _error;
  int _photoIdx = 0;
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.instance.getRestaurantDetail(
        widget.restaurantId,
        userLat: widget.conditions?.lat,
        userLng: widget.conditions?.lng,
        transport: widget.conditions?.transport ?? '도보',
      );
      if (mounted) setState(() { _detail = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─── 로딩 스켈레톤 (shimmer) ───────────────────────────────────
  Widget _buildShimmer() {
    return Scaffold(
      backgroundColor: kBg,
      body: Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF9FAFB),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대표 사진 영역
              Container(height: 240, width: double.infinity, color: Colors.white),
              const SizedBox(height: 12),
              // 타이틀 블록
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 22, width: 160, decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 10),
                    Container(height: 14, width: 100, decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(height: 28, width: 60, decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(width: 8),
                      Container(height: 28, width: 60, decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 혼잡도 바 스켈레톤
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(height: 12),
              // 메뉴 카드 스켈레톤 3개
              ...List.generate(3, (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildShimmer();
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));
    final r = _detail!;

    // 갤러리: 가게 사진 + 메뉴 사진 2장
    final gallery = <Map<String, dynamic>>[
      {'src': r.photoUrl, 'icon': r.heroIcon, 'hue': r.heroHue, 'label': '대표 사진'},
      ...r.menus.take(2).map((m) => {
            'src': m.photoUrl,
            'icon': m.icon,
            'hue': m.hue,
            'label': m.name,
          }),
    ];

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ─── 스크롤 본문 ─────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 180),
            child: Column(
              children: [
                _buildHeroGallery(r, gallery),
                _buildTitleBlock(r),
                const SizedBox(height: 8),
                _buildCrowdChart(r),
                const SizedBox(height: 8),
                _buildMenuSection(r),
                const SizedBox(height: 8),
                _buildFeaturesSection(r),
              ],
            ),
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
                      colors: [Colors.white, Colors.white.withOpacity(0)],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(child: _ctaOutline('길찾기', Icons.navigation_rounded, () => _openMap(r))),
                      const SizedBox(width: 10),
                      Expanded(child: _ctaFilled('전화', Icons.phone_rounded, () => _callPhone(r))),
                    ],
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

  // ─── 히어로 갤러리 ─────────────────────────────────────────
  Widget _buildHeroGallery(RestaurantDetail r, List<Map<String, dynamic>> gallery) {
    final item = gallery[_photoIdx];
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 사진
          GestureDetector(
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity == null) return;
              if (d.primaryVelocity! < 0 && _photoIdx < gallery.length - 1) {
                setState(() => _photoIdx++);
              } else if (d.primaryVelocity! > 0 && _photoIdx > 0) {
                setState(() => _photoIdx--);
              }
            },
            child: SmartPhoto(
              photoUrl: item['src'],
              heroIcon: item['icon'],
              heroHue: item['hue'],
              width: double.infinity,
              height: 280,
              borderRadius: 0,
            ),
          ),

          // 그라데이션 오버레이
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.32),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
                stops: const [0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 상단 버튼 영역
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _glassBtn(Icons.chevron_left_rounded, widget.onBack),
                const Spacer(),
                _glassBtn(
                  _fav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  () => setState(() => _fav = !_fav),
                  color: _fav ? const Color(0xFFFB7185) : Colors.white,
                ),
                const SizedBox(width: 8),
                _glassBtn(Icons.ios_share_rounded, () {}),
              ],
            ),
          ),

          // 하단: 사진 레이블 + dot indicator
          Positioned(
            bottom: 14,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item['label'],
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: List.generate(gallery.length, (i) {
                      final active = i == _photoIdx;
                      return GestureDetector(
                        onTap: () => setState(() => _photoIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 16 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 타이틀 블록 ──────────────────────────────────────────
  Widget _buildTitleBlock(RestaurantDetail r) {
    return Container(
      color: kCard,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.category,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kInk2,
                    letterSpacing: -0.1,
                  )),
              const SizedBox(width: 6),
              Container(
                  width: 2, height: 2,
                  decoration: const BoxDecoration(color: kInk3, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
              const SizedBox(width: 2),
              Text(
                r.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              Text(' · 리뷰 ${r.reviewCount}개',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: kInk3,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(width: 8),
              CrowdBadge(level: r.crowdLevel),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.name,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: kInk,
                letterSpacing: -0.8,
                height: 1.15,
              )),
          const SizedBox(height: 10),
          _infoRow(Icons.location_on_outlined,
              '${r.address} · ${widget.conditions?.transport ?? '도보'} ${r.walkMinutes}분'),
          _infoRow(
            Icons.access_time_rounded,
            null,
            richText: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  color: kInk2,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: r.isOpen ? '영업 중' : '마감',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: r.isOpen ? const Color(0xFF10B981) : kCrowdHigh,
                    ),
                  ),
                  const TextSpan(text: ' · '),
                  TextSpan(text: r.hours),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String? text, {Widget? richText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: kInk2),
          const SizedBox(width: 8),
          Expanded(
            child: richText ??
                Text(text ?? '',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: kInk2,
                      height: 1.5,
                      letterSpacing: -0.1,
                    )),
          ),
        ],
      ),
    );
  }

  // ─── 혼잡도 차트 ──────────────────────────────────────────
  Widget _buildCrowdChart(RestaurantDetail r) {
    return Container(
      color: kCard,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('혼잡도 예상',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.1,
                  )),
              Row(
                children: [
                  const Text('지금 ',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: kInk2,
                        fontWeight: FontWeight.w500,
                      )),
                  Text(
                    r.crowdLevel,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: crowdColor(r.crowdLevel),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: r.crowdByHour.map((c) {
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c.isNow)
                        Text('지금',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: kBrand,
                            )),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: c.crowdRatio,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: c.isNow ? kBrand : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.hourLabel,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          fontWeight: c.isNow ? FontWeight.w700 : FontWeight.w500,
                          color: c.isNow ? kInk : kInk3,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '이 시간대는 보통 ${r.crowdLevel}해요 · 통계 기반 예측',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              color: kInk3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          // 정확도 경고 (기획서 5장)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '혼잡도 예측은 통계 기반으로 정확하지 않을 수 있어요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 대표 메뉴 ────────────────────────────────────────────
  Widget _buildMenuSection(RestaurantDetail r) {
    final priceText = r.priceInfo?.displayText
        ?? (r.price > 0 ? '약 ${_fmt(r.price)}원' : '정보 없음');
    return Container(
      color: kCard,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('대표 메뉴',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.1,
                  )),
              Builder(builder: (context) {
                final conf = r.priceInfo?.confidence ?? r.priceConfidence;
                final label = conf >= 0.8
                    ? '신뢰도 높음'
                    : conf >= 0.5
                        ? '신뢰도 보통'
                        : '신뢰도 낮음';
                final color = conf >= 0.8
                    ? kBrand
                    : conf >= 0.5
                        ? const Color(0xFFF59E0B)
                        : kInk3;
                final bgColor = conf >= 0.8
                    ? kBrand50
                    : conf >= 0.5
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF5F5F4);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, size: 9, color: color),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                            letterSpacing: 0.02 * 10.5,
                          )),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 14),
          if (r.menus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 14, color: kInk3),
                  SizedBox(width: 8),
                  Text('메뉴 정보를 수집 중이에요',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: kInk3,
                      )),
                ],
              ),
            )
          else
            ...r.menus.asMap().entries.map((e) => _menuRow(e.value, e.key == 0)),
          const Divider(height: 24, color: Color(0xFFEDEDE9), thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1인 평균',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: kInk2,
                    fontWeight: FontWeight.w500,
                  )),
              Text(priceText,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.2,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('네이버 플레이스 기준',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  color: kInk3,
                )),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(Menu m, bool isBest) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SmartPhoto(
            photoUrl: m.photoUrl,
            heroIcon: m.icon,
            heroHue: m.hue,
            width: 64,
            height: 64,
            borderRadius: 12,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                          letterSpacing: -0.2,
                        )),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kBrand50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('BEST',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: kBrandDark,
                              letterSpacing: 0.04 * 9.5,
                            )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                const Text('1인 메뉴',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      color: kInk3,
                    )),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _fmt(m.price),
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.2,
                  ),
                ),
                const TextSpan(
                  text: '원',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11.5,
                    color: kInk3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 특징 ──────────────────────────────────────────────────
  Widget _buildFeaturesSection(RestaurantDetail r) {
    return Container(
      color: kCard,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('특징',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
                letterSpacing: -0.1,
              )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.features.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 11, color: kBrand),
                    const SizedBox(width: 5),
                    Text(f,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kInk2,
                          letterSpacing: -0.1,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 유틸 ─────────────────────────────────────────────────
  Widget _glassBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _ctaOutline(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBrand, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: kBrand),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: kBrand,
                  letterSpacing: -0.2,
                )),
          ],
        ),
      ),
    );
  }

  Widget _ctaFilled(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kBrand.withOpacity(0.32),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(RestaurantDetail r) async {
    final uri = Uri.parse(
        'https://map.kakao.com/link/search/${Uri.encodeComponent(r.name)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(RestaurantDetail r) async {
    if (r.phone == null) return;
    final uri = Uri.parse('tel:${r.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _fmt(int price) => price
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
