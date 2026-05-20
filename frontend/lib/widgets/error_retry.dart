// 서버 오류 / 네트워크 오류 공통 위젯
import 'package:flutter/material.dart';
import '../theme.dart';

class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool fullScreen;

  const ErrorRetryWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.fullScreen = false,
  });

  // 에러 메시지 → 사용자 친화적 문구 + 아이콘
  ({String text, IconData icon, Color color}) _parse() {
    final m = message.toLowerCase();

    if (m.contains('인터넷 연결') || m.contains('socketexception')) {
      return (
        text: '인터넷 연결을 확인해주세요',
        icon: Icons.wifi_off_rounded,
        color: const Color(0xFFEF4444),
      );
    }
    if (m.contains('응답이 너무 느려') || m.contains('timeout') || m.contains('408')) {
      return (
        text: '서버 응답이 느려요\n잠시 후 다시 시도해주세요',
        icon: Icons.hourglass_empty_rounded,
        color: const Color(0xFFF59E0B),
      );
    }
    if (m.contains('500') || m.contains('502') || m.contains('503') ||
        m.contains('서버 오류')) {
      return (
        text: '서버에 일시적인 문제가 있어요\n잠시 후 다시 시도해주세요',
        icon: Icons.cloud_off_rounded,
        color: const Color(0xFFF59E0B),
      );
    }
    if (m.contains('로그인이 만료') || m.contains('401')) {
      return (
        text: '로그인이 만료됐어요\n다시 로그인해주세요',
        icon: Icons.lock_outline_rounded,
        color: kBrand,
      );
    }

    return (
      text: '잠시 문제가 생겼어요\n다시 시도해주세요',
      icon: Icons.error_outline_rounded,
      color: const Color(0xFFEF4444),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _parse();
    final bgColor = info.color.withOpacity(0.1);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Icon(info.icon, size: 32, color: info.color),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          info.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kInk,
            letterSpacing: -0.2,
            height: 1.55,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('다시 시도',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrand,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: content,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: content,
      ),
    );
  }
}
