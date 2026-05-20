// 화면 2 — 추천 결과
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/conditions.dart';
import '../theme.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_banner.dart';

class ScreenResults extends StatefulWidget {
  final RecommendResponse response;
  final Conditions conditions;
  final VoidCallback onBack;
  final ValueChanged<RestaurantCard> onPick;
  final int navIndex;
  final ValueChanged<int> onNavTap;

  const ScreenResults({
    super.key,
    required this.response,
    required this.conditions,
    required this.onBack,
    required this.onPick,
    required this.navIndex,
    required this.onNavTap,
  });

  @override
  State<ScreenResults> createState() => _ScreenResultsState();
}

class _ScreenResultsState extends State<ScreenResults> {
  String _sort = '추천순';
  bool _showAll = false;

  List<RestaurantCard> get _sorted {
    final list = List<RestaurantCard>.from(widget.response.results);
    if (_sort == '거리순') list.sort((a, b) => a.walkMinutes.compareTo(b.walkMinutes));
    if (_sort == '가격순') list.sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final visible = _showAll ? sorted : sorted.take(4).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          // ─── 상단 바 ──────────────────────────────────────
          _buildTopBar(),

          // ─── 정렬 탭 ──────────────────────────────────────
          _buildSortTabs(sorted.length),

          // ─── 카드 리스트 / 빈 결과 ────────────────────────
          Expanded(
            child: sorted.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    children: [
                      // 날씨 배너 (위치 정보 있을 때만 표시 / 출처: 기상청)
                      if (widget.conditions.lat != null &&
                          widget.conditions.lng != null)
                        WeatherBanner(
                          lat: widget.conditions.lat!,
                          lng: widget.conditions.lng!,
                        ),
                      ...visible.asMap().entries.map((e) => RestaurantCardWidget(
                            restaurant: e.value,
                            onTap: () => widget.onPick(e.value),
                            rank: _sort == '추천순' ? e.key + 1 : null,
                            transport: widget.conditions.transport,
                          )),
                      if (!_showAll && sorted.length > 4)
                        GestureDetector(
                          onTap: () => setState(() => _showAll = true),
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: kHair, style: BorderStyle.solid),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${sorted.length - 4}개 더 보기',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: kInk2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 16, color: kInk2),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: kCard,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 뒤로가기
              GestureDetector(
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_left_rounded, size: 26, color: kInk),
                ),
              ),
              const Expanded(
                child: Text('추천 결과',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                      letterSpacing: -0.4,
                    )),
              ),
              // 조건 수정
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: kHair),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.tune_rounded, size: 11, color: kInk2),
                      SizedBox(width: 4),
                      Text('조건 수정',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kInk2,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.response.summary,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              color: kInk2,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 결과 없음 ────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: kBrand50,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('조건에 맞는 식당이 없어요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 10),
            const Text(
              '이동 시간을 늘리거나\n예산을 조금 올려보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: kInk2,
                height: 1.6,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('조건 다시 설정',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBrand),
                foregroundColor: kBrand,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortTabs(int count) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          ...['추천순', '거리순', '가격순'].map((s) {
            final active = _sort == s;
            return GestureDetector(
              onTap: () => setState(() => _sort = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? kInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : kInk2,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            '$count개 결과',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: kInk3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
