import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1=email, 2=code, 3=new password
  bool _loading = false;

  // Step 1
  final _emailCtrl = TextEditingController();

  // Step 2
  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus = List.generate(6, (_) => FocusNode());
  String _email = '';

  // Step 3
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  String _resetToken = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      showErrorSnackBar(context, 'Please enter your email');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _email = email;
        _step = 2;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.map((c) => c.text).join();
    if (code.length < 6) {
      showErrorSnackBar(context, 'Please enter the full 6-digit code');
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await ApiService().verifyResetCode(_email, code);
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = 3;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_newPwCtrl.text.length < 8) {
      showErrorSnackBar(context, 'Password must be at least 8 characters');
      return;
    }
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      showErrorSnackBar(context, 'Passwords do not match');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().resetPassword(_resetToken, _newPwCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      showSuccessSnackBar(context, 'Password reset successfully! Please sign in.');
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _strength(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08080f), Color(0xFF150825), Color(0xFF08080f)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () {
                      if (_step > 1) {
                        setState(() => _step--);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ]),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _step == 1
                      ? _StepEmail(
                          key: const ValueKey(1),
                          emailCtrl: _emailCtrl,
                          loading: _loading,
                          onSend: _sendCode,
                        )
                      : _step == 2
                          ? _StepCode(
                              key: const ValueKey(2),
                              email: _email,
                              codeCtrl: _codeCtrl,
                              codeFocus: _codeFocus,
                              loading: _loading,
                              onVerify: _verifyCode,
                              onResend: () async {
                                try {
                                  await ApiService().forgotPassword(_email);
                                  if (mounted) {
                                    showSuccessSnackBar(context, 'Code resent!');
                                  }
                                } catch (_) {}
                              },
                            )
                          : _StepNewPassword(
                              key: const ValueKey(3),
                              newCtrl: _newPwCtrl,
                              confirmCtrl: _confirmPwCtrl,
                              showNew: _showNew,
                              showConfirm: _showConfirm,
                              loading: _loading,
                              strength: _strength(_newPwCtrl.text),
                              onToggleNew: () =>
                                  setState(() => _showNew = !_showNew),
                              onToggleConfirm: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                              onChanged: () => setState(() {}),
                              onReset: _resetPassword,
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Email ──────────────────────────────────────────────────────────

class _StepEmail extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSend;
  const _StepEmail({
    super.key,
    required this.emailCtrl,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_reset_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text('Forgot password?',
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(
              "Enter your email and we'll send you a code to reset your password.",
              style:
                  GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
          const SizedBox(height: 32),
          Text('EMAIL',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 0.08)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const SizedBox(width: 16),
              const Icon(Icons.email_outlined,
                  size: 18, color: AppColors.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: GoogleFonts.outfit(
                        fontSize: 15, color: AppColors.text3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: loading
                    ? const LinearGradient(
                        colors: [Color(0xFF3d1a6e), Color(0xFF3d1a6e)])
                    : AppColors.primaryBtn,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12))
                ],
              ),
              child: loading
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : Text('Send Reset Code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: 6-digit code ───────────────────────────────────────────────────

class _StepCode extends StatelessWidget {
  final String email;
  final List<TextEditingController> codeCtrl;
  final List<FocusNode> codeFocus;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  const _StepCode({
    super.key,
    required this.email,
    required this.codeCtrl,
    required this.codeFocus,
    required this.loading,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text('Check your email',
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.text2),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to '),
                TextSpan(
                    text: email,
                    style: GoogleFonts.outfit(
                        color: AppColors.purpleLight,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (i) => SizedBox(
                width: 46,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: codeCtrl[i],
                    focusNode: codeFocus[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        codeFocus[i + 1].requestFocus();
                      }
                      if (v.isEmpty && i > 0) {
                        codeFocus[i - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: loading ? null : onVerify,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: loading
                    ? const LinearGradient(
                        colors: [Color(0xFF3d1a6e), Color(0xFF3d1a6e)])
                    : AppColors.primaryBtn,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12))
                ],
              ),
              child: loading
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : Text('Verify Code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: onResend,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.text2),
                  children: [
                    const TextSpan(text: "Didn't receive it? "),
                    TextSpan(
                        text: 'Resend code',
                        style: GoogleFonts.outfit(
                            color: AppColors.purpleLight,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: New password ───────────────────────────────────────────────────

class _StepNewPassword extends StatelessWidget {
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool showNew;
  final bool showConfirm;
  final bool loading;
  final int strength;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onChanged;
  final VoidCallback onReset;

  const _StepNewPassword({
    super.key,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.showNew,
    required this.showConfirm,
    required this.loading,
    required this.strength,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFef4444),
      const Color(0xFFf59e0b),
      const Color(0xFF22c55e),
      const Color(0xFF22c55e),
    ];
    final labels = ['Weak', 'Fair', 'Good', 'Strong'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text('New password',
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('Create a strong password for your account.',
              style:
                  GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
          const SizedBox(height: 32),
          _buildPasswordField(
              context, 'NEW PASSWORD', newCtrl, showNew, onToggleNew, onChanged),
          if (newCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              ...List.generate(
                  4,
                  (i) => Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: i < strength
                                ? colors[strength - 1]
                                : AppColors.surface3,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      )),
              const SizedBox(width: 8),
              Text(strength > 0 ? labels[strength - 1] : '',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: strength > 0
                          ? colors[strength - 1]
                          : Colors.transparent)),
            ]),
          ],
          const SizedBox(height: 14),
          _buildPasswordField(context, 'CONFIRM PASSWORD', confirmCtrl,
              showConfirm, onToggleConfirm, onChanged),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: loading ? null : onReset,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: loading
                    ? const LinearGradient(
                        colors: [Color(0xFF3d1a6e), Color(0xFF3d1a6e)])
                    : AppColors.primaryBtn,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12))
                ],
              ),
              child: loading
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : Text('Reset Password',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      BuildContext context,
      String label,
      TextEditingController ctrl,
      bool visible,
      VoidCallback onToggle,
      VoidCallback onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 0.08)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: !visible,
          onChanged: (_) => onChange(),
          style:
              GoogleFonts.outfit(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.outfit(
                color: AppColors.text3, fontSize: 15),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.text3),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.text3),
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    ]);
  }
}
