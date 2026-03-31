import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static const _commonPasswords = {
    '12345678', 'password', 'qwerty123', '11111111', 'abcdefgh', 'password1', '123456789',
  };

  bool _isPasswordStrong(String p) {
    if (p.length < 8) return false;
    if (!p.contains(RegExp(r'[A-Z]'))) return false;
    if (!p.contains(RegExp(r'[a-z]'))) return false;
    if (!p.contains(RegExp(r'[0-9]'))) return false;
    if (_commonPasswords.contains(p.toLowerCase())) return false;
    return true;
  }

  Future<void> _changePassword() async {
    if (_currentCtrl.text.isEmpty ||
        _newCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      showErrorSnackBar(context, 'Please fill in all fields');
      return;
    }
    if (!_isPasswordStrong(_newCtrl.text)) {
      showErrorSnackBar(
          context, 'Password must be at least 8 characters and include uppercase, lowercase, and a number');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      showErrorSnackBar(context, 'Passwords do not match');
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      showErrorSnackBar(
          context, 'New password must be different from current');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService()
          .changePassword(_currentCtrl.text, _newCtrl.text);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Password changed successfully!');
      Navigator.of(context).pop();
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
    if (p.contains(RegExp(r'[a-z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
                const SizedBox(width: 12),
                Text('Change Password',
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),

              const SizedBox(height: 32),

              _buildPasswordField('CURRENT PASSWORD', _currentCtrl,
                  _showCurrent,
                  () => setState(() => _showCurrent = !_showCurrent)),
              const SizedBox(height: 14),
              _buildPasswordField('NEW PASSWORD', _newCtrl, _showNew,
                  () => setState(() => _showNew = !_showNew)),
              if (_newCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildStrengthBar(_newCtrl.text),
              ],
              const SizedBox(height: 14),
              _buildPasswordField('CONFIRM NEW PASSWORD', _confirmCtrl,
                  _showConfirm,
                  () => setState(() => _showConfirm = !_showConfirm)),

              const Spacer(),

              GestureDetector(
                onTap: _loading ? null : _changePassword,
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
                      : Text('Update Password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool visible, VoidCallback toggleVisibility) {
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
          controller: controller,
          obscureText: !visible,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle:
                GoogleFonts.outfit(color: AppColors.text3, fontSize: 15),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.text3),
            suffixIcon: GestureDetector(
              onTap: toggleVisibility,
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

  Widget _buildStrengthBar(String password) {
    final s = _strength(password);
    final colors = [
      const Color(0xFFef4444),
      const Color(0xFFf59e0b),
      const Color(0xFF22c55e),
      const Color(0xFF16a34a),
    ];
    final labels = ['Weak', 'Fair', 'Good', 'Strong'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ...List.generate(
            4,
            (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < s ? colors[s - 1] : AppColors.surface3,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                )),
        const SizedBox(width: 8),
        Text(s > 0 ? labels[s - 1] : '',
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: s > 0 ? colors[s - 1] : Colors.transparent)),
      ]),
      const SizedBox(height: 8),
      _pwCondition(password.length >= 8, 'At least 8 characters'),
      _pwCondition(password.contains(RegExp(r'[A-Z]')), 'Uppercase letter (A-Z)'),
      _pwCondition(password.contains(RegExp(r'[a-z]')), 'Lowercase letter (a-z)'),
      _pwCondition(password.contains(RegExp(r'[0-9]')), 'At least one number (0-9)'),
    ]);
  }

  Widget _pwCondition(bool met, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(met ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13, color: met ? const Color(0xFF22c55e) : AppColors.text3),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: met ? const Color(0xFF22c55e) : AppColors.text3)),
      ]),
    );
  }
}
