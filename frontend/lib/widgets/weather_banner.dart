// 날씨 배너 위젯 — 기상청 초단기예보 기반
// ※ 출처 표시 의무: 공공누리 1유형 (공공데이터포털)
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class WeatherBanner extends StatefulWidget {
  final double lat;
  final double lng;

  const WeatherBanner({super.key, required this.lat, required this.lng});

  @override
  State<WeatherBanner> createState() => _WeatherBannerState();
}

class _WeatherBannerState extends State<WeatherBanner> {
  Map<String, dynamic>? _weather;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final w = await ApiService.instance.getWeather(widget.lat, widget.lng);
      if (mounted) setState(() { _weather = w; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_loading) {
      return _shell(child: const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: kBrand),
      ));
    }
    // 오류 or 데이터 없음 → 배너 숨김
    if (_error || _weather == null) return const SizedBox.shrink();

    final condition = _weather!['condition'] as String? ?? '';
    final temp      = (_weather!['temperature'] as num?)?.toDouble() ?? 0.0;
    final advice    = _weather!['advice'] as String? ?? '';
    final isOk      = _weather!['is_outdoor_ok'] as bool? ?? true;

    final icon = _conditionIcon(condition);
    final tempStr = '${temp.toStringAsFixed(0)}°C';

    return _shell(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$condition  $tempStr',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        )),
                    if (!isOk) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('실내 추천',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            )),
                      ),
                    ],
                  ],
                ),
                if (advice.isNotEmpty)
                  Text(advice,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        color: kInk3,
                      )),
              ],
            ),
          ),
          // ─── 저작자 표시 (공공누리 1유형 의무) ─────────────────
          const Text('출처: 기상청',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 9,
                color: kInk3,
              )),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kHair),
        ),
        child: child,
      );

  String _conditionIcon(String condition) {
    switch (condition) {
      case '맑음':  return '☀️';
      case '구름많음': return '⛅';
      case '흐림':  return '☁️';
      case '비':   return '🌧️';
      case '눈':   return '❄️';
      default:    return '🌤️';
    }
  }
}
