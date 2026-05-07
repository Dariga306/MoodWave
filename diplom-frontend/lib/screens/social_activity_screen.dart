import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'extra_screens.dart';
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
                                'Friends Activity',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'See who is listening right now',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppColors.text2,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ..._live.map(
                                (item) => _LiveFriendCard(
                                  friend:
                                      Map<String, dynamic>.from(item as Map),
                                ),
                              ),
                            ],
                            if (_recent.isNotEmpty) ...[
                              SizedBox(height: _live.isNotEmpty ? 18 : 0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recently Listened',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RecentHistoryScreen(),
                                      ),
                                    ),
                                    child: Text(
                                      'All →',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.purpleLight,
                                      ),
                                    ),
                                  ),
                                ],
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
  const _ActivityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
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
              'No activity yet',
              style: GoogleFonts.outfit(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends and listen together to\nsee live music activity here',
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

class _LiveFriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _LiveFriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final now = (friend['now_playing'] as Map?)?.cast<String, dynamic>() ?? {};
    final track = (now['title'] ?? 'Listening now').toString();
    final artist = (now['artist'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openProfile(context, friend),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purpleDark.withOpacity(0.18),
              AppColors.blue.withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            _FriendAvatar(friend: friend, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_friendName(friend)} is listening',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [if (artist.isNotEmpty) artist, track].join(' — '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.purpleLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle(friend),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pink.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.pink,
                ),
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

String _subtitle(Map<String, dynamic> friend) {
  final city = (friend['city'] ?? '').toString();
  return city.isNotEmpty
      ? city
      : '@${(friend['username'] ?? 'user').toString()}';
}

String _relTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
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
