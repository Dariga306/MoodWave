import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/media_url.dart';
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
  final _chatsViewKey = GlobalKey<_ChatsViewState>();

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
              children: [
                _ChatsView(key: _chatsViewKey),
                const _MatchView(),
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                    onTap: () async {
                      final composeResult =
                          await Navigator.push<Map<String, dynamic>?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _NewMessageScreen(),
                        ),
                      );
                      final chat = composeResult?['chat'];
                      if (chat is Map && mounted) {
                        _chatsViewKey.currentState
                            ?.upsertChat(Map<String, dynamic>.from(chat));
                      }
                      if (mounted) {
                        _chatsViewKey.currentState?.refresh();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const outerPadding = 4.0;
                  final tabWidth =
                      (constraints.maxWidth - outerPadding * 2) / 2;
                  return Container(
                    height: 58,
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
                          height: 50,
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
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
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17, color: active ? Colors.white : AppColors.text3),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 14,
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
  String? _decidingAction;
  bool _matchingEnabled = true;
  bool _seedingDemo = false;
  final TextEditingController _cityCtrl = TextEditingController();
  bool _onlyOnline = false;
  bool _onlyPublic = false;
  bool _excludeHiddenTaste = true;
  double _minSimilarity = 35;
  bool _autoResetAttempted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getMatchCandidates(
        city: _cityCtrl.text,
        onlyOnline: _onlyOnline,
        onlyPublic: _onlyPublic,
        excludeHiddenTaste: _excludeHiddenTaste,
        minSimilarity: _minSimilarity.round(),
      );
      if (!mounted) return;
      setState(() {
        _matchingEnabled = data['matching_enabled'] as bool? ?? true;
        _candidates = (data['candidates'] as List?) ?? [];
        _idx = 0;
        _loading = false;
      });
      if (_matchingEnabled &&
          _candidates.isEmpty &&
          !_autoResetAttempted &&
          !_seedingDemo) {
        _autoResetAttempted = true;
        unawaited(_seedDemoProfiles());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _current =>
      _candidates.isNotEmpty && _idx < _candidates.length
          ? _candidates[_idx] as Map<String, dynamic>
          : null;

  Future<void> _seedDemoProfiles() async {
    if (_seedingDemo) return;
    setState(() => _seedingDemo = true);
    try {
      await ApiService()
          .resetDemoDecisions()
          .catchError((_) => <String, dynamic>{});
      await ApiService().seedDemoMatch();
      _cityCtrl.clear();
      _onlyOnline = false;
      _onlyPublic = false;
      _excludeHiddenTaste = false;
      _minSimilarity = 0;
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add demo profiles',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF3a1b2b),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _seedingDemo = false);
      }
    }
  }

  Future<void> _decide(String decision) async {
    if (_decidingAction != null || _current == null) return;
    HapticFeedback.mediumImpact();
    final candidate = Map<String, dynamic>.from(_current!);
    final userId = candidate['user_id'] as int;
    setState(() => _decidingAction = decision);
    try {
      final result = await ApiService().decideMatch(userId, decision);
      if (!mounted) return;
      if (result['is_mutual'] == true) {
        await _showMutualDialog(candidate, result['match_id'] as int? ?? 0);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _decidingAction = null;
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
    if (!_matchingEnabled) {
      return _buildDisabledState();
    }
    if (_current == null) {
      return _buildEmpty();
    }
    return _buildCard(_current!);
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          _buildFilters(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.all(16),
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
                          color: AppColors.purple.withOpacity(0.4),
                          blurRadius: 30)
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
                Text(
                    'Try lowering the minimum match, typing a city, or adding demo profiles.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.text2, height: 1.5)),
                const SizedBox(height: 28),
                Column(
                  children: [
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
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
                        child: Center(
                          child: Text('Refresh matches',
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _seedingDemo ? null : _seedDemoProfiles,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _seedingDemo
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.purpleLight),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 16, color: AppColors.purpleLight),
                                  const SizedBox(width: 8),
                                  Text('Reset demo profiles',
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Resetting demo profiles makes every test profile visible again with cities, bios, banners, and fresh pre-likes.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.text3, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.favorite_outline_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Text('Music Match is hidden',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            Text(
              'Turn on “Appear in Music Match” in Edit Profile or Privacy to start discovering people with similar taste.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.text2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Music Match',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Find people by city, status, and music similarity.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How filters work',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 6),
                Text(
                  'Public only: show only open profiles. If it is off, private profiles can also appear if they allowed Music Match.',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: AppColors.text2, height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hide hidden taste: hide people who do not show their music taste. Turn it off if you still want those profiles in results.',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: AppColors.text2, height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(
                  'Leave city empty to search everywhere, or type a city name to narrow the results.',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: AppColors.text2, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _cityCtrl,
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by city',
                hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                prefixIcon: const Icon(Icons.location_city_rounded,
                    color: AppColors.text3),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => _load(),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('Online only', _onlyOnline,
                  () => setState(() => _onlyOnline = !_onlyOnline),
                  autoLoad: true),
              _filterChip('Public only', _onlyPublic,
                  () => setState(() => _onlyPublic = !_onlyPublic),
                  autoLoad: true),
              _filterChip(
                  'Hide hidden taste',
                  _excludeHiddenTaste,
                  () => setState(
                      () => _excludeHiddenTaste = !_excludeHiddenTaste),
                  autoLoad: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Minimum match ${_minSimilarity.round()}%',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              Text('${_minSimilarity.round()}%',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.purpleLight)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.purpleLight,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.purpleLight,
              overlayColor: AppColors.purple.withOpacity(0.18),
            ),
            child: Slider(
              value: _minSimilarity,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _minSimilarity = v),
              onChangeEnd: (_) => _load(),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _seedingDemo ? null : _seedDemoProfiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_seedingDemo)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purpleLight),
                    )
                  else ...[
                    const Icon(Icons.groups_rounded,
                        size: 16, color: AppColors.purpleLight),
                    const SizedBox(width: 8),
                    Text('Reset demo profiles',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap,
      {bool autoLoad = false}) {
    return GestureDetector(
      onTap: () {
        onTap();
        if (autoLoad) {
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? AppColors.gradPurple : null,
          color: active ? null : AppColors.bg,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: active ? Colors.transparent : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final name = c['display_name'] ?? c['username'] ?? 'User';
    final city = (c['city'] as String?) ?? '';
    final similarity = c['similarity_pct'] ?? 0;
    final icebreaker = c['icebreaker'] ?? 'You have similar music taste!';
    final tasteSummary = (c['taste_summary'] ?? '').toString();
    final bio = (c['bio'] ?? '').toString();
    final mediaVersion = c['updated_at'];
    final avatarUrl = buildMediaUrl(
      (c['avatar_url'] ?? '').toString(),
      version: mediaVersion,
    );
    final bannerUrl = buildMediaUrl(
      (c['banner_url'] ?? '').toString(),
      version: mediaVersion,
    );
    final isOnline = c['is_online'] == true;
    final presence = (c['presence_status'] ?? '').toString();
    final tasteVisible = c['music_taste_visible'] == true;
    final isPublic = c['is_public'] != false;
    final artistPreview = (c['artist_preview'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          _buildFilters(),
          const SizedBox(height: 18),
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
                  height: 188,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1a0533),
                        Color(0xFF0d1a3d),
                        Color(0xFF1a0533)
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (bannerUrl.isNotEmpty)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
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
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF22c55e)
                                      : const Color(0xFFfacc15),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline
                                    ? 'Online now'
                                    : presence == 'offline'
                                        ? 'Recently seen'
                                        : 'Available',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Avatar with glow ring
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 94,
                              height: 94,
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
                              width: 84,
                              height: 84,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 3),
                              ),
                              child: avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(initial,
                                            style: GoogleFonts.outfit(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white)),
                                      ),
                                    )
                                  : Center(
                                      child: Text(initial,
                                          style: GoogleFonts.outfit(
                                              fontSize: 30,
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
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _profileModeChip(
                                      isPublic
                                          ? 'Public profile'
                                          : 'Private profile',
                                      isPublic
                                          ? Icons.public_rounded
                                          : Icons.lock_rounded,
                                    ),
                                    if (!tasteVisible)
                                      _profileModeChip(
                                        'Taste hidden',
                                        Icons.visibility_off_rounded,
                                      ),
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bio,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: AppColors.text2),
                                  ),
                                ],
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
                                          fontSize: 20,
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
                      const SizedBox(height: 12),
                      // Icebreaker
                      Container(
                        padding: const EdgeInsets.all(12),
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
                                      fontSize: 12.5,
                                      height: 1.55,
                                      color: AppColors.text2)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.purple.withOpacity(0.12),
                              AppColors.pink.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.purple.withOpacity(0.16)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.purple.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.graphic_eq_rounded,
                                  size: 18, color: AppColors.purpleLight),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Music taste',
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text)),
                                  const SizedBox(height: 4),
                                  Text(
                                      tasteVisible
                                          ? (tasteSummary.isNotEmpty
                                              ? tasteSummary
                                              : 'Similar vibe detected')
                                          : 'This person hides their detailed music taste',
                                      style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          height: 1.45,
                                          color: AppColors.text2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (artistPreview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.person_search_rounded,
                                  size: 16, color: AppColors.pink),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Picked artists',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: artistPreview.map((artist) {
                                        final artistName =
                                            (artist['name'] ?? 'Artist')
                                                .toString();
                                        final artistImage =
                                            (artist['image_url'] ??
                                                    artist['picture_medium'] ??
                                                    artist['picture_big'] ??
                                                    '')
                                                .toString();
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.04),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                clipBehavior: Clip.antiAlias,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: AppColors.gradMixed,
                                                ),
                                                child: artistImage.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: artistImage,
                                                        fit: BoxFit.cover,
                                                        errorWidget:
                                                            (_, __, ___) =>
                                                                Center(
                                                          child: Text(
                                                            artistName
                                                                    .isNotEmpty
                                                                ? artistName[0]
                                                                    .toUpperCase()
                                                                : 'A',
                                                            style: GoogleFonts
                                                                .outfit(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Center(
                                                        child: Text(
                                                          artistName.isNotEmpty
                                                              ? artistName[0]
                                                                  .toUpperCase()
                                                              : 'A',
                                                          style: GoogleFonts
                                                              .outfit(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                artistName,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.text2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _decidingAction != null
                                ? null
                                : () => _decide('like'),
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
                                  if (_decidingAction == 'like')
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
                            onTap: _decidingAction != null
                                ? null
                                : () => _decide('skip'),
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
                                  if (_decidingAction == 'skip')
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.purpleLight,
                                      ),
                                    )
                                  else ...[
                                    const Icon(Icons.close_rounded,
                                        size: 18, color: Color(0xFFf87171)),
                                    const SizedBox(width: 8),
                                    Text('Pass',
                                        style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text)),
                                  ],
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

  Widget _profileModeChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.purpleLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}

// ─── Chats View ───────────────────────────────────────────────────────────────

class _ChatsView extends StatefulWidget {
  const _ChatsView({super.key});
  @override
  State<_ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<_ChatsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;
  List<dynamic> _chats = [];
  List<Map<String, dynamic>> _liveList = [];
  Map<int, Map<String, dynamic>> _liveActivityByUser = {};
  final Set<String> _hiddenChatKeys = {};
  final Set<String> _mutedChatKeys = {};
  final Set<String> _pinnedChatKeys = {};
  Map<String, int> _unreadCounts = {};
  static const _pinnedChatsKey = 'pinned_chats_v1';
  static const _mutedChatsKey = 'muted_chat_threads_v1';
  static const _hiddenChatsKey = 'hidden_chats_v1';
  static const _lastReadKeyPrefix = 'last_read_v1_';
  bool _loading = true;
  bool _refreshing = false;
  int _consecutiveEmptyLoads = 0;
  String _lastChatsSignature = '';
  String _lastUnreadSignature = '';
  DateTime _lastUnreadLoadedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _cachedChatsKey = 'social_cached_chats_v2';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(),
    );
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadPins(),
      _loadMuted(),
      _loadHidden(),
      _loadCachedChats(),
    ]);
    await _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPins() async {
    final prefs = await SharedPreferences.getInstance();
    final pins = prefs.getStringList(_pinnedChatsKey) ?? [];
    if (!mounted) return;
    setState(() => _pinnedChatKeys.addAll(pins));
  }

  Future<void> _loadMuted() async {
    final prefs = await SharedPreferences.getInstance();
    final muted = prefs.getStringList(_mutedChatsKey) ?? [];
    if (!mounted) return;
    setState(() => _mutedChatKeys.addAll(muted));
  }

  Future<void> _loadHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_hiddenChatsKey) ?? [];
    if (!mounted) return;
    setState(() => _hiddenChatKeys.addAll(hidden));
  }

  Future<void> _saveHidden() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenChatsKey, _hiddenChatKeys.toList());
  }

  Future<void> _toggleMute(String key) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_mutedChatKeys.contains(key)) {
        _mutedChatKeys.remove(key);
      } else {
        _mutedChatKeys.add(key);
      }
    });
    await prefs.setStringList(_mutedChatsKey, _mutedChatKeys.toList());
  }

  Future<void> _loadCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedChatsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty || !mounted) return;
      setState(() {
        _chats = decoded;
        _loading = false;
      });
    } catch (_) {}
  }

  Future<void> _saveCachedChats(List<dynamic> chats) async {
    if (chats.whereType<Map>().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedChatsKey, jsonEncode(chats));
  }

  void _showFloatingNotice(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: error
                ? const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
                  )
                : AppColors.gradPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                error ? Icons.error_outline_rounded : Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePin(String key) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_pinnedChatKeys.contains(key)) {
        _pinnedChatKeys.remove(key);
      } else if (_pinnedChatKeys.length < 5) {
        _pinnedChatKeys.add(key);
      }
    });
    await prefs.setStringList(_pinnedChatsKey, _pinnedChatKeys.toList());
  }

  Future<void> _hideChat(String key) async {
    final previousChats = List<dynamic>.from(_chats);
    setState(() {
      _hiddenChatKeys.add(key);
      _chats = _chats.where((raw) {
        if (raw is! Map) return true;
        return _chatKey(Map<String, dynamic>.from(raw)) != key;
      }).toList();
      _unreadCounts.remove(key);
    });
    await Future.wait([_saveCachedChats(_chats), _saveHidden()]);
    try {
      await ApiService().deleteChat(key);
    } catch (_) {
      try {
        await ApiService().hideChat(key);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _hiddenChatKeys.remove(key);
          _chats = previousChats;
        });
        await _saveHidden();
        _showFloatingNotice('Could not delete chat', error: true);
      }
    }
  }

  Future<void> _leaveGroup(String key, int groupChatId) async {
    final previousChats = List<dynamic>.from(_chats);
    setState(() {
      _hiddenChatKeys.add(key);
      _chats = _chats.where((raw) {
        if (raw is! Map) return true;
        return _chatKey(Map<String, dynamic>.from(raw)) != key;
      }).toList();
      _unreadCounts.remove(key);
    });
    await Future.wait([_saveCachedChats(_chats), _saveHidden()]);
    try {
      await ApiService().leaveGroupChat(groupChatId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hiddenChatKeys.remove(key);
        _chats = previousChats;
      });
      await _saveHidden();
      _showFloatingNotice('Could not leave group', error: true);
    }
  }

  void refresh() {
    _consecutiveEmptyLoads = 0;
    _refreshing = false;
    _load();
  }

  void upsertChat(Map<String, dynamic> incoming) {
    final nextChat = {
      ...incoming,
      'created_at':
          (incoming['created_at'] ?? DateTime.now().toUtc().toIso8601String())
              .toString(),
      'updated_at':
          (incoming['updated_at'] ?? DateTime.now().toUtc().toIso8601String())
              .toString(),
    };
    final key = _chatKey(nextChat);
    final nextChats = List<dynamic>.from(_chats);
    final index = nextChats.indexWhere((raw) {
      if (raw is! Map) return false;
      return _chatKey(Map<String, dynamic>.from(raw)) == key;
    });
    if (index >= 0) {
      final existing = Map<String, dynamic>.from(nextChats[index] as Map);
      nextChats[index] = {...existing, ...nextChat};
    } else {
      nextChats.insert(0, nextChat);
    }
    if (!mounted) return;
    setState(() {
      _hiddenChatKeys.remove(key);
      _chats = nextChats;
      _loading = false;
    });
    unawaited(Future.wait([_saveCachedChats(nextChats), _saveHidden()]));
  }

  Future<void> _load() async {
    if (_refreshing) return;
    if (!await ApiService().hasToken()) {
      if (mounted) {
        if (_chats.isEmpty) await _loadCachedChats();
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    _refreshing = true;
    try {
      unawaited(ApiService().sendPresenceHeartbeat());
      final data = await ApiService().getChats();
      final dataHasChats = data.whereType<Map>().isNotEmpty;
      if (!dataHasChats && _chats.isNotEmpty) {
        _consecutiveEmptyLoads += 1;
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      if (!dataHasChats) {
        _consecutiveEmptyLoads += 1;
        if (_consecutiveEmptyLoads < 3) {
          if (_chats.isEmpty) await _loadCachedChats();
          if (mounted) setState(() => _loading = false);
          return;
        }
      }
      _consecutiveEmptyLoads = dataHasChats ? 0 : _consecutiveEmptyLoads + 1;
      Map<int, Map<String, dynamic>> liveMap = {};
      List<Map<String, dynamic>> liveList = [];
      Map<String, dynamic> activity = const {};
      try {
        activity = await ApiService().getFriendsActivity();
      } catch (_) {
        activity = const {};
      }
      final live = (activity['live'] as List?) ?? const [];
      final recent = (activity['recent'] as List?) ?? const [];
      for (final item in live.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final id = (row['id'] as num?)?.toInt();
        if (id != null) liveMap[id] = row;
        liveList.add(row);
      }
      for (final item in recent.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final id = (row['id'] as num?)?.toInt();
        if (id != null) liveMap.putIfAbsent(id, () => row);
      }

      if (!mounted) return;
      final incomingChatKeys = data
          .whereType<Map>()
          .map((item) => _chatKey(Map<String, dynamic>.from(item)))
          .toSet();
      // Hidden keys are persisted; only remove when user explicitly re-opens chat
      final nextSignature = [
        for (final rawChat in data.whereType<Map>())
          _chatSignature(Map<String, dynamic>.from(rawChat)),
        '|live|',
        for (final item in liveList) _liveSignature(item),
        '|presence|',
        for (final item in liveMap.values) _liveSignature(item),
      ].join('||');
      final chatsChanged = nextSignature != _lastChatsSignature;
      if (_loading || chatsChanged) {
        _lastChatsSignature = nextSignature;
        setState(() {
          _chats = data;
          _liveActivityByUser = liveMap;
          _liveList = liveList;
          _loading = false;
        });
        unawaited(_saveCachedChats(data));
      } else if (_loading) {
        setState(() => _loading = false);
      }
      _loadUnreadCounts(force: chatsChanged);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveActivityByUser = {};
        _liveList = [];
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  String _chatSignature(Map<String, dynamic> chat) {
    final partner =
        (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
    return [
      _chatKey(chat),
      (chat['firebase_chat_id'] ?? '').toString(),
      (chat['updated_at'] ?? '').toString(),
      (chat['last_message_at'] ?? '').toString(),
      (chat['last_message_type'] ?? '').toString(),
      (chat['last_message_preview'] ?? '').toString(),
      (partner['display_name'] ?? '').toString(),
      (partner['avatar_url'] ?? '').toString(),
      (chat['member_count'] ?? '').toString(),
    ].join('|');
  }

  String _liveSignature(Map<String, dynamic> item) => [
        (item['id'] ?? '').toString(),
        (item['display_name'] ?? '').toString(),
        (item['avatar_url'] ?? '').toString(),
        ((item['now_playing'] as Map?)?['title'] ?? '').toString(),
        ((item['now_playing'] as Map?)?['artist'] ?? '').toString(),
        ((item['now_playing'] as Map?)?['cover_url'] ?? '').toString(),
        ((item['now_playing'] as Map?)?['track_cover_url'] ?? '').toString(),
        ((item['now_playing'] as Map?)?['album_cover_url'] ?? '').toString(),
        (item['activity_status'] ?? '').toString(),
        (item['presence_status'] ?? '').toString(),
        (item['last_seen_at'] ?? '').toString(),
      ].join('|');

  Future<void> _loadUnreadCounts({bool force = false}) async {
    if (!force &&
        DateTime.now().difference(_lastUnreadLoadedAt) <
            const Duration(seconds: 10)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final requests = <Map<String, String>>[];
    for (final rawChat in _chats) {
      final chat = Map<String, dynamic>.from(rawChat as Map);
      final key = _chatKey(chat);
      final firebaseId = (chat['firebase_chat_id'] as String?) ?? '';
      if (firebaseId.isEmpty) continue;
      final lastRead = prefs.getString('$_lastReadKeyPrefix$key');
      requests.add({
        'key': key,
        'firebase_chat_id': firebaseId,
        'since': lastRead ??
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String()
      });
    }
    if (requests.isEmpty) return;
    try {
      final counts = await ApiService().getUnreadCounts(requests);
      if (!mounted) return;
      final orderedKeys = counts.keys.toList()..sort();
      final signature = orderedKeys.map((k) => '$k:${counts[k]}').join('|');
      _lastUnreadLoadedAt = DateTime.now();
      if (signature != _lastUnreadSignature) {
        _lastUnreadSignature = signature;
        setState(() => _unreadCounts = counts);
      }
    } catch (_) {}
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
        .where((c) => !_hiddenChatKeys
            .contains(_chatKey(Map<String, dynamic>.from(c as Map))))
        .toList()
      ..sort((a, b) {
        final aKey = _chatKey(Map<String, dynamic>.from(a as Map));
        final bKey = _chatKey(Map<String, dynamic>.from(b as Map));
        final aPinned = _pinnedChatKeys.contains(aKey) ? 0 : 1;
        final bPinned = _pinnedChatKeys.contains(bKey) ? 0 : 1;
        return aPinned.compareTo(bPinned);
      });
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
                      height: 92,
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
                  if (i == visibleChats.length) {
                    return const SizedBox(height: 80);
                  }
                  final chat =
                      Map<String, dynamic>.from(visibleChats[i] as Map);
                  final partner =
                      (chat['partner'] as Map<String, dynamic>?) ?? const {};
                  final partnerId = (partner['id'] as num?)?.toInt();
                  final key = _chatKey(chat);
                  return _ChatItem(
                    chat: chat,
                    activity: partnerId == null
                        ? null
                        : _liveActivityByUser[partnerId],
                    isMuted: _mutedChatKeys.contains(key),
                    isPinned: _pinnedChatKeys.contains(key),
                    unreadCount: _unreadCounts[key] ?? 0,
                    onHide: () => _hideChat(key),
                    onLeaveGroup: (groupId) => _leaveGroup(key, groupId),
                    onToggleMute: () => _toggleMute(key),
                    onTogglePin: () => _togglePin(key),
                    canPin: !_pinnedChatKeys.contains(key) &&
                            _pinnedChatKeys.length >= 5
                        ? false
                        : true,
                    onReturn: (result) {
                      final returnedChat = result?['chat'];
                      if (returnedChat is Map) {
                        upsertChat(Map<String, dynamic>.from(returnedChat));
                      }
                      _load();
                    },
                  );
                },
                childCount: visibleChats.length + 1,
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
  final bool isPinned;
  final bool canPin;
  final int unreadCount;
  final VoidCallback? onHide;
  final void Function(int groupChatId)? onLeaveGroup;
  final VoidCallback? onToggleMute;
  final VoidCallback? onTogglePin;
  final void Function(Map<String, dynamic>? result)? onReturn;
  const _ChatItem({
    required this.chat,
    this.activity,
    this.isMuted = false,
    this.isPinned = false,
    this.canPin = true,
    this.unreadCount = 0,
    this.onHide,
    this.onLeaveGroup,
    this.onToggleMute,
    this.onTogglePin,
    this.onReturn,
  });

  static String _cleanPreview(String? raw, String? type, String? timeStr) {
    if (raw == null || raw.isEmpty) {
      return timeStr != null ? 'Tap to start 🎵' : 'New match!';
    }
    if (type == 'track') return raw;
    final t = raw.trim();
    if (t.startsWith('💬') ||
        t.contains('создал') ||
        t.contains('group chat') ||
        t.contains('created a group')) {
      return '💬 Group invite';
    }
    if (t.contains('Listening room') ||
        t.contains('Live Room') ||
        t.contains('MW-') ||
        t.contains('Invite code')) {
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
    final avatarVersion = chatKind == 'group'
        ? (chat['updated_at']?.toString() ??
            chat['last_message_at']?.toString())
        : null;
    final avatarUrl = buildMediaUrl(
      (partner['avatar_url'] ?? '').toString(),
      version: avatarVersion,
    );
    final city = (partner['city'] as String?) ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final preview = chat['last_message_preview'] as String?;
    final previewType = chat['last_message_type'] as String?;
    final timeStr =
        chat['last_message_at'] as String? ?? chat['created_at'] as String?;
    final nowPlaying =
        (activity?['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final activityStatus = (activity?['activity_status'] ?? '').toString();
    final isLiveNow = activityStatus == 'live' && nowPlaying.isNotEmpty;
    final isRecentListen = activityStatus == 'recent' && nowPlaying.isNotEmpty;
    final liveTitle = (nowPlaying['title'] ?? '').toString().trim();
    final liveArtist = (nowPlaying['artist'] ?? '').toString().trim();
    final isOnline = activity?['is_online'] == true;
    final lastSeenAt = (activity?['last_seen_at'] ?? '').toString();
    final lastSeenLabel = lastSeenAt.isNotEmpty ? _relTime(lastSeenAt) : '';
    final statusText = isLiveNow
        ? 'Listening now'
        : isRecentListen
            ? 'Listened recently'
            : isOnline
                ? 'Online'
                : lastSeenLabel.isNotEmpty
                    ? (lastSeenLabel == 'now'
                        ? 'Last seen just now'
                        : 'Last seen $lastSeenLabel ago')
                    : '';

    final previewText = _ChatItem._cleanPreview(preview, previewType, timeStr);
    final isTrackPreview = previewType == 'track';
    final accentColor = AppColors.purpleLight;
    final tileDecoration = isLiveNow || isRecentListen
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface.withOpacity(0.34),
            border: Border.all(color: AppColors.purpleLight.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleDark.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>?>(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(
                    matchId: matchId,
                    chatId: chatId,
                    groupChatId: groupChatId,
                    partnerName: name,
                    partnerId: partner['id'] as int? ?? 0,
                    partnerAvatarUrl: avatarUrl,
                    firebaseChatId:
                        (chat['firebase_chat_id'] as String?) ?? '')));
        onReturn?.call(result);
      },
      onLongPress: () => _showChatOptions(context, name, chatKind, groupChatId),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: EdgeInsets.symmetric(
            vertical: 13,
            horizontal: (isLiveNow || isRecentListen) ? 12 : 2,
          ),
          decoration: tileDecoration,
          child: Row(children: [
            // Avatar with optional glow for new chats
            Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: avatarUrl.isNotEmpty ? Colors.transparent : null,
                gradient: avatarUrl.isNotEmpty ? null : AppColors.gradMixed,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.3),
                      blurRadius: 12)
                ],
              ),
              child: avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      imageBuilder: (_, imageProvider) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
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
            if (isLiveNow || isRecentListen)
              Transform.translate(
                offset: const Offset(-14, 16),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isLiveNow
                              ? AppColors.green
                              : const Color(0xFFFACC15))
                          .withOpacity(0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isLiveNow
                                ? AppColors.green
                                : const Color(0xFFFACC15))
                            .withOpacity(0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 12,
                      color:
                          isLiveNow ? AppColors.green : const Color(0xFFFACC15),
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
                    else if (statusText.isNotEmpty)
                      Text(statusText,
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: isLiveNow
                                  ? AppColors.green
                                  : isRecentListen
                                      ? const Color(0xFFFACC15)
                                      : isOnline
                                          ? AppColors.purpleLight
                                          : AppColors.text3))
                    else if (city.isNotEmpty)
                      Text(city,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.text3)),
                    const SizedBox(height: 3),
                    if (isLiveNow || isRecentListen)
                      Row(
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 12,
                            color: isLiveNow
                                ? AppColors.green
                                : const Color(0xFFFACC15),
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
                                color: accentColor,
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
                            color:
                                isTrackPreview ? accentColor : AppColors.text3),
                      ),
                  ]),
            ),
            // Time + indicators
            if (timeStr != null || isMuted || isPinned || unreadCount > 0) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPinned)
                        const Icon(Icons.push_pin_rounded,
                            size: 12, color: AppColors.purpleLight),
                      if (isPinned && isMuted) const SizedBox(width: 4),
                      if (isMuted)
                        const Icon(Icons.notifications_off_rounded,
                            size: 12, color: AppColors.text3),
                    ],
                  ),
                  if (timeStr != null)
                    Text(
                      _relTime(timeStr),
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.text3),
                    ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, maxWidth: 30),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        gradient: isMuted ? null : AppColors.gradPurple,
                        color: isMuted ? AppColors.glass : null,
                        borderRadius: BorderRadius.circular(9),
                        border: isMuted
                            ? Border.all(color: AppColors.border)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMuted ? AppColors.text3 : Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _showChatOptions(
    BuildContext context,
    String chatName,
    String chatKind,
    int? groupChatId,
  ) {
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
            if (isPinned || canPin) ...[
              _sheetOption(
                icon:
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                label: isPinned ? 'Unpin chat' : 'Pin chat',
                color: AppColors.purpleLight,
                onTap: () {
                  Navigator.pop(context);
                  onTogglePin?.call();
                },
              ),
              const SizedBox(height: 8),
            ],
            _sheetOption(
              icon:
                  isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              label: isMuted ? 'Unmute' : 'Mute',
              color: AppColors.text,
              onTap: () {
                Navigator.pop(context);
                onToggleMute?.call();
              },
            ),
            const SizedBox(height: 8),
            if (chatKind == 'group' && groupChatId != null) ...[
              _sheetOption(
                icon: Icons.logout_rounded,
                label: 'Leave group',
                color: const Color(0xFFFACC15),
                onTap: () {
                  Navigator.pop(context);
                  onLeaveGroup?.call(groupChatId);
                },
              ),
              const SizedBox(height: 8),
            ],
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
    final rawCover =
        (nowPlaying['cover_url'] ?? nowPlaying['track_cover_url'] ?? '')
            .toString()
            .trim();
    final coverUrl =
        rawCover.startsWith('http') ? rawCover : buildMediaUrl(rawCover);

    return Container(
      width: 62,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.purpleLight.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: coverUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) =>
                              _avatarFallback(avatar, initial),
                        ),
                      )
                    : _avatarFallback(avatar, initial),
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

  Widget _avatarFallback(String avatar, String initial) {
    if (avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: buildMediaUrl(avatar),
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(),
          errorWidget: (_, __, ___) => Center(
            child: Text(initial,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
      );
    }
    return Center(
      child: Text(initial,
          style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
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
      final firebaseChatId = (result['firebase_chat_id'] as String?) ?? '';
      final chatResult = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            partnerName: partnerName,
            partnerId: partnerId,
            partnerAvatarUrl: avatarUrl,
            firebaseChatId: firebaseChatId.isNotEmpty ? firebaseChatId : null,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(
          context,
          chatResult ??
              {
                'chat': {
                  ...result,
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                }
              });
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
                _RecommendationSection(
                  title: _searchCtrl.text.trim().isEmpty
                      ? 'People you follow'
                      : 'Results',
                  users: _filtered,
                  openingUserId: _openingUserId,
                  onTap: _openChat,
                ),
                if (_searchCtrl.text.trim().isEmpty && _recommended.isNotEmpty)
                  _RecommendationSection(
                    title: 'Recommendations',
                    users: _recommended,
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
