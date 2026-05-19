// 화면 — 회원가입
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/chip_widget.dart';

class ScreenRegister extends StatefulWidget {
  final VoidCallback onRegisterSuccess;
  final VoidCallback onGoToLogin;

  const ScreenRegister({
    super.key,
    required this.onRegisterSuccess,
    required this.onGoToLogin,
  });

  @override
  State<ScreenRegister> createState() => _ScreenRegisterState();
}

class _ScreenRegisterState extends State<ScreenRegister> {
  final _emailCtrl    = TextEditingController();
  final _pwCtrl       = TextEditingController();
  final _pw2Ctrl      = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure  = true;
  bool _obscure2 = true;
  String _identity = '학생';
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.instance.register(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        nickname: _nicknameCtrl.text.trim(),
        identity: _identity,
      );
      widget.onRegisterSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 400
          ? '이미 사용 중인 이메일이에요'
          : '회원가입 중 오류가 발생했어요 (${e.statusCode})');
    } catch (_) {
      setState(() => _error = '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── 상단 바 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: kInk2),
                    onPressed: widget.onGoToLogin,
                  ),
                  const Text('회원가입',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        letterSpacing: -0.3,
                      )),
                ],
              ),
            ),

            // ─── 폼 ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 에러
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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

                      // 이메일
                      _label('이메일'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: _textStyle,
                        decoration: _deco('example@email.com'),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? '올바른 이메일을 입력해주세요'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // 닉네임
                      _label('닉네임'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nicknameCtrl,
                        textInputAction: TextInputAction.next,
                        style: _textStyle,
                        decoration: _deco('앱에서 사용할 이름'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '닉네임을 입력해주세요'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // 비밀번호
                      _label('비밀번호'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pwCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        style: _textStyle,
                        decoration: _deco('6자 이상').copyWith(
                          suffixIcon: _eyeBtn(
                              _obscure, () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? '6자 이상 입력해주세요'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // 비밀번호 확인
                      _label('비밀번호 확인'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pw2Ctrl,
                        obscureText: _obscure2,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _register(),
                        style: _textStyle,
                        decoration: _deco('비밀번호 재입력').copyWith(
                          suffixIcon: _eyeBtn(
                              _obscure2, () => setState(() => _obscure2 = !_obscure2)),
                        ),
                        validator: (v) => v != _pwCtrl.text
                            ? '비밀번호가 일치하지 않아요'
                            : null,
                      ),
                      const SizedBox(height: 22),

                      // 신분 선택
                      _label('신분'),
                      const SizedBox(height: 10),
                      Row(
                        children: ['학생', '직장인'].map((opt) {
                          return Expanded(
                            child: Padding(
                              padding: opt == '학생'
                                  ? const EdgeInsets.only(right: 4)
                                  : const EdgeInsets.only(left: 4),
                              child: GridSelectButton(
                                label: opt,
                                active: _identity == opt,
                                onTap: () => setState(() => _identity = opt),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // 회원가입 버튼
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
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
                              : const Text('가입하기',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  )),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 로그인으로
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('이미 계정이 있으신가요?',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                color: kInk3,
                              )),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: widget.onGoToLogin,
                            child: const Text('로그인',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kBrand,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kInk,
      ));

  Widget _eyeBtn(bool obscure, VoidCallback onTap) => IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20, color: kInk3,
        ),
        onPressed: onTap,
      );

  static const _textStyle = TextStyle(fontFamily: 'Pretendard', fontSize: 15);

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: kInk3),
        filled: true,
        fillColor: kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kHair)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kHair)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrand, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      );
}
