// 혼잡도 배지 — 한산(초록) / 보통(노랑) / 혼잡(빨강)
import 'package:flutter/material.dart';
import '../theme.dart';

class CrowdBadge extends StatelessWidget {
  final String level;
  final double fontSize;

  const CrowdBadge({super.key, required this.level, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = crowdColor(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          level,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
