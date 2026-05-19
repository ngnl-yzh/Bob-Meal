// SmartPhoto — 실제 사진 로드 실패 시 컬러 플레이스홀더로 폴백
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmartPhoto extends StatelessWidget {
  final String? photoUrl;
  final String heroIcon;
  final int heroHue;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  const SmartPhoto({
    super.key,
    this.photoUrl,
    required this.heroIcon,
    required this.heroHue,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
  });

  Color get _bgColor {
    // HSL(hue, 38%, 88%) 근사값
    return HSLColor.fromAHSL(1.0, heroHue.toDouble(), 0.38, 0.88).toColor();
  }

  Color get _accentColor {
    return HSLColor.fromAHSL(1.0, heroHue.toDouble(), 0.70, 0.50).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: fit,
                width: width,
                height: height,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: _bgColor,
      child: Center(
        child: Icon(
          _iconData(),
          size: (width ?? 64) * 0.4,
          color: _accentColor,
        ),
      ),
    );
  }

  IconData _iconData() {
    switch (heroIcon) {
      case 'katsu':     return Icons.set_meal_rounded;
      case 'kimbap':    return Icons.lunch_dining_rounded;
      case 'noodle':    return Icons.ramen_dining_rounded;
      case 'rice-bowl': return Icons.rice_bowl_rounded;
      case 'meat':      return Icons.kebab_dining_rounded;
      case 'stew':
      default:          return Icons.soup_kitchen_rounded;
    }
  }
}
