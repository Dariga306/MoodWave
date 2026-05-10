import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'user_profile_screen.dart';

class SocialActivityScreen extends StatefulWidget {
  const SocialActivityScreen({super.key});

  @override
  State<SocialActivityScreen> createState() => _SocialActivityScreenState();
}

class _SocialActivityScreenState extends State<SocialActivityScreen> {
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
      body: Column(
        children: [
          const _ActivityHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  )
                : (_live.isEmpty && _recent.isEmpty)
                    ? _EmptyActivity(onRefresh: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.purpleLight,
                        backgroundColor: AppColors.surface,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                          children: [
                            if (_live.isNotEmpty) ...[
                              Text(
                                'Listening Now',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your friends are live right now',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.text2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ..._live.map(
                                (item) => _LiveFriendCard(
                                  friend:
                                      Map<String, dynamic>.from(item as Map),
                                ),
                              ),
                            ],
                            if (_recent.isNotEmpty) ...[
                              SizedBox(height: _live.isNotEmpty ? 18 : 0),
                              Text(
                                'Recently Played',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._recent.map(
                                (item) => _RecentFriendItem(
                                  friend:
                                      Map<String, dynamic>.from(item as Map),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.purpleLight, AppColors.pink],
                    ).createShader(b),
                    child: Text(
                      'Activity',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'What your friends are listening to',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyActivity({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('🎧', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nobody\'s listening right now',
              style: GoogleFonts.outfit(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends and listen together —\ntheir activity will show here',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryBtn,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Refresh',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Gradient palettes cycling per card index
const _kCardGradients = [
  [Color(0xFF4c1d95), Color(0xFF7c3aed)],
  [Color(0xFF9d174d), Color(0xFFec4899)],
  [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
  [Color(0xFF065f46), Color(0xFF10b981)],
  [Color(0xFF92400e), Color(0xFFf59e0b)],
];

class _LiveFriendCard extends StatefulWidget {
  final Map<String, dynamic> friend;
  const _LiveFriendCard({required this.friend});

  @override
  State<_LiveFriendCard> createState() => _LiveFriendCardState();
}

class _LiveFriendCardState extends State<_LiveFriendCard>
    with TickerProviderStateMixin {
  late final List<AnimationController> _barCtrls;
  late final List<Animation<double>> _barAnims;

  static int _cardIndex = 0;
  late final int _myIndex;

  @override
  void initState() {
    super.initState();
    _myIndex = _cardIndex++;
    final speeds = [650, 850, 550, 750];
    _barCtrls = speeds
        .map((ms) => AnimationController(
              vsync: this,
              duration: Duration(milliseconds: ms),
            )..repeat(reverse: true))
        .toList();
    _barAnims = [
      Tween<double>(begin: 0.2, end: 1.0).animate(
          CurvedAnimation(parent: _barCtrls[0], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(parent: _barCtrls[1], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.15, end: 0.85).animate(
          CurvedAnimation(parent: _barCtrls[2], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.35, end: 0.95).animate(
          CurvedAnimation(parent: _barCtrls[3], curve: Curves.easeInOut)),
    ];
  }

  @override
  void dispose() {
    for (final c in _barCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now =
        (widget.friend['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final track = (now['title'] ?? 'Listening now').toString();
    final artist = (now['artist'] ?? '').toString();
    final colors = _kCardGradients[_myIndex % _kCardGradients.length];

    return GestureDetector(
      onTap: () => _openProfile(context, widget.friend),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors[0].withOpacity(0.55),
              colors[1].withOpacity(0.40),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors[1].withOpacity(0.35)),
        ),
        child: Row(
          children: [
            // Avatar with LIVE badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _FriendAvatar(friend: widget.friend, size: 48),
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors[0], colors[1]],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: AppColors.bg, width: 1.5),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _friendName(widget.friend),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    track,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Animated music bars
            AnimatedBuilder(
              animation: Listenable.merge(_barCtrls),
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (i) {
                  return Container(
                    width: 3,
                    height: 28 * _barAnims[i].value,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: colors[1].withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentFriendItem extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _RecentFriendItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    final now = (friend['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final track = (now['title'] ?? 'No recent activity').toString();
    final artist = (now['artist'] ?? '').toString();
    final playedAt = now['played_at']?.toString();

    return GestureDetector(
      onTap: () => _openProfile(context, friend),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(
          children: [
            _FriendAvatar(friend: friend, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _friendName(friend),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (artist.isNotEmpty) artist, track].join(' — '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relTime(playedAt),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final Map<String, dynamic> friend;
  final double size;
  const _FriendAvatar({required this.friend, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatar = (friend['avatar_url'] ?? '').toString();
    final name = _friendName(friend);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.gradMixed,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
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
                      fontSize: size * 0.36,
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
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

String _friendName(Map<String, dynamic> friend) {
  return (friend['display_name'] ?? friend['username'] ?? 'User').toString();
}

String _relTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final normalized =
        (iso.endsWith('Z') || iso.contains('+')) ? iso : '${iso}Z';
    final dt = DateTime.parse(normalized).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  } catch (_) {
    return '';
  }
}

void _openProfile(BuildContext context, Map<String, dynamic> friend) {
  final rawId = friend['id'];
  final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
  if (userId == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => UserProfileScreen(
        userId: userId,
        initialUser: friend,
      ),
    ),
  );
}
