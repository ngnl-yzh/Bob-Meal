// 화면 — 로그인
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ScreenLogin extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onGoToRegister;

  const ScreenLogin({
    super.key,
    required this.onLoginSuccess,
    required this.onGoToRegister,
  });

  @override
  State<ScreenLogin> createState() => _ScreenLoginState();
}

class _ScreenLoginState extends State<ScreenLogin> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  // ─── 이메일 로그인 ────────────────────────────────────────────
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.instance.login(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      widget.onLoginSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 401
          ? '이메일 또는 비밀번호가 올바르지 않아요'
          : '로그인 중 오류가 발생했어요 (${e.statusCode})');
    } catch (_) {
      setState(() => _error = '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── 카카오 로그인 ────────────────────────────────────────────
  Future<void> _loginWithKakao() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 카카오톡 앱이 있으면 앱으로, 없으면 웹으로 로그인
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      // 우리 백엔드에 카카오 액세스 토큰 전달 → JWT 교환
      await ApiService.instance.loginWithKakao(token.accessToken);
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _error = '카카오 로그인에 실패했어요. 다시 시도해주세요.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: top + 32),

                // ─── 로고 ──────────────────────────────────────
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: kBrand,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('끼',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text('한끼루트',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.5,
                      )),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('오늘 한끼, 어디서 먹을지 고민될 때',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: kInk3,
                      )),
                ),
                const SizedBox(height: 40),

                // ─── 에러 메시지 ────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12.5,
                                color: Color(0xFFDC2626),
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ─── 이메일 ────────────────────────────────────
                _inputLabel('이메일'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontFamily: 'Pretendard', fontSize: 15),
                  decoration: _inputDeco('example@email.com'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? '올바른 이메일을 입력해주세요' : null,
                ),
                const SizedBox(height: 14),

                // ─── 비밀번호 ───────────────────────────────────
                _inputLabel('비밀번호'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _loginWithEmail(),
                  style: const TextStyle(fontFamily: 'Pretendard', fontSize: 15),
                  decoration: _inputDeco('비밀번호').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20, color: kInk3,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? '6자 이상 입력해주세요' : null,
                ),
                const SizedBox(height: 22),

                // ─── 로그인 버튼 ────────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('로그인',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── 구분선 ────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider(color: kHair)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('또는',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: kInk3,
                          )),
                    ),
                    const Expanded(child: Divider(color: kHair)),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── 카카오 로그인 ──────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginWithKakao,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xFF191919),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('💬', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('카카오로 시작하기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── 회원가입 링크 ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('아직 계정이 없으신가요?',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: kInk3,
                        )),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onGoToRegister,
                      child: const Text('회원가입',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kBrand,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String label) => Text(label,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kInk,
      ));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          color: kInk3,
        ),
        filled: true,
        fillColor: kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kHair),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kHair),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBrand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      );
}
