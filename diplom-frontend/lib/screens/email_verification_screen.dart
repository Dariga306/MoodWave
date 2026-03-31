import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';
import 'genre_select_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      showErrorSnackBar(context, 'Enter all 6 digits');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().verifyEmail(widget.email, _code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GenreSelectScreen()));
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ApiService().resendVerification(widget.email);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Code sent again');
      _startCountdown();
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08080f), Color(0xFF150825), Color(0xFF0d1328)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Step dots
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _dot(done: true),
                  const SizedBox(width: 6),
                  _dot(active: true),
                  const SizedBox(width: 6),
                  _dot(),
                  const SizedBox(width: 6),
                  _dot(),
                ]),
                const SizedBox(height: 32),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.purpleDark.withOpacity(0.4),
                          blurRadius: 30)
                    ],
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 36, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('Verify your email',
                    style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.text2, height: 1.5),
                ),
                const SizedBox(height: 36),
                // 6 digit boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46,
                      height: 56,
                      margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _ctrls[i].text.isNotEmpty
                              ? AppColors.purple
                              : AppColors.border,
                        ),
                      ),
                      child: TextField(
                        controller: _ctrls[i],
                        focusNode: _nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (v) {
                          setState(() {});
                          if (v.isNotEmpty && i < 5) {
                            _nodes[i + 1].requestFocus();
                          }
                          if (v.isNotEmpty && i == 5) {
                            _nodes[i].unfocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _loading ? null : _verify,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryBtn,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.purpleDark.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 12))
                      ],
                    ),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)))
                        : Text('Verify',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _resendCountdown == 0 ? _resend : null,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend code',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: _resendCountdown == 0
                          ? AppColors.purpleLight
                          : AppColors.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Please verify your account to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.text3),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot({bool done = false, bool active = false}) {
    final w = done ? 20.0 : active ? 14.0 : 7.0;
    final c = done
        ? AppColors.purple
        : active
            ? AppColors.purpleLight
            : AppColors.surface3;
    return Container(
      width: w,
      height: 7,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(100)),
    );
  }
}
