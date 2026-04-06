import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../chat_screen.dart';

/// Combined Social screen — Chats (left) | Matching (right)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Social',
                      style: GoogleFonts.outfit(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: AppColors.text, letterSpacing: -0.5)),
                  const SizedBox(height: 14),
                  // Toggle tabs
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _Tab(label: 'Chats', icon: Icons.chat_bubble_outline_rounded,
                            active: _tab.index == 0, onTap: () => _tab.animateTo(0)),
                        _Tab(label: 'Matching', icon: Icons.favorite_outline_rounded,
                            active: _tab.index == 1, onTap: () => _tab.animateTo(1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: const [
                _ChatsView(),
                _MatchingView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: active ? AppColors.primaryBtn : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: active ? Colors.white : AppColors.text3),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.text3)),
            ],
          ),
        ),
      ),
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

  List<dynamic> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getMyMatches();
      if (!mounted) return;
      setState(() { _matches = data; _loading = false; });
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
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight));
    }
    if (_matches.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💬', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          Text('No chats yet',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Match with someone to start chatting',
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.purpleLight,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _matches.length,
        itemBuilder: (_, i) => _ChatItem(match: _matches[i] as Map<String, dynamic>),
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final Map<String, dynamic> match;
  const _ChatItem({required this.match});

  @override
  Widget build(BuildContext context) {
    final matchId = match['match_id'] as int? ?? match['id'] as int? ?? 0;
    final partner = match['partner'] as Map<String, dynamic>? ?? match;
    final name = partner['display_name'] ?? partner['username'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final similarity = match['similarity_pct'] ?? match['compatibility_pct'] ?? 0;
    final lastMsg = match['last_message'] as String? ?? 'Start a conversation 🎵';
    final timeStr = match['last_message_at'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(
              matchId: matchId,
              partnerName: name,
              partnerId: partner['user_id'] as int? ?? partner['id'] as int? ?? 0))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
        child: Row(children: [
          // Avatar
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(initial,
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 12),
          // Name + last msg
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('$similarity%',
                      style: GoogleFonts.outfit(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppColors.purpleLight)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(lastMsg,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          if (timeStr != null)
            Text(_formatTime(timeStr),
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ]),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}

// ─── Matching View ────────────────────────────────────────────────────────────

class _MatchingView extends StatefulWidget {
  const _MatchingView();
  @override
  State<_MatchingView> createState() => _MatchingViewState();
}

class _MatchingViewState extends State<_MatchingView>
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
      setState(() { _candidates = data; _idx = 0; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _current =>
      _candidates.isNotEmpty && _idx < _candidates.length
          ? _candidates[_idx] as Map<String, dynamic>
          : null;

  Future<void> _decide(String decision) async {
    if (_deciding || _current == null) return;
    final c = Map<String, dynamic>.from(_current!);
    final userId = c['user_id'] as int;
    setState(() => _deciding = true);
    try {
      final result = await ApiService().decideMatch(userId, decision);
      if (!mounted) return;
      if (result['is_mutual'] == true) {
        _showMutualDialog(c, result['match_id'] as int? ?? 0);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() { _deciding = false; _idx++; });
  }

  Future<void> _showMutualDialog(Map<String, dynamic> c, int matchId) async {
    final name = c['display_name'] ?? c['username'] ?? 'User';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("It's a match! 🎵",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text("$name liked you back! You share music taste.",
            style: GoogleFonts.outfit(color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(matchId: matchId, partnerName: name,
                      partnerId: c['user_id'] as int? ?? 0)));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Chat now', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight));
    }
    if (_current == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎵', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 14),
        Text('No matches right now', style: GoogleFonts.outfit(
            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 6),
        Text('Listen to more music to find people\nwith similar taste',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(gradient: AppColors.primaryBtn, borderRadius: BorderRadius.circular(14)),
            child: Text('Refresh', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]));
    }

    final c = _current!;
    final name = c['display_name'] ?? c['username'] ?? 'User';
    final city = c['city'] ?? '';
    final similarity = c['similarity_pct'] ?? 0;
    final icebreaker = c['icebreaker'] ?? 'You have similar music taste!';
    final genres = (c['genres'] as List?)?.cast<String>() ?? [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final remaining = _candidates.length > _idx + 1 ? _candidates.length - _idx - 1 : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('$remaining more waiting',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header gradient
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.purpleDark.withOpacity(0.8), AppColors.pink.withOpacity(0.4)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: Center(
                child: Container(width: 80, height: 80,
                  decoration: BoxDecoration(gradient: AppColors.gradMixed, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 2)),
                  child: Center(child: Text(initial,
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
                if (city.isNotEmpty)
                  Text('📍 $city', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.purple.withOpacity(0.2), AppColors.pink.withOpacity(0.1)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Text('$similarity%',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.purpleLight)),
                    const SizedBox(width: 8),
                    Text('taste match', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.music_note_rounded, size: 16, color: AppColors.purpleLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(icebreaker, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2, height: 1.4))),
                  ]),
                ),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: genres.take(5).map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border)),
                      child: Text(g, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
                    )).toList(),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          // Skip
          GestureDetector(
            onTap: _deciding ? null : () => _decide('skip'),
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.close_rounded, size: 28, color: Color(0xFFf87171)),
            ),
          ),
          // Like
          GestureDetector(
            onTap: _deciding ? null : () => _decide('like'),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtn,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.purple.withOpacity(0.4), blurRadius: 20)],
              ),
              child: _deciding
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.favorite_rounded, size: 32, color: Colors.white),
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.refresh_rounded, size: 26, color: AppColors.text2),
            ),
          ),
        ]),
      ]),
    );
  }
}
