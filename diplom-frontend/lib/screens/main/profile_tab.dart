import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../edit_profile_screen.dart';
import '../login_screen.dart';
import '../settings_screen.dart';
import '../stats_screen.dart';
import '../library_screen.dart';
import '../notifications_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int? _songsCount;
  int? _thisMonthCount;
  int? _friendsCount;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService().getUserStats();
      if (!mounted) return;
      setState(() {
        _songsCount = data['songs_count'] as int? ?? 0;
        _thisMonthCount = data['this_month_count'] as int? ?? 0;
        _friendsCount = data['friends_count'] as int? ?? 0;
        _statsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final username = user?['username'] ?? '';
    final city = user?['city'] ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2d0a5e), Color(0xFF1a0440), Color(0xFF0a1040)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 200, height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.purple.withOpacity(0.25),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                        // Settings button
                        Positioned(
                          top: 0, right: 20,
                          child: SafeArea(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.settings_rounded, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar & Edit
                  Positioned(
                    bottom: -36,
                    left: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 3),
                              boxShadow: [
                                BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 24),
                              ],
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (user == null) return;
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(user: user),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text('Edit Profile',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 44),

              // Name & handle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 24, fontWeight: FontWeight.w800,
                            color: AppColors.text, letterSpacing: -0.02 * 24)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('@$username',
                          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('· $city',
                            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3)),
                      ],
                    ]),
                  ],
                ),
              ),

              // Stats
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _StatCell(
                        value: _statsLoaded ? '${_songsCount ?? 0}' : '—',
                        label: 'Songs',
                      )),
                      Container(width: 1, height: 60, color: AppColors.border),
                      Expanded(child: _StatCell(
                        value: _statsLoaded ? '${_thisMonthCount ?? 0}' : '—',
                        label: 'This month',
                      )),
                      Container(width: 1, height: 60, color: AppColors.border),
                      Expanded(child: _StatCell(
                        value: _statsLoaded ? '${_friendsCount ?? 0}' : '—',
                        label: 'Friends',
                      )),
                    ],
                  ),
                ),
              ),

              // Quick access
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('My Pages', style: GoogleFonts.outfit(
                    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _NavRow(icon: '📚', label: 'Library', sub: 'Your playlists & albums',
                      color: AppColors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
                  _NavRow(icon: '📊', label: 'Stats & Wrapped', sub: '2024 year in review',
                      color: AppColors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
                  _NavRow(icon: '🔔', label: 'Notifications', sub: 'Matches, friends, music',
                      color: AppColors.pink, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  _NavRow(icon: '⚙️', label: 'Settings', sub: 'Account, playback, privacy',
                      color: AppColors.text2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                ]),
              ),

              // Logout button
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3d0000).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFef4444).withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFef4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Center(child: Text('🚪', style: TextStyle(fontSize: 18)))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Log Out', style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFFef4444))),
                        Text('Sign out of your account', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                      ])),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.purpleLight, AppColors.pink],
            ).createShader(b),
            child: Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String icon, label, sub;
  final Color color;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.sub,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.outfit(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text(sub, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 20),
        ]),
      ),
    );
  }
}
