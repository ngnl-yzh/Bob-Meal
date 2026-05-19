// 선택 칩 — UI 프로토타입 Chip 컴포넌트와 동일
import 'package:flutter/material.dart';
import '../theme.dart';

class SelectChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double fontSize;

  const SelectChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? kBrand : kCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? kBrand : kHair,
            width: 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: kBrand.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: fontSize,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? Colors.white : kInk,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// 격자형 선택 버튼 (신분·위치·시간 등)
class GridSelectButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Widget? leading;

  const GridSelectButton({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? kBrand : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? kBrand : kHair,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  active ? Colors.white : kInk2,
                  BlendMode.srcIn,
                ),
                child: leading!,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : kInk,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
