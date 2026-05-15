import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/moodwave_brand.dart';
import 'genre_select_screen.dart';
import 'main/main_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeController.dispose();
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
      final user = context.read<AuthProvider>().user;
      final hasCity = (user?['city'] as String?)?.isNotEmpty == true;
      Navigator.of(context).pushReplacement(
        smoothPageRoute(
          hasCity ? const MainScreen() : const GenreSelectScreen(),
        ),
      );
    } else {
      showErrorSnackBar(
          context, context.read<AuthProvider>().error ?? 'Login failed');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      UserCredential userCred;

      if (kIsWeb) {
        // Web: Firebase popup — no google_sign_in needed
        final provider = GoogleAuthProvider();
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Mobile: google_sign_in → Firebase credential
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _googleLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final firebaseToken = await userCred.user?.getIdToken();
      if (firebaseToken == null) throw Exception('No token');

      if (!mounted) return;
      final ok =
          await context.read<AuthProvider>().loginWithGoogle(firebaseToken);
      if (!mounted) return;
      setState(() => _googleLoading = false);
      if (ok) {
        final needsOnboarding =
            context.read<AuthProvider>().status == AuthStatus.unauthenticated;
        Navigator.of(context).pushReplacement(
          smoothPageRoute(
            needsOnboarding ? const GenreSelectScreen() : const MainScreen(),
          ),
        );
      } else {
        showErrorSnackBar(context,
            context.read<AuthProvider>().error ?? 'Google sign in failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _googleLoading = false);
        showErrorSnackBar(context, 'Google sign in failed');
      }
    }
  }

  bool get _anyLoading => _loading || _googleLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.authBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MoodWaveLogoMark(size: 110, radius: 32, glow: 1.1),
                      const SizedBox(height: 14),
                      Text('MoodWave',
                          style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 28),
                      Text('Welcome back',
                          style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      const SizedBox(height: 6),
                      Text('Sign in to your account',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: AppColors.text2)),
                      const SizedBox(height: 28),
                      _SocialButton(
                        loading: _googleLoading,
                        disabled: _anyLoading,
                        onTap: _signInWithGoogle,
                        icon: const _GoogleMark(size: 18),
                        label: 'Continue with Google',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: AppColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                          ),
                          const Expanded(
                              child: Divider(color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildField(
                        controller: _emailCtrl,
                        label: 'EMAIL',
                        icon: Icons.email_outlined,
                        hint: 'your@email.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _passwordCtrl,
                        label: 'PASSWORD',
                        icon: Icons.lock_outline_rounded,
                        hint: '••••••••',
                        obscure: _obscure,
                        trailing: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.text3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              smoothPageRoute(const ForgotPasswordScreen())),
                          child: Text('Forgot password?',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.purpleLight)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _anyLoading ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: _loading
                                ? const LinearGradient(colors: [
                                    Color(0xFF3d1a6e),
                                    Color(0xFF3d1a6e)
                                  ])
                                : AppColors.authCta,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.pink.withValues(alpha: 0.28),
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
                              : Text('Sign In',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          smoothPageRoute(const SignUpScreen()),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppColors.text2),
                            children: [
                              const TextSpan(text: 'New to MoodWave? '),
                              TextSpan(
                                text: 'Create account',
                                style: GoogleFonts.outfit(
                                    color: AppColors.purpleLight,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
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
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style:
                      GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(
                        fontSize: 15, color: AppColors.text3),
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

class _GoogleMark extends StatelessWidget {
  final double size;

  const _GoogleMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    void drawArc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(arcRect, start, sweep, false, paint);
    }

    drawArc(const Color(0xFF4285F4), -0.12, 1.45);
    drawArc(const Color(0xFF34A853), 1.33, 1.18);
    drawArc(const Color(0xFFFBBC05), 2.51, 1.02);
    drawArc(const Color(0xFFEA4335), 3.53, 1.46);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    final y = size.height * 0.52;
    canvas.drawLine(
      Offset(size.width * 0.53, y),
      Offset(size.width * 0.92, y),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SocialButton extends StatelessWidget {
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  final Widget icon;
  final String label;

  const _SocialButton({
    required this.loading,
    required this.disabled,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF25182F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                ],
              ),
      ),
    );
  }
}
