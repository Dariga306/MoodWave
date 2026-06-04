import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/media_url.dart';
import '../artist_screen.dart';
import '../edit_profile_screen.dart';
import '../extra_screens.dart';
import '../notifications_screen.dart';
import '../settings_screen.dart';
import '../stats_screen.dart';
import '../user_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int? _followersCount;
  int? _followingCount;
  int? _userId;
  bool _statsLoaded = false;
  int _lastProfileRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService().getMe();
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(data);
      setState(() {
        _followersCount = (data['followers_count'] as num?)?.toInt() ?? 0;
        _followingCount = (data['following_count'] as num?)?.toInt() ?? 0;
        _userId = (data['id'] as num?)?.toInt();
        _statsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoaded = true);
    }
  }

  void _openFollowersList() {
    if (_userId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ConnectionsScreen(
            userId: _userId!,
            mode: _ConnectionMode.followers,
          ),
        ));
  }

  void _openFollowingList() {
    if (_userId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ConnectionsScreen(
            userId: _userId!,
            mode: _ConnectionMode.following,
          ),
        ));
  }

  void _handleProfileRevision(int revision) {
    if (revision == _lastProfileRevision) return;
    _lastProfileRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  static String _genderToPronouns(String gender) {
    switch (gender.toLowerCase().trim()) {
      case 'male':
        return 'he/him';
      case 'female':
        return 'she/her';
      case 'non-binary':
      case 'non_binary':
        return 'they/them';
      case '':
      case 'prefer not to say':
      case 'prefer_not_to_say':
        return '';
      default:
        return gender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileRevision =
        context.select<AuthProvider, int>((auth) => auth.profileRevision);
    _handleProfileRevision(profileRevision);
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final username = user?['username'] ?? '';
    final city = user?['city'] ?? '';
    final bio = user?['bio'] as String? ?? '';
    final mediaVersion = user?['updated_at'];
    final avatarUrl = buildMediaUrl(
      user?['avatar_url'] as String?,
      version: mediaVersion,
    );
    final bannerUrl = buildMediaUrl(
      user?['banner_url'] as String?,
      version: mediaVersion,
    );
    final gender = user?['gender'] as String? ?? '';
    final pronouns = _genderToPronouns(gender);
    final avatarPreset = user?['avatar_preset'] as int? ?? 0;
    final bannerPreset = user?['banner_preset'] as int? ?? 0;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    const avatarGradients = [
      [Color(0xFF7C3AED), Color(0xFFDB2777)],
      [Color(0xFF2563EB), Color(0xFF7C3AED)],
      [Color(0xFF059669), Color(0xFF2563EB)],
      [Color(0xFFD97706), Color(0xFFDC2626)],
      [Color(0xFF7C3AED), Color(0xFF2563EB)],
      [Color(0xFFDB2777), Color(0xFFEF4444)],
      [Color(0xFF0891B2), Color(0xFF059669)],
      [Color(0xFF6D28D9), Color(0xFF0891B2)],
      [Color(0xFF374151), Color(0xFF6D28D9)],
      [Color(0xFFB45309), Color(0xFF065F46)],
      [Color(0xFF9D174D), Color(0xFF6D28D9)],
      [Color(0xFF1E40AF), Color(0xFF065F46)],
    ];

    const bannerGradients = [
      [Color(0xFF150825), Color(0xFF3d1a6e)],
      [Color(0xFF1a1a3e), Color(0xFF7C3AED)],
      [Color(0xFF0d1a3d), Color(0xFF2563EB)],
      [Color(0xFF0d2618), Color(0xFF059669)],
      [Color(0xFF3d1a1a), Color(0xFFDC2626)],
      [Color(0xFF08080f), Color(0xFF374151)],
    ];

    final safeAvatarPreset = avatarPreset.clamp(0, avatarGradients.length - 1);
    final safeBannerPreset = bannerPreset.clamp(0, bannerGradients.length - 1);
    final avatarColors = avatarGradients[safeAvatarPreset];
    final bannerColors = bannerGradients[safeBannerPreset];

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
              // Banner (settings gear only in stack)
              Stack(
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: bannerColors.cast<Color>(),
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (bannerUrl.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              bannerUrl,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.purple.withOpacity(0.2),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 20,
                          child: SafeArea(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen())),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.settings_rounded,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // OverflowBox reduces layout height by 40px so name sits 12px
              // below the avatar's visual bottom, while Transform keeps the
              // avatar visually overlapping the banner.
              SizedBox(
                height: 42,
                child: OverflowBox(
                  maxHeight: double.infinity,
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: const Offset(0, -40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: avatarColors.cast<Color>(),
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 3),
                            ),
                            child: avatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      avatarUrl,
                                      width: 82,
                                      height: 82,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(initial,
                                            style: GoogleFonts.outfit(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(initial,
                                        style: GoogleFonts.outfit(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (user == null) return;
                              final auth = context.read<AuthProvider>();
                              final saved =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    user: Map<String, dynamic>.from(user),
                                  ),
                                ),
                              );
                              if (mounted && saved == true) {
                                await auth.reload();
                                if (mounted) _load();
                              } else if (mounted) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text('Edit Profile',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Name, handle, bio
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('@$username',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: AppColors.text2)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('· $city',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppColors.text3)),
                      ],
                      if (pronouns.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('· $pronouns',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                      ],
                    ]),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(bio,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.text2,
                              height: 1.5)),
                    ],
                  ],
                ),
              ),

              // Followers / Following — Spotify-style inline
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openFollowersList,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _statsLoaded
                                  ? '${_followersCount ?? 0}'
                                  : '—',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.purpleLight,
                              ),
                            ),
                            TextSpan(
                              text: '  Followers',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _openFollowingList,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _statsLoaded
                                  ? '${_followingCount ?? 0}'
                                  : '—',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.purpleLight,
                              ),
                            ),
                            TextSpan(
                              text: '  Following',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick access
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('My Pages',
                    style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _NavRow(
                      icon: Icons.history_rounded,
                      label: 'Listening History',
                      sub: 'Recently played by day',
                      color: AppColors.cyan,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RecentHistoryScreen()))),
                  _NavRow(
                      icon: Icons.bar_chart_rounded,
                      label: 'My Stats',
                      sub: 'Top artists, genres & more',
                      color: AppColors.purple,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatsScreen()))),
                  _NavRow(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      sub: 'Matches, friends, music',
                      color: AppColors.pink,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()))),
                ]),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _NavRow(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(child: Icon(icon, size: 18, color: color))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text(sub,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
              ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 20),
        ]),
      ),
    );
  }
}

enum _ConnectionMode { followers, following }

class _ConnectionsScreen extends StatefulWidget {
  final int userId;
  final _ConnectionMode mode;
  const _ConnectionsScreen({required this.userId, required this.mode});

  @override
  State<_ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<_ConnectionsScreen> {
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _followingUsers = [];
  List<Map<String, dynamic>> _followingArtists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = widget.mode == _ConnectionMode.followers
          ? await Future.wait([
              ApiService()
                  .getUserFollowers(widget.userId)
                  .catchError((_) => <Map<String, dynamic>>[]),
            ])
          : await Future.wait([
              ApiService()
                  .getUserFollowing(widget.userId)
                  .catchError((_) => <Map<String, dynamic>>[]),
              ApiService()
                  .getUserFollowingArtists(widget.userId)
                  .catchError((_) => <Map<String, dynamic>>[]),
            ]);
      if (!mounted) return;
      setState(() {
        if (widget.mode == _ConnectionMode.followers) {
          _followers = results[0] as List<Map<String, dynamic>>;
        } else {
          _followingUsers = results[0] as List<Map<String, dynamic>>;
          _followingArtists = results[1] as List<Map<String, dynamic>>;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _userRow(Map<String, dynamic> u) {
    final name = (u['display_name'] ?? u['first_name'] ?? u['username'] ?? '')
        .toString();
    final uname = (u['username'] ?? '').toString();
    final avatar = buildMediaUrl(
      u['avatar_url']?.toString(),
      version: u['updated_at'],
    );
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final rawId =
        u['id'] ?? u['user_id'] ?? u['follower_id'] ?? u['following_id'];
    final userId =
        rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: userId == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: userId,
                      initialUser: {
                        ...u,
                        'id': userId,
                      },
                    ),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppColors.gradMixed),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                            child: Text(initial,
                                style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))))
                    : Center(
                        child: Text(initial,
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  if (uname.isNotEmpty)
                    Text('@$uname',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.text3)),
                ])),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _artistRow(Map<String, dynamic> artist) {
    final name = (artist['name'] ?? '').toString();
    final pic = (artist['picture_medium'] ??
            artist['picture_xl'] ??
            artist['picture'] ??
            '')
        .toString();
    final fans = artist['nb_fan'];
    final fansNum =
        fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
    final sub = fansNum >= 1000000
        ? '${(fansNum / 1000000).toStringAsFixed(1)}M listeners'
        : fansNum >= 1000
            ? '${(fansNum / 1000).toStringAsFixed(0)}K listeners'
            : 'Artist';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () {
        final id = artist['id'];
        if (id != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ArtistScreen(artistId: id.toString(), artistName: name)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: AppColors.gradPurple),
            child: ClipOval(
              child: pic.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: pic,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                          child: Text(initial,
                              style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white))))
                  : Center(
                      child: Text(initial,
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text(sub,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
              ])),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.text3, size: 20),
        ]),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 52, color: AppColors.text3),
            const SizedBox(height: 12),
            Text(msg,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text('Check back later',
                style:
                    GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final followingAll = [..._followingUsers, ..._followingArtists];
    final isFollowers = widget.mode == _ConnectionMode.followers;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          isFollowers
              ? 'Followers${_loading ? '' : ' (${_followers.length})'}'
              : 'Following${_loading ? '' : ' (${followingAll.length})'}',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight))
          : isFollowers
              ? (_followers.isEmpty
                  ? _emptyState('No followers yet')
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _followers.map((u) => _userRow(u)).toList(),
                    ))
              : (followingAll.isEmpty
                  ? _emptyState('Not following anyone yet')
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (_followingUsers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                            child: Text(
                              'People',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text3,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          ..._followingUsers.map((u) => _userRow(u)),
                        ],
                        if (_followingArtists.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Text(
                              'Artists',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text3,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          ..._followingArtists.map((a) => _artistRow(a)),
                        ],
                      ],
                    )),
    );
  }
}
