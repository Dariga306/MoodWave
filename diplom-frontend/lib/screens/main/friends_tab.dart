import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  List<dynamic> _live = [];
  List<dynamic> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getFriendsActivity();
      if (!mounted) return;
      setState(() {
        _live = (data['live'] as List?) ?? [];
        _recent = (data['recent'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Friends Activity',
                          style: GoogleFonts.outfit(
                              fontSize: 26, fontWeight: FontWeight.w800,
                              color: AppColors.text, letterSpacing: -0.02 * 26)),
                      const SizedBox(height: 4),
                      Text("See what's playing right now",
                          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)),
                )
              else if (_live.isEmpty && _recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(children: [
                      const Text('🎵', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No friends activity yet',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                      Text('Add friends to see what they listen to',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                    ]),
                  ),
                )
              else ...[
                // Live now
                if (_live.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _live.map((f) => _buildLiveCard(f as Map<String, dynamic>)).toList(),
                    ),
                  ),
                ],

                // Recently listened
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionHeader(title: 'Recently Listened', action: 'All →', onAction: () {}),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _recent.map((f) => _buildRecentItem(f as Map<String, dynamic>)).toList(),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCard(Map<String, dynamic> friend) {
    final username = friend['display_name'] ?? friend['username'] ?? 'User';
    final nowPlaying = friend['now_playing'] as Map<String, dynamic>?;
    final track = nowPlaying != null
        ? '${nowPlaying['artist'] ?? ''} — ${nowPlaying['title'] ?? ''}'
        : 'Listening now';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.purpleDark.withOpacity(0.12),
            AppColors.pink.withOpacity(0.08),
          ]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                  ),
                  child: Center(child: Text(initial,
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                Positioned(
                  bottom: -3, right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pink,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('LIVE',
                        style: GoogleFonts.outfit(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 0.08)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$username is listening',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text(track,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.purpleLight),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedMusicBars(color1: AppColors.purpleLight, color2: AppColors.pink, maxHeight: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> friend) {
    final username = friend['display_name'] ?? friend['username'] ?? 'User';
    final nowPlaying = friend['now_playing'] as Map<String, dynamic>?;
    final trackStr = nowPlaying != null
        ? '${nowPlaying['artist'] ?? ''} — ${nowPlaying['title'] ?? ''}'
        : 'No recent activity';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Center(child: Text(initial,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(trackStr, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
