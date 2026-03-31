import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import 'email_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  static const _commonPasswords = {
    '12345678', 'password', 'qwerty123', '11111111', 'abcdefgh',
    'password1', '123456789',
  };

  bool get _hasLength => _passwordCtrl.text.length >= 8;
  bool get _hasUpper => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _passwordCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _notCommon => !_commonPasswords.contains(_passwordCtrl.text.toLowerCase());

  bool get _passwordOk =>
      _hasLength && _hasUpper && _hasLower && _hasDigit && _notCommon;

  void _validateAndRegister() {
    setState(() => _errors.clear());

    bool hasError = false;

    if (_displayNameCtrl.text.trim().isEmpty) {
      _errors['display_name'] = 'Display name is required';
      hasError = true;
    }

    if (_usernameCtrl.text.trim().length < 3) {
      _errors['username'] = 'Username must be at least 3 characters';
      hasError = true;
    }

    if (_emailCtrl.text.trim().isEmpty) {
      _errors['email'] = 'Email is required';
      hasError = true;
    } else if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$')
        .hasMatch(_emailCtrl.text.trim())) {
      _errors['email'] = 'Enter a valid email address';
      hasError = true;
    }

    if (!_passwordOk) {
      _errors['password'] = 'Password must be at least 8 characters and include uppercase, lowercase, and a number';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    _register();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().register(
          email: _emailCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: _displayNameCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
                email: _emailCtrl.text.trim(),
              )));
    } else {
      showErrorSnackBar(
          context, context.read<AuthProvider>().error ?? 'Registration failed');
    }
  }

  int get _passwordStrength {
    final p = _passwordCtrl.text;
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[a-z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08080f), Color(0xFF150825), Color(0xFF08080f)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
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
                const SizedBox(height: 16),
                // Step dots
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StepDot(state: _DotState.done),
                  const SizedBox(width: 6),
                  _StepDot(state: _DotState.active),
                  const SizedBox(width: 6),
                  _StepDot(state: _DotState.inactive),
                ]),
                const SizedBox(height: 24),
                Text('Create your account',
                    style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 4),
                Text('Step 1 of 3 — Personal details',
                    style:
                        GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                const SizedBox(height: 24),

                _buildField(_displayNameCtrl, 'DISPLAY NAME',
                    hint: 'Your name', errorKey: 'display_name'),
                const SizedBox(height: 12),
                _buildField(_usernameCtrl, 'USERNAME',
                    hint: '@username', errorKey: 'username'),
                const SizedBox(height: 12),
                _buildField(_emailCtrl, 'EMAIL',
                    hint: 'your@email.com',
                    keyboardType: TextInputType.emailAddress,
                    errorKey: 'email'),
                const SizedBox(height: 12),

                // Password with strength indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PASSWORD',
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
                        border: Border.all(
                          color: _errors['password'] != null
                              ? const Color(0xFFef4444)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: AppColors.text3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              onChanged: (_) => setState(() {
                                _errors.remove('password');
                              }),
                              style: GoogleFonts.outfit(
                                  fontSize: 15, color: AppColors.text),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: GoogleFonts.outfit(
                                    fontSize: 15, color: AppColors.text3),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _obscure = !_obscure),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 16,
                                color: AppColors.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errors['password'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: Color(0xFFef4444)),
                          const SizedBox(width: 4),
                          Text(_errors['password']!,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFFef4444))),
                        ]),
                      ),
                    if (_passwordCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                          children: List.generate(
                              4,
                              (i) => Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: EdgeInsets.only(
                                          right: i < 3 ? 4 : 0),
                                      decoration: BoxDecoration(
                                        color: i < _passwordStrength
                                            ? (_passwordStrength == 4
                                                ? const Color(0xFF16a34a)
                                                : _passwordStrength >= 3
                                                    ? const Color(0xFF22c55e)
                                                    : _passwordStrength >= 2
                                                        ? const Color(0xFFf59e0b)
                                                        : const Color(0xFFef4444))
                                            : AppColors.surface3,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                    ),
                                  ))),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _passwordStrength == 4 ? 'Strong' :
                            _passwordStrength == 3 ? 'Good' :
                            _passwordStrength == 2 ? 'Fair' : 'Weak',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _passwordStrength == 4
                                  ? const Color(0xFF16a34a)
                                  : _passwordStrength == 3
                                      ? const Color(0xFF22c55e)
                                      : _passwordStrength == 2
                                          ? const Color(0xFFf59e0b)
                                          : const Color(0xFFef4444),
                            ),
                          ),
                          if (_passwordStrength < 3)
                            Text(
                              'Cannot submit yet',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: AppColors.text3),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _PasswordCondition(met: _hasLength, label: 'At least 8 characters'),
                      _PasswordCondition(met: _hasUpper, label: 'Uppercase letter (A-Z)'),
                      _PasswordCondition(met: _hasLower, label: 'Lowercase letter (a-z)'),
                      _PasswordCondition(met: _hasDigit, label: 'At least one number (0-9)'),
                    ],
                  ],
                ),

                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _loading ? null : _validateAndRegister,
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
                                    strokeWidth: 2, color: Colors.white)))
                        : Text('Create Account →',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String hint = '',
    TextInputType? keyboardType,
    String? errorKey,
  }) {
    final hasError = errorKey != null && _errors[errorKey] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            border: Border.all(
                color:
                    hasError ? const Color(0xFFef4444) : AppColors.border),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
            onChanged: (_) {
              if (errorKey != null && _errors[errorKey] != null) {
                setState(() => _errors.remove(errorKey));
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
              border: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Color(0xFFef4444)),
              const SizedBox(width: 4),
              Text(_errors[errorKey]!,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: const Color(0xFFef4444))),
            ]),
          ),
      ],
    );
  }
}

class _PasswordCondition extends StatelessWidget {
  final bool met;
  final String label;
  const _PasswordCondition({required this.met, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 13,
          color: met ? const Color(0xFF22c55e) : AppColors.text3,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: met ? const Color(0xFF22c55e) : AppColors.text3)),
      ]),
    );
  }
}

enum _DotState { done, active, inactive }

class _StepDot extends StatelessWidget {
  final _DotState state;
  const _StepDot({required this.state});
  @override
  Widget build(BuildContext context) {
    final width = state == _DotState.done
        ? 20.0
        : state == _DotState.active
            ? 14.0
            : 7.0;
    final color = state == _DotState.inactive
        ? AppColors.surface3
        : state == _DotState.active
            ? AppColors.purpleLight
            : AppColors.purple;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: 7,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
    );
  }
}
