// 디자인 시스템 — UI 프로토타입 ui.jsx 와 동일한 컬러/타이포 시스템
import 'package:flutter/material.dart';

// ─── 브랜드 컬러 ─────────────────────────────────────────────
const Color kBrand     = Color(0xFF0F766E);
const Color kBrandDark = Color(0xFF0B5A55);
const Color kBrand50   = Color(0xFFECFDF5);
const Color kBrand100  = Color(0xFFD1FAE5);

// ─── 텍스트 컬러 ─────────────────────────────────────────────
const Color kInk  = Color(0xFF0A0A0A);
const Color kInk2 = Color(0xFF525252);
const Color kInk3 = Color(0xFFA3A3A3);

// ─── 배경/구분선 ──────────────────────────────────────────────
const Color kHair = Color(0xFFEDEDE9);
const Color kBg   = Color(0xFFFAFAF7);
const Color kCard = Color(0xFFFFFFFF);

// ─── 혼잡도 컬러 ─────────────────────────────────────────────
const Color kCrowdLow    = Color(0xFF10B981);  // 한산
const Color kCrowdMed    = Color(0xFFF59E0B);  // 보통
const Color kCrowdHigh   = Color(0xFFEF4444);  // 혼잡

Color crowdColor(String level) {
  switch (level) {
    case '한산': return kCrowdLow;
    case '보통': return kCrowdMed;
    case '혼잡': return kCrowdHigh;
    default:     return kInk3;
  }
}

// ─── ThemeData ────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrand,
      primary: kBrand,
      surface: kBg,
    ),
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Pretendard',
    appBarTheme: const AppBarTheme(
      backgroundColor: kCard,
      foregroundColor: kInk,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.4,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: kInk,
        letterSpacing: -0.7,
        height: 1.15,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.3,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: kInk2,
        letterSpacing: -0.2,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: kInk3,
        letterSpacing: -0.1,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: kInk3,
        letterSpacing: -0.1,
      ),
    ),
  );
}
