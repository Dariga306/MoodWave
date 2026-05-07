import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../chat_screen.dart';
import '../extra_screens.dart';
import '../social_activity_screen.dart';

class SocialTab extends StatefulWidget {
  const SocialTab({super.key});
  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
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
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SocialActivityScreen(),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withOpacity(0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.purple.withOpacity(0.16),
                              AppColors.pink.withOpacity(0.08),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          size: 20,
                          color: AppColors.purpleLight,
                        ),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getChats();
      if (!mounted) return;
      setState(() {
        _chats = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight));
    }
    if (_chats.isEmpty) {
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
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _chats.length,
        itemBuilder: (_, i) =>
            _ChatItem(chat: _chats[i] as Map<String, dynamic>),
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  const _ChatItem({required this.chat});

  @override
  Widget build(BuildContext context) {
    final matchId = chat['match_id'] as int?;
    final chatId = chat['chat_id'] as int?;
    final partner =
        (chat['partner'] as Map<String, dynamic>?) ?? {'display_name': 'User'};
    final name = partner['display_name'] ??
        partner['first_name'] ??
        partner['username'] ??
        'User';
    final city = (partner['city'] as String?) ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final similarity = chat['similarity_pct'] ?? 0;
    final preview = chat['last_message_preview'] as String?;
    final previewType = chat['last_message_type'] as String?;
    final timeStr =
        chat['last_message_at'] as String? ?? chat['created_at'] as String?;

    final previewText = preview != null && preview.isNotEmpty
        ? preview
        : (timeStr != null ? 'Tap to start chatting 🎵' : 'New match!');
    final isTrackPreview = previewType == 'track';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                  matchId: matchId,
                  chatId: chatId,
                  partnerName: name,
                  partnerId: partner['id'] as int? ?? 0,
                  partnerAvatarUrl: (partner['avatar_url'] ?? '').toString()))),
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
            const SizedBox(width: 12),
            // Name + preview
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(name,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.purple.withOpacity(0.2),
                            AppColors.pink.withOpacity(0.1),
                          ]),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: AppColors.purple.withOpacity(0.25)),
                        ),
                        child: Text('$similarity%',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purpleLight)),
                      ),
                    ]),
                    if (city.isNotEmpty)
                      Text(city,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.text3)),
                    const SizedBox(height: 3),
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

// ─── Activity View ────────────────────────────────────────────────────────────

class _ActivityView extends StatefulWidget {
  const _ActivityView();
  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight));
    }
    if (_live.isEmpty && _recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                  child: Text('🎧', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 20),
            Text('No activity yet',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            Text('Match and add friends to see\nwhat they listen to',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.text2, height: 1.5)),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.purpleLight,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_live.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFec4899), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Live Now',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.pink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('${_live.length}',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pink)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: _live
                    .map((f) => _LiveCard(friend: f as Map<String, dynamic>))
                    .toList(),
              ),
            ),
          ],
          if (_recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recently Listened',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RecentHistoryScreen())),
                    child: Text('All →',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.purpleLight)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: _recent
                    .map((f) => _RecentItem(friend: f as Map<String, dynamic>))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _LiveCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final name = friend['display_name'] ?? friend['username'] ?? 'User';
    final nowPlaying = friend['now_playing'] as Map<String, dynamic>?;
    final track = nowPlaying != null
        ? '${nowPlaying['artist'] ?? ''} — ${nowPlaying['title'] ?? ''}'
        : 'Listening now';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.purpleDark.withOpacity(0.1),
            AppColors.pink.withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purple.withOpacity(0.18)),
        ),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.35),
                      blurRadius: 12)
                ],
              ),
              child: Center(
                  child: Text(initial,
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('LIVE',
                    style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name is listening',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 2),
                Text(track,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purpleLight),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedMusicBars(
              color1: AppColors.purpleLight,
              color2: AppColors.pink,
              maxHeight: 22),
        ]),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _RecentItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    final name = friend['display_name'] ?? friend['username'] ?? 'User';
    final nowPlaying = friend['now_playing'] as Map<String, dynamic>?;
    final trackStr = nowPlaying != null
        ? '${nowPlaying['artist'] ?? ''} — ${nowPlaying['title'] ?? ''}'
        : 'No recent activity';
    final playedAt = nowPlaying?['played_at'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.gradPurple,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(
              child: Text(initial,
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            Text(trackStr,
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (playedAt != null) ...[
          const SizedBox(width: 8),
          Text(_relTime(playedAt),
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ],
      ]),
    );
  }

  String _relTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}
