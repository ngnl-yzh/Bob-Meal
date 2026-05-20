// 화면 — 내 정보 (마이페이지)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';

class ScreenMyPage extends StatefulWidget {
  final VoidCallback onLogout;
  final int navIndex;
  final ValueChanged<int> onNavTap;

  const ScreenMyPage({
    super.key,
    required this.onLogout,
    required this.navIndex,
    required this.onNavTap,
  });

  @override
  State<ScreenMyPage> createState() => _ScreenMyPageState();
}

class _ScreenMyPageState extends State<ScreenMyPage> {
  String _nickname = '';
  String _identity = '학생';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nickname = prefs.getString('user_nickname') ?? '';
        _identity = prefs.getString('user_identity') ?? '학생';
        _loading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('로그아웃',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kInk,
            )),
        content: const Text('정말 로그아웃하실 건가요?',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: kInk2,
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  color: kInk2,
                )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                )),
          ),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nickname.isNotEmpty ? _nickname[0] : '?';

    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          // ── 헤더 ───────────────────────────────────────────
          Container(
            color: kCard,
            padding: EdgeInsets.fromLTRB(
                22, MediaQuery.of(context).padding.top + 14, 22, 16),
            child: const Row(
              children: [
                Text('내 정보',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                      letterSpacing: -0.4,
                    )),
              ],
            ),
          ),

          // ── 본문 ───────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kBrand, strokeWidth: 2))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 100),
                    children: [
                      _buildProfileCard(initials),
                      const SizedBox(height: 24),
                      _buildSectionLabel('나의 활동'),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('앱 정보'),
                      _buildSettingsList(),
                      const SizedBox(height: 28),
                      _buildLogoutButton(),
                    ],
                  ),
          ),

          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }

  // ── 프로필 카드 ───────────────────────────────────────────
  Widget _buildProfileCard(String initials) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kHair),
      ),
      child: Row(
        children: [
          // 이니셜 아바타
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: kBrand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nickname.isNotEmpty ? _nickname : '이름 없음',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: kBrand50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _identity,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kBrandDark,
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

  // ── 통계 ─────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('찜한 식당', '0개', Icons.favorite_rounded),
        const SizedBox(width: 12),
        _statCard('추천 받은 횟수', '0회', Icons.restaurant_rounded),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kHair),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: kInk3),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: kInk3,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  // ── 앱 정보 목록 ──────────────────────────────────────────
  Widget _buildSettingsList() {
    final items = [
      _Item(Icons.info_outline_rounded, '앱 버전', 'v1.0.0', null),
      _Item(Icons.mail_outline_rounded, '문의 / 피드백', null, () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('준비 중입니다.')),
        );
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHair),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(item.icon, size: 20, color: kInk2),
                title: Text(item.label,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: kInk,
                    )),
                trailing: item.trailing != null
                    ? Text(item.trailing!,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: kInk3,
                        ))
                    : const Icon(Icons.chevron_right_rounded,
                        size: 18, color: kInk3),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(height: 1, color: kHair, indent: 52),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── 로그아웃 버튼 ─────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _confirmLogout,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF4444)),
          foregroundColor: const Color(0xFFEF4444),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('로그아웃',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }

  Widget _buildSectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kInk3,
              letterSpacing: 0.3,
            )),
      );
}

class _Item {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _Item(this.icon, this.label, this.trailing, this.onTap);
}
