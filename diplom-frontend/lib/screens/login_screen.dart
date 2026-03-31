import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import 'main/main_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      showErrorSnackBar(context, 'Please fill in all fields');
      return;
    }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      showErrorSnackBar(
          context, context.read<AuthProvider>().error ?? 'Login failed');
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
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 30)],
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text('MoodWave', style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: AppColors.text, letterSpacing: -0.4)),
                const SizedBox(height: 28),
                Text('Welcome back', style: GoogleFonts.outfit(
                    fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 6),
                Text('Sign in to your account',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                const SizedBox(height: 32),

                // Email field
                _buildField(
                  controller: _emailCtrl,
                  label: 'EMAIL',
                  icon: Icons.email_outlined,
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // Password field
                _buildField(
                  controller: _passwordCtrl,
                  label: 'PASSWORD',
                  icon: Icons.lock_outline_rounded,
                  hint: '••••••••',
                  obscure: _obscure,
                  trailing: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: AppColors.text3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen())),
                    child: Text('Forgot password?',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.purpleLight)),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign In button
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: _loading
                          ? const LinearGradient(colors: [Color(0xFF3d1a6e), Color(0xFF3d1a6e)])
                          : AppColors.primaryBtn,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: AppColors.purpleDark.withOpacity(0.4),
                          blurRadius: 30, offset: const Offset(0, 12))],
                    ),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : Text('Sign In', textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2),
                      children: [
                        const TextSpan(text: 'New to MoodWave? '),
                        TextSpan(
                          text: 'Create account',
                          style: GoogleFonts.outfit(
                              color: AppColors.purpleLight, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.text3, letterSpacing: 0.06)),
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
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 16)],
            ],
          ),
        ),
      ],
    );
  }
}
