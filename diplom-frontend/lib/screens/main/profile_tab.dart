import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../artist_screen.dart';
import '../edit_profile_screen.dart';
import '../extra_screens.dart';
import '../library_screen.dart';
import '../notifications_screen.dart';
import '../settings_screen.dart';
import '../stats_screen.dart';

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
  List<Map<String, dynamic>> _followedArtists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadStats(), _loadFollowedArtists()]);
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService().getUserStats();
      if (!mounted) return;
      setState(() {
        _followersCount = data['followers_count'] as int? ?? 0;
        _followingCount = data['following_count'] as int? ?? 0;
        _userId = data['user_id'] as int?;
        _statsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoaded = true);
    }
  }

  void _openFollowersList() {
    if (_userId == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _UsersListScreen(
        title: 'Followers',
        userId: _userId!,
        mode: 'followers',
      ),
    ));
  }

  void _openFollowingList() {
    if (_userId == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _UsersListScreen(
        title: 'Following',
        userId: _userId!,
        mode: 'following',
      ),
    ));
  }

  Future<void> _loadFollowedArtists() async {
    try {
      final list = await ApiService().getFollowedArtistsDetails();
      if (!mounted) return;
      setState(() {
        _followedArtists = list.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final username = user?['username'] ?? '';
    final city = user?['city'] ?? '';
    final bio = user?['bio'] as String? ?? '';
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final bannerUrl = user?['banner_url'] as String? ?? '';
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
              // Banner
              Stack(
                clipBehavior: Clip.none,
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
                            child: CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox(),
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        Center(
                          child: Container(
                            width: 200, height: 200,
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
                          top: 0, right: 20,
                          child: SafeArea(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.settings_rounded, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar & Edit row
                  Positioned(
                    bottom: -40,
                    left: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 82, height: 82,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: avatarColors.cast<Color>(),
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.purpleDark.withOpacity(0.4),
                                    blurRadius: 20),
                              ],
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 32, fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (user == null) return;
                              final saved = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    user: Map<String, dynamic>.from(user),
                                  ),
                                ),
                              );
                              if (mounted && saved == true) {
                                _load();
                              } else if (mounted) {
                                setState(() {});
                              }
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
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.text)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 52),

              // Name, handle, bio
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 24, fontWeight: FontWeight.w800,
                            color: AppColors.text, letterSpacing: -0.5)),
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
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(bio,
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2, height: 1.5)),
                    ],
                  ],
                ),
              ),

              // Stats — Followers / Following (clickable)
              const SizedBox(height: 14),
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
                      Expanded(child: GestureDetector(
                        onTap: _openFollowersList,
                        child: _StatCell(
                          value: _statsLoaded ? '${_followersCount ?? 0}' : '—',
                          label: 'Followers',
                        ),
                      )),
                      Container(width: 1, height: 54, color: AppColors.border),
                      Expanded(child: GestureDetector(
                        onTap: _openFollowingList,
                        child: _StatCell(
                          value: _statsLoaded ? '${_followingCount ?? 0}' : '—',
                          label: 'Following',
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              // Followed Artists
              if (_followedArtists.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Text('Following',
                        style: GoogleFonts.outfit(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const Spacer(),
                    Text('${_followedArtists.length}',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3)),
                  ]),
                ),
                const SizedBox(height: 10),
                ...(_followedArtists.take(5).map((artist) {
                  final pic = (artist['picture_medium'] ?? artist['picture_xl'] ?? artist['picture'] ?? '').toString();
                  final name = (artist['name'] ?? '').toString();
                  final fans = artist['nb_fan'];
                  final fansNum = fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
                  final fansStr = fansNum >= 1000000
                      ? '${(fansNum / 1000000).toStringAsFixed(1)}M followers'
                      : fansNum >= 1000
                          ? '${(fansNum / 1000).toStringAsFixed(0)}K followers'
                          : fansNum > 0 ? '$fansNum followers' : 'Artist';
                  return GestureDetector(
                    onTap: () {
                      final id = artist['id'];
                      if (id != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ArtistScreen(artistId: id.toString(), artistName: name),
                        ));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradMixed),
                          child: ClipOval(child: pic.isNotEmpty
                              ? CachedNetworkImage(imageUrl: pic, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))))
                              : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                          Text(fansStr, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                        ])),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 20),
                      ]),
                    ),
                  );
                })),
                if (_followedArtists.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _AllFollowedArtistsScreen(artists: _followedArtists),
                      )),
                      child: Text('Show all (${_followedArtists.length})',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.purpleLight,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],

              // Quick access
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('My Pages',
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _NavRow(icon: '📚', label: 'Library', sub: 'Your playlists & albums',
                      color: AppColors.blue,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LibraryScreen()))),
                  _NavRow(icon: '🕐', label: 'Listening History', sub: 'Recently played by day',
                      color: AppColors.cyan,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RecentHistoryScreen()))),
                  _NavRow(icon: '📊', label: 'My Stats', sub: 'Top artists, genres & more',
                      color: AppColors.purple,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StatsScreen()))),
                  _NavRow(icon: '🔔', label: 'Notifications', sub: 'Matches, friends, music',
                      color: AppColors.pink,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
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

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3, fontWeight: FontWeight.w500)),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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

// ─── Followers / Following list screen ───────────────────────────────────────

class _UsersListScreen extends StatefulWidget {
  final String title;
  final int userId;
  final String mode; // 'followers' | 'following'
  const _UsersListScreen({required this.title, required this.userId, required this.mode});

  @override
  State<_UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<_UsersListScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = widget.mode == 'followers'
          ? await ApiService().getUserFollowers(widget.userId)
          : await ApiService().getUserFollowing(widget.userId);
      if (!mounted) return;
      setState(() { _users = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: Text(widget.title,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Text('Nothing here yet',
                  style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    final name = (u['display_name'] ?? u['username'] ?? '').toString();
                    final uname = (u['username'] ?? '').toString();
                    final avatar = (u['avatar_url'] ?? '').toString();
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradMixed),
                          child: ClipOval(
                            child: avatar.isNotEmpty
                                ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Center(child: Text(initial,
                                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))))
                                : Center(child: Text(initial,
                                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                          if (uname.isNotEmpty)
                            Text('@$uname', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                        ])),
                      ]),
                    );
                  },
                ),
    );
  }
}

// ─── All followed artists screen ──────────────────────────────────────────────

class _AllFollowedArtistsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> artists;
  const _AllFollowedArtistsScreen({required this.artists});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        title: Text('Following',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: artists.length,
        itemBuilder: (context, i) {
          final artist = artists[i];
          final pic = (artist['picture_medium'] ?? artist['picture_xl'] ?? artist['picture'] ?? '').toString();
          final name = (artist['name'] ?? '').toString();
          final fans = artist['nb_fan'];
          final fansNum = fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
          final fansStr = fansNum >= 1000000
              ? '${(fansNum / 1000000).toStringAsFixed(1)}M followers'
              : fansNum >= 1000
                  ? '${(fansNum / 1000).toStringAsFixed(0)}K followers'
                  : fansNum > 0 ? '$fansNum followers' : 'Artist';
          return GestureDetector(
            onTap: () {
              final id = artist['id'];
              if (id != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ArtistScreen(artistId: id.toString(), artistName: name),
                ));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradMixed),
                  child: ClipOval(child: pic.isNotEmpty
                      ? CachedNetworkImage(imageUrl: pic, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))))
                      : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(fansStr, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}
