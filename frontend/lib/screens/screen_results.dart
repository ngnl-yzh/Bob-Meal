// 화면 2 — 추천 결과
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/conditions.dart';
import '../theme.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/bottom_nav.dart';

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

          // ─── 카드 리스트 ───────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                ...visible.asMap().entries.map((e) => RestaurantCardWidget(
                      restaurant: e.value,
                      onTap: () => widget.onPick(e.value),
                      rank: _sort == '추천순' ? e.key + 1 : null,
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
                        border: Border.all(color: kHair, style: BorderStyle.solid),
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
