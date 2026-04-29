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
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SocialScreen(userId: _userId!, initialTab: 0),
        ));
  }

  void _openFollowingList() {
    if (_userId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SocialScreen(userId: _userId!, initialTab: 1),
        ));
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
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final username = user?['username'] ?? '';
    final city = user?['city'] ?? '';
    final bio = user?['bio'] as String? ?? '';
    final avatarUrl = user?['avatar_url'] as String? ?? '';
    final bannerUrl = user?['banner_url'] as String? ?? '';
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
                            child: CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox(),
                              errorWidget: (_, __, ___) => const SizedBox(),
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
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppColors.purpleDark.withOpacity(0.4),
                                    blurRadius: 20),
                              ],
                            ),
                            child: avatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      width: 82,
                                      height: 82,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Center(
                                        child: Text(initial,
                                            style: GoogleFonts.outfit(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white)),
                                      ),
                                      errorWidget: (_, __, ___) => Center(
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

              // Stats — Followers / Following (clickable)
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Connections',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openFollowingList,
                      child: Text(
                        'See all',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.purpleLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                      Expanded(
                          child: GestureDetector(
                        onTap: _openFollowersList,
                        child: _StatCell(
                          value: _statsLoaded ? '${_followersCount ?? 0}' : '—',
                          label: 'Followers',
                        ),
                      )),
                      Container(width: 1, height: 54, color: AppColors.border),
                      Expanded(
                          child: GestureDetector(
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500)),
        ],
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

// ─── Followers / Following combined screen ────────────────────────────────────

class _SocialScreen extends StatefulWidget {
  final int userId;
  final int initialTab; // 0 = Followers, 1 = Following
  const _SocialScreen({required this.userId, required this.initialTab});

  @override
  State<_SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<_SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _followingUsers = [];
  List<Map<String, dynamic>> _followingArtists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService()
            .getUserFollowers(widget.userId)
            .catchError((_) => <Map<String, dynamic>>[]),
        ApiService()
            .getUserFollowing(widget.userId)
            .catchError((_) => <Map<String, dynamic>>[]),
        ApiService()
            .getFollowedArtistsDetails()
            .then((list) => list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList())
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _followingUsers = results[1];
        _followingArtists = results[2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _userRow(Map<String, dynamic> u) {
    final name = (u['display_name'] ?? u['username'] ?? '').toString();
    final uname = (u['username'] ?? '').toString();
    final avatar = (u['avatar_url'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          if (uname.isNotEmpty)
            Text('@$uname',
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
      ]),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                  text: _loading
                      ? 'Followers'
                      : 'Followers (${_followers.length})'),
              Tab(
                  text: _loading
                      ? 'Following'
                      : 'Following (${followingAll.length})'),
            ],
            labelStyle:
                GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.text3,
            indicatorColor: AppColors.purpleLight,
            indicatorWeight: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight))
          : TabBarView(
              controller: _tabController,
              children: [
                // ── Followers tab ──────────────────────────────────────
                _followers.isEmpty
                    ? _emptyState('No followers yet')
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: _followers.map((u) => _userRow(u)).toList()),

                // ── Following tab (users + artists) ────────────────────
                followingAll.isEmpty
                    ? _emptyState('Not following anyone yet')
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ..._followingUsers.map((u) => _userRow(u)),
                          ..._followingArtists.map((a) => _artistRow(a)),
                        ],
                      ),
              ],
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
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: artists.length,
        itemBuilder: (context, i) {
          final artist = artists[i];
          final pic = (artist['picture_medium'] ??
                  artist['picture_xl'] ??
                  artist['picture'] ??
                  '')
              .toString();
          final name = (artist['name'] ?? '').toString();
          final fans = artist['nb_fan'];
          final fansNum =
              fans is int ? fans : int.tryParse(fans?.toString() ?? '') ?? 0;
          final fansStr = fansNum >= 1000000
              ? '${(fansNum / 1000000).toStringAsFixed(1)}M followers'
              : fansNum >= 1000
                  ? '${(fansNum / 1000).toStringAsFixed(0)}K followers'
                  : fansNum > 0
                      ? '$fansNum followers'
                      : 'Artist';
          return GestureDetector(
            onTap: () {
              final id = artist['id'];
              if (id != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistScreen(
                          artistId: id.toString(), artistName: name),
                    ));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, gradient: AppColors.gradMixed),
                  child: ClipOval(
                      child: pic.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: pic,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                  child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                          : Center(
                              child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)))),
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
                      Text(fansStr,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3)),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.text3, size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}
