import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../chat_screen.dart';
import '../group_chat_setup_screen.dart';
import '../social_activity_screen.dart';

class SocialTab extends StatefulWidget {
  const SocialTab({super.key});
  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _liveActivityCount = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadActivityBadge();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static const _labels = ['Chats', 'Matching'];
  static const _icons = [
    Icons.chat_bubble_rounded,
    Icons.favorite_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: const [
                _ChatsView(),
                _MatchView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _headerActionButton(
                    icon: Icons.headphones_rounded,
                    iconSize: 20,
                    badgeText:
                        _liveActivityCount > 0 ? '$_liveActivityCount' : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SocialActivityScreen(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _headerActionButton(
                    icon: Icons.edit_rounded,
                    iconSize: 20,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _NewMessageScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const outerPadding = 4.0;
                  final tabWidth =
                      (constraints.maxWidth - outerPadding * 2) / 2;
                  return Container(
                    height: 50,
                    padding: const EdgeInsets.all(outerPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: _tab.index * tabWidth,
                          top: 0,
                          width: tabWidth,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFF7c3aed), Color(0xFFec4899)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple.withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(
                            2,
                            (i) => Expanded(
                              child: _SegTab(
                                label: _labels[i],
                                icon: _icons[i],
                                active: _tab.index == i,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _tab.animateTo(i);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required double iconSize,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: AppColors.purpleLight,
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.bg, width: 1.5),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadActivityBadge() async {
    try {
      final data = await ApiService().getFriendsActivity();
      final live = (data['live'] as List?) ?? const [];
      if (!mounted) return;
      setState(() => _liveActivityCount = live.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveActivityCount = 0);
    }
  }
}

class _RecommendationSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final int? openingUserId;
  final void Function(Map<String, dynamic>) onTap;

  const _RecommendationSection({
    required this.title,
    required this.users,
    required this.openingUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        ...users.map((u) {
          final name =
              (u['display_name'] ?? u['username'] ?? 'User').toString();
          final username = (u['username'] ?? '').toString();
          final avatarUrl = (u['avatar_url'] ?? '').toString();
          final userId = (u['id'] as num?)?.toInt();
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          final opening = userId != null && openingUserId == userId;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradMixed,
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            title: Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            subtitle: username.isNotEmpty
                ? Text(
                    '@$username',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  )
                : null,
            trailing: opening
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.text3,
                  ),
            onTap: () => onTap(u),
          );
        }),
      ],
    );
  }
}

// ─── Segmented tab pill ───────────────────────────────────────────────────────

class _SegTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _SegTab(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15, color: active ? Colors.white : AppColors.text3),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.text3)),
          ],
        ),
      ),
    );
  }
}

// ─── Match View ───────────────────────────────────────────────────────────────

class _MatchView extends StatefulWidget {
  const _MatchView();
  @override
  State<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<_MatchView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _candidates = [];
  int _idx = 0;
  bool _loading = true;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getMatchCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = data;
        _idx = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _current =>
      _candidates.isNotEmpty && _idx < _candidates.length
          ? _candidates[_idx] as Map<String, dynamic>
          : null;

  int get _remaining =>
      _candidates.length > _idx + 1 ? _candidates.length - _idx - 1 : 0;

  Future<void> _decide(String decision) async {
    if (_deciding || _current == null) return;
    HapticFeedback.mediumImpact();
    final candidate = Map<String, dynamic>.from(_current!);
    final userId = candidate['user_id'] as int;
    setState(() => _deciding = true);
    try {
      final result = await ApiService().decideMatch(userId, decision);
      if (!mounted) return;
      if (result['is_mutual'] == true) {
        await _showMutualDialog(candidate, result['match_id'] as int? ?? 0);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _deciding = false;
      _idx++;
    });
  }

  Future<void> _showMutualDialog(
      Map<String, dynamic> candidate, int matchId) async {
    final name = candidate['display_name'] ?? candidate['username'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: AppColors.purple.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.purple.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: -4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1a0533), Color(0xFF0d1a3d)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.gradMixed,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.purple.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 4)
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradMixed,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 2),
                        ),
                        child: Center(
                            child: Text(initial,
                                style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.titleGradient.createShader(b),
                      child: Text("It's a Match!",
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    Text("$name liked you back",
                        style: GoogleFonts.outfit(
                            fontSize: 15, color: AppColors.text2)),
                    const SizedBox(height: 4),
                    Text("You share music taste ✨",
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.text3)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                    matchId: matchId,
                                    partnerName: name,
                                    partnerId:
                                        candidate['user_id'] as int? ?? 0,
                                    partnerAvatarUrl:
                                        (candidate['avatar_url'] ?? '')
                                            .toString())));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryBtn,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.purple.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: Text('Start Chat',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('Maybe later',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text2)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight));
    }
    if (_current == null) {
      return _buildEmpty();
    }
    return _buildCard(_current!);
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purple.withOpacity(0.4), blurRadius: 30)
                ],
              ),
              child: const Center(
                  child: Text('🎵', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 20),
            Text('No matches right now',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            Text('Listen to more music to find people\nwith similar taste',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.text2, height: 1.5)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryBtn,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.purple.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Text('Try again',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final name = c['display_name'] ?? c['username'] ?? 'User';
    final city = (c['city'] as String?) ?? '';
    final similarity = c['similarity_pct'] ?? 0;
    final icebreaker = c['icebreaker'] ?? 'You have similar music taste!';
    final genres = (c['top_genres'] as List?)?.cast<String>() ??
        (c['genres'] as List?)?.cast<String>() ??
        [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          if (_remaining > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('$_remaining more people waiting',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
            ),
          // Main card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: AppColors.purple.withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 48,
                    offset: const Offset(0, 24)),
                BoxShadow(
                    color: AppColors.purple.withOpacity(0.08), blurRadius: 40),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero gradient section
                Container(
                  height: 210,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1a0533),
                        Color(0xFF0d1a3d),
                        Color(0xFF1a0533),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Glow overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.purple.withOpacity(0.15),
                                Colors.transparent,
                              ],
                              radius: 0.8,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      // City badge
                      if (city.isNotEmpty)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF22c55e),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(city,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.85))),
                            ]),
                          ),
                        ),
                      // Avatar with glow ring
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.purple.withOpacity(0.5),
                                      blurRadius: 35,
                                      spreadRadius: 2)
                                ],
                              ),
                            ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 3),
                              ),
                              child: Center(
                                child: Text(initial,
                                    style: GoogleFonts.outfit(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Card body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + match %
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text)),
                                if (city.isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 13, color: AppColors.text3),
                                    const SizedBox(width: 3),
                                    Text(city,
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text3)),
                                  ]),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.purple.withOpacity(0.2),
                                  AppColors.pink.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.purple.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      const LinearGradient(colors: [
                                    AppColors.purpleLight,
                                    AppColors.pink,
                                  ]).createShader(b),
                                  child: Text('$similarity%',
                                      style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                                Text('match',
                                    style: GoogleFonts.outfit(
                                        fontSize: 10, color: AppColors.text3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Icebreaker
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.music_note_rounded,
                                size: 16, color: AppColors.purpleLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(icebreaker,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      height: 1.55,
                                      color: AppColors.text2)),
                            ),
                          ],
                        ),
                      ),
                      // Genre chips
                      if (genres.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: genres.take(5).map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  AppColors.purple.withOpacity(0.15),
                                  AppColors.purpleDark.withOpacity(0.1),
                                ]),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: AppColors.purple.withOpacity(0.25)),
                              ),
                              child: Text(g,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.purpleLight)),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _deciding ? null : () => _decide('like'),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: AppColors.gradPurple,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.purpleDark
                                          .withOpacity(0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_deciding)
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                  else ...[
                                    const Icon(Icons.favorite_rounded,
                                        size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Like',
                                        style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _deciding ? null : () => _decide('skip'),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.close_rounded,
                                      size: 18, color: Color(0xFFf87171)),
                                  const SizedBox(width: 8),
                                  Text('Pass',
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hint row
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hintChip('✕', false),
              const SizedBox(width: 16),
              Text('Tap to decide',
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              const SizedBox(width: 16),
              _hintChip('♥', true),
            ],
          ),
          if (_remaining > 0) ...[
            const SizedBox(height: 8),
            Text('$_remaining more waiting...',
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _load,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    size: 14, color: AppColors.text3),
                const SizedBox(width: 4),
                Text('Refresh',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintChip(String symbol, bool isLike) {
    final color = isLike ? const Color(0xFF22c55e) : const Color(0xFFf87171);
    return Row(
      children: [
        if (!isLike) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2))),
            child: Center(
                child:
                    Text(symbol, style: TextStyle(fontSize: 13, color: color))),
          ),
          const SizedBox(width: 5),
          Text('Pass',
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ] else ...[
          Text('Like',
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
          const SizedBox(width: 5),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2))),
            child: Center(
                child:
                    Text(symbol, style: TextStyle(fontSize: 13, color: color))),
          ),
        ],
      ],
    );
  }
}

// ─── Chats View ───────────────────────────────────────────────────────────────

class _ChatsView extends StatefulWidget {
  const _ChatsView();
  @override
  State<_ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<_ChatsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _chats = [];
  List<Map<String, dynamic>> _liveList = [];
  Map<int, Map<String, dynamic>> _liveActivityByUser = {};
  final Set<String> _hiddenChatKeys = {};
  final Set<String> _mutedChatKeys = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getChats();
      Map<int, Map<String, dynamic>> liveMap = {};
      List<Map<String, dynamic>> liveList = [];
      try {
        final activity = await ApiService().getFriendsActivity();
        final live = (activity['live'] as List?) ?? const [];
        for (final item in live.whereType<Map>()) {
          final row = Map<String, dynamic>.from(item);
          final id = (row['id'] as num?)?.toInt();
          if (id != null) liveMap[id] = row;
          liveList.add(row);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _chats = data;
        _liveActivityByUser = liveMap;
        _liveList = liveList;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chats = [];
        _liveActivityByUser = {};
        _liveList = [];
        _loading = false;
      });
    }
  }

  String _chatKey(Map<String, dynamic> chat) {
    final gid = chat['group_chat_id'];
    final cid = chat['chat_id'];
    final mid = chat['match_id'];
    if (gid != null) return 'g:$gid';
    if (cid != null) return 'c:$cid';
    return 'm:$mid';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight));
    }
    final visibleChats = _chats
        .where((c) => !_hiddenChatKeys.contains(
            _chatKey(Map<String, dynamic>.from(c as Map))))
        .toList();
    if (visibleChats.isEmpty && _liveList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                    child: Text('💬', style: TextStyle(fontSize: 34))),
              ),
              const SizedBox(height: 20),
              Text('No chats yet',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text('Match with someone to start chatting',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.text2, height: 1.5)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.purpleLight,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Live friends row
          if (_liveList.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Listening now',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text2,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _liveList.length,
                        itemBuilder: (_, i) =>
                            _LiveMiniCard(friend: _liveList[i]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0x0DFFFFFF), height: 1),
                  ],
                ),
              ),
            ),
          // Chat list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final chat =
                      Map<String, dynamic>.from(visibleChats[i] as Map);
                  final partner =
                      (chat['partner'] as Map<String, dynamic>?) ?? const {};
                  final partnerId = (partner['id'] as num?)?.toInt();
                  final key = _chatKey(chat);
                  return _ChatItem(
                    chat: chat,
                    activity:
                        partnerId == null ? null : _liveActivityByUser[partnerId],
                    isMuted: _mutedChatKeys.contains(key),
                    onHide: () => setState(() => _hiddenChatKeys.add(key)),
                    onToggleMute: () => setState(() {
                      if (_mutedChatKeys.contains(key)) {
                        _mutedChatKeys.remove(key);
                      } else {
                        _mutedChatKeys.add(key);
                      }
                    }),
                  );
                },
                childCount: visibleChats.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  final Map<String, dynamic>? activity;
  final bool isMuted;
  final VoidCallback? onHide;
  final VoidCallback? onToggleMute;
  const _ChatItem({
    required this.chat,
    this.activity,
    this.isMuted = false,
    this.onHide,
    this.onToggleMute,
  });

  static String _cleanPreview(String? raw, String? type, String? timeStr) {
    if (raw == null || raw.isEmpty) {
      return timeStr != null ? 'Tap to start 🎵' : 'New match!';
    }
    if (type == 'track') return raw;
    final t = raw.trim();
    if (t.startsWith('💬') || t.contains('создал') || t.contains('group chat') || t.contains('created a group')) {
      return '💬 Group invite';
    }
    if (t.contains('Listening room') || t.contains('MW-') || t.contains('Invite code')) {
      return '🎵 Room invite';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final matchId = chat['match_id'] as int?;
    final chatId = chat['chat_id'] as int?;
    final groupChatId = chat['group_chat_id'] as int?;
    final chatKind = (chat['chat_kind'] ?? 'direct').toString();
    final memberCount = (chat['member_count'] as num?)?.toInt() ?? 0;
    final partner =
        (chat['partner'] as Map<String, dynamic>?) ?? {'display_name': 'User'};
    final name = partner['display_name'] ??
        partner['first_name'] ??
        partner['username'] ??
        'User';
    final city = (partner['city'] as String?) ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final preview = chat['last_message_preview'] as String?;
    final previewType = chat['last_message_type'] as String?;
    final timeStr =
        chat['last_message_at'] as String? ?? chat['created_at'] as String?;
    final nowPlaying =
        (activity?['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final isLiveNow = nowPlaying.isNotEmpty;
    final liveTitle = (nowPlaying['title'] ?? '').toString().trim();
    final liveArtist = (nowPlaying['artist'] ?? '').toString().trim();

    final previewText = _ChatItem._cleanPreview(preview, previewType, timeStr);
    final isTrackPreview = previewType == 'track';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                  matchId: matchId,
                  chatId: chatId,
                  groupChatId: groupChatId,
                  partnerName: name,
                  partnerId: partner['id'] as int? ?? 0,
                  partnerAvatarUrl: (partner['avatar_url'] ?? '').toString()))),
      onLongPress: () => _showChatOptions(context, name),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF)))),
          child: Row(children: [
            // Avatar with optional glow for new chats
            Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.3),
                      blurRadius: 12)
                ],
              ),
              child: (partner['avatar_url']?.toString().isNotEmpty ?? false)
                  ? Image.network(
                      partner['avatar_url'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))),
            ),
            if (isLiveNow)
              Transform.translate(
                offset: const Offset(-14, 16),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.purple.withOpacity(0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withOpacity(0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 12,
                      color: AppColors.purpleLight,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // Name + preview
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    if (chatKind == 'group')
                      Text(
                        memberCount > 0 ? '$memberCount members' : 'Group chat',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.text3),
                      )
                    else if (city.isNotEmpty)
                      Text(city,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.text3)),
                    const SizedBox(height: 3),
                    if (isLiveNow)
                      Row(
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            size: 12,
                            color: AppColors.purpleLight,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                if (liveTitle.isNotEmpty) liveTitle,
                                if (liveArtist.isNotEmpty) liveArtist,
                              ].join(' • ').isNotEmpty
                                  ? [
                                      if (liveTitle.isNotEmpty) liveTitle,
                                      if (liveArtist.isNotEmpty) liveArtist,
                                    ].join(' • ')
                                  : 'Listening now',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purpleLight,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        isTrackPreview ? previewText : previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isTrackPreview
                                ? AppColors.purpleLight
                                : AppColors.text3),
                      ),
                    if (isLiveNow) ...[
                      const SizedBox(height: 3),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.text3,
                        ),
                      ),
                    ],
                  ]),
            ),
            // Time
            if (timeStr != null) ...[
              const SizedBox(width: 8),
              Text(_relTime(timeStr),
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
            ],
          ]),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, String chatName) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              chatName,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _sheetOption(
              icon: isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              label: isMuted ? 'Unmute' : 'Mute',
              color: AppColors.text,
              onTap: () {
                Navigator.pop(context);
                onToggleMute?.call();
              },
            ),
            const SizedBox(height: 8),
            _sheetOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete chat',
              color: const Color(0xFFf87171),
              onTap: () {
                Navigator.pop(context);
                onHide?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }
}

// ─── Live Mini Card ───────────────────────────────────────────────────────────

class _LiveMiniCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _LiveMiniCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final name =
        (friend['display_name'] ?? friend['username'] ?? 'User').toString();
    final avatar = (friend['avatar_url'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final nowPlaying =
        (friend['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final title = (nowPlaying['title'] ?? '').toString().trim();

    return Container(
      width: 62,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.purpleLight.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: avatar.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.pink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.purpleLight,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── New Message Screen ───────────────────────────────────────────────────────

class _NewMessageScreen extends StatefulWidget {
  const _NewMessageScreen();

  @override
  State<_NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<_NewMessageScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _recommended = [];
  bool _loading = true;
  int? _openingUserId;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = context.read<AuthProvider>().user;
      final myId = (me?['id'] as num?)?.toInt() ?? 0;
      final following = await ApiService().getUserFollowing(myId, limit: 100);
      final recommended = await _buildRecommendations(myId, following);
      if (!mounted) return;
      setState(() {
        _users = following;
        _filtered = following;
        _recommended = recommended;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _buildRecommendations(
    int myId,
    List<Map<String, dynamic>> following,
  ) async {
    final seen = <int>{myId};
    final recommendations = <Map<String, dynamic>>[];

    void addUser(Map<String, dynamic> user) {
      final id = (user['id'] as num?)?.toInt();
      if (id == null || seen.contains(id)) return;
      seen.add(id);
      recommendations.add(user);
    }

    for (final user in following) {
      final id = (user['id'] as num?)?.toInt();
      if (id != null) seen.add(id);
    }

    try {
      final history = await ApiService().getSearchHistory(limit: 12);
      for (final item in history.where((entry) =>
          entry['result_type']?.toString().toLowerCase() == 'profile')) {
        final id = int.tryParse((item['result_id'] ?? '').toString());
        if (id == null || seen.contains(id)) continue;
        try {
          final summary = await ApiService().getUserProfileSummary(
            id,
            playlistLimit: 0,
            tracksLimit: 0,
          );
          addUser({
            'id': id,
            'display_name':
                (summary['display_name'] ?? summary['username'] ?? 'User')
                    .toString(),
            'username': (summary['username'] ?? '').toString(),
            'avatar_url': (summary['avatar_url'] ?? '').toString(),
          });
        } catch (_) {}
      }
    } catch (_) {}

    for (final followed in following.take(8)) {
      final followedId = (followed['id'] as num?)?.toInt();
      if (followedId == null) continue;
      try {
        final secondDegree =
            await ApiService().getUserFollowing(followedId, limit: 10);
        for (final user in secondDegree) {
          addUser(user);
          if (recommendations.length >= 12) break;
        }
      } catch (_) {}
      if (recommendations.length >= 12) break;
    }

    return recommendations;
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      setState(() => _filtered = _users);
      return;
    }
    setState(() => _filtered = []);
    _searchDebounce = Timer(const Duration(milliseconds: 240), () async {
      final remote = await ApiService().searchUsers(q, limit: 24);
      if (!mounted || _searchCtrl.text.trim().toLowerCase() != q) return;
      setState(() {
        _filtered = remote;
      });
    });
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    final userId = (user['id'] as num?)?.toInt();
    if (userId == null || _openingUserId != null) return;
    setState(() => _openingUserId = userId);
    try {
      final result = await ApiService().startDirectChat(userId);
      if (!mounted) return;
      final chatId = result['chat_id'] as int?;
      final partnerId = (result['partner']?['id'] as num?)?.toInt() ?? userId;
      final partnerName = result['partner']?['display_name']?.toString() ??
          result['partner']?['username']?.toString() ??
          (user['display_name'] ?? user['username'] ?? 'User').toString();
      final avatarUrl = result['partner']?['avatar_url']?.toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            partnerName: partnerName,
            partnerId: partnerId,
            partnerAvatarUrl: avatarUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingUserId = null);
      String msg = 'Could not open chat';
      if (e.toString().contains('403') || e.toString().contains('private')) {
        msg = 'Profile is private — match first to message them';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text('New Message',
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search people...',
                hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.text3),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
        ),
        if (_loading)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight)))
        else if (_filtered.isEmpty &&
            _recommended.isEmpty &&
            _searchCtrl.text.trim().isNotEmpty)
          Expanded(
              child: Center(
                  child: Text('No people found',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: AppColors.text3))))
        else
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupChatSetupScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Group chat',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.text3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_searchCtrl.text.trim().isEmpty && _recommended.isNotEmpty)
                  _RecommendationSection(
                    title: 'Recommendations',
                    users: _recommended,
                    openingUserId: _openingUserId,
                    onTap: _openChat,
                  ),
                _RecommendationSection(
                  title: _searchCtrl.text.trim().isEmpty
                      ? 'People you follow'
                      : 'Results',
                  users: _filtered,
                  openingUserId: _openingUserId,
                  onTap: _openChat,
                ),
              ],
            ),
          ),
      ]),
    );
  }
}
