// 추천 결과 카드 — UI 프로토타입 RestaurantCard 와 동일한 레이아웃
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../theme.dart';
import 'smart_photo.dart';
import 'crowd_badge.dart';

class RestaurantCardWidget extends StatelessWidget {
  final RestaurantCard restaurant;
  final VoidCallback onTap;
  final int? rank;

  const RestaurantCardWidget({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 0,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── 사진 + 순위 배지 ───────────────────────────────
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SmartPhoto(
                    photoUrl: r.photoUrl,
                    heroIcon: r.heroIcon,
                    heroHue: r.heroHue,
                    width: 72,
                    height: 72,
                    borderRadius: 12,
                  ),
                  if (rank != null && rank! <= 3)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? kBrand
                              : rank == 2
                                  ? const Color(0xFF0E948A)
                                  : const Color(0xFF13B5A7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kBrand.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ─── 정보 영역 ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 카테고리
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: r.isOpen ? kInk : kInk3,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ─── 영업 상태 배지 ──────────────────────────
                      OpenStatusBadge(isOpen: r.isOpen, closesSoon: r.closesSoon),
                    ],
                  ),
                  // 오늘 영업시간
                  if (r.todayHours.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      r.isOpen
                          ? (r.closesSoon ? '⚠ 곧 마감 · ${r.todayHours}' : r.todayHours)
                          : r.todayHours,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        color: r.isOpen
                            ? (r.closesSoon ? const Color(0xFFF59E0B) : kInk3)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),

                  // 별점 · 거리 · 가격 · 혼잡도
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            r.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                            ),
                          ),
                          Text(
                            ' (${r.reviewCount})',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11,
                              color: kInk3,
                            ),
                          ),
                        ],
                      ),
                      _dot(),
                      Text(
                        '도보 ${r.walkMinutes}분',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: kInk2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _dot(),
                      Text(
                        '~${_formatPrice(r.price)}원',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: kInk2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      CrowdBadge(level: r.crowdLevel),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 태그들
                  Wrap(
                    spacing: 5,
                    children: r.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: kBrand50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: kBrandDark,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() => Container(
        width: 2, height: 2,
        decoration: const BoxDecoration(color: kInk3, shape: BoxShape.circle),
      );

  String _formatPrice(int price) {
    if (price >= 1000) {
      return price.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    }
    return '$price';
  }
}

// ─── 영업 상태 배지 (독립 위젯) ───────────────────────────────
class OpenStatusBadge extends StatelessWidget {
  final bool isOpen;
  final bool closesSoon;
  const OpenStatusBadge({
    super.key,
    required this.isOpen,
    required this.closesSoon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (!isOpen) {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF9CA3AF);
      label = '영업종료';
    } else if (closesSoon) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = '곧마감';
    } else {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF059669);
      label = '영업중';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
