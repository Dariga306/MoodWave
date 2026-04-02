import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import 'main/main_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('8') && digits.length == 11) return '+7${digits.substring(1)}';
    if (digits.startsWith('7') && digits.length == 11) return '+$digits';
    return digits;
  }

  Future<void> _sendCode() async {
    final phone = _normalizePhone(_phoneCtrl.text.trim());
    if (phone.isEmpty) {
      showErrorSnackBar(context, 'Enter your phone number');
      return;
    }
    if (!phone.startsWith('+')) {
      showErrorSnackBar(context, 'Enter number with country code, e.g. +7 705 883 36 50');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone, // already normalized to +7...
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _loading = false);
            showErrorSnackBar(context, e.message ?? 'Phone verification failed');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _loading = false;
              _codeSent = true;
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, 'Failed to send code. Check phone number format (+7...)');
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      showErrorSnackBar(context, 'Enter the 6-digit code');
      return;
    }
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, e.message ?? 'Invalid code');
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseToken = await userCred.user?.getIdToken();
      if (firebaseToken == null) throw Exception('No token');

      if (!mounted) return;
      final ok = await context.read<AuthProvider>().loginWithFirebasePhone(firebaseToken);
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      } else {
        showErrorSnackBar(context, context.read<AuthProvider>().error ?? 'Sign in failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, 'Sign in failed');
      }
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
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 30)
                    ],
                  ),
                  child: const Icon(Icons.phone_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  _codeSent ? 'Enter the code' : 'Phone sign in',
                  style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'We sent a 6-digit code to ${_phoneCtrl.text.trim()}'
                      : 'Enter your phone number with country code',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2),
                ),
                const SizedBox(height: 36),
                if (!_codeSent) ...[
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'PHONE NUMBER',
                    hint: '+7 777 123 45 67',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ] else ...[
                  _buildField(
                    controller: _codeCtrl,
                    label: 'VERIFICATION CODE',
                    hint: '123456',
                    icon: Icons.lock_outline_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _loading ? null : _sendCode,
                    child: Text(
                      'Resend code',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.purpleLight),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _loading ? null : (_codeSent ? _verifyCode : _sendCode),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: _loading
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
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : Text(
                            _codeSent ? 'Verify' : 'Send code',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Back to sign in',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.purpleLight),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text3,
                letterSpacing: 0.06)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, size: 18, color: AppColors.text3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }
}
