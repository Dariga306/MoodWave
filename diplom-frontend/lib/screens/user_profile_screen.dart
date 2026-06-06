import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';
import '../utils/media_url.dart';
import 'chat_screen.dart';
import 'modals.dart' as modals;
import 'player_screen.dart';
import 'playlist_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? initialUser;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _nowPlaying;
  String _presenceStatus = '';
  String _lastSeenAt = '';
  String _activityStatus = '';
  bool _loading = true;
  bool _followBusy = false;
  bool _messageBusy = false;

  Map<String, dynamic> get _user => Map<String, dynamic>.from(
      (_data?['user'] as Map?) ?? widget.initialUser ?? {});
  Map<String, dynamic> get _relation =>
      Map<String, dynamic>.from((_data?['relation'] as Map?) ?? {});
  List<Map<String, dynamic>> get _playlists =>
      ((_data?['playlists'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
        ..sort((a, b) => (b['updated_at']?.toString() ?? '').compareTo(
              a['updated_at']?.toString() ?? '',
            ));
  List<Map<String, dynamic>> get _recentTracks => _condenseRecentTracks(
        ((_data?['recent_tracks'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort((a, b) => (b['played_at']?.toString() ?? '').compareTo(
                a['played_at']?.toString() ?? '',
              )),
      );
  List<Map<String, dynamic>> get _favoriteArtists =>
      ((_data?['favorite_artists'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
  Map<String, dynamic> get _playlistStats =>
      Map<String, dynamic>.from((_data?['playlist_stats'] as Map?) ?? {});

  String get _displayName => (_user['display_name'] ??
          _user['first_name'] ??
          _user['username'] ??
          'User')
      .toString();
  String get _username => (_user['username'] ?? '').toString();
  String get _city => (_user['city'] ?? '').toString();
  String get _bio => (_user['bio'] ?? '').toString();
  String get _gender => (_user['gender'] ?? '').toString();
  Object? get _mediaVersion => _user['updated_at'];
  String get _avatarUrl => buildMediaUrl(
        (_user['avatar_url'] ?? '').toString(),
        version: _mediaVersion,
      );
  String get _bannerUrl => buildMediaUrl(
        (_user['banner_url'] ?? '').toString(),
        version: _mediaVersion,
      );
  List<String> get _genres => ((_user['genres'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();

  bool get _musicTasteHidden => _user['hide_music_taste'] == true;
  bool get _followersVisible =>
      _relation['is_self'] == true || _user['show_followers'] != false;

  String? get _friendStatusText {
    final status = (_relation['friend_request_status'] ?? 'none').toString();
    switch (status) {
      case 'accepted':
        return 'Friends';
      default:
        return null;
    }
  }

  String get _pronouns {
    switch (_gender.toLowerCase().trim()) {
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
        return _gender;
    }
  }

  List<String> get _visibleGenres {
    final unique = <String>{};
    final ordered = <String>[];
    for (final genre in _genres) {
      final normalized = genre.trim();
      if (normalized.isEmpty) continue;
      if (unique.add(normalized.toLowerCase())) {
        ordered.add(normalized);
      }
      if (ordered.length == 3) break;
    }
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    MiniPlayerOverlayController.suppress();
    _load();
  }

  @override
  void dispose() {
    MiniPlayerOverlayController.unsuppress();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService().getUserProfileSummary(widget.userId),
        ApiService().getUserNowPlaying(widget.userId).then((v) => v ?? {}),
      ]);
      if (!mounted) return;
      final data = results[0] as Map<String, dynamic>;
      final nowPlayingData = results[1] as Map<String, dynamic>;
      setState(() {
        _data = data;
        _nowPlaying = nowPlayingData['now_playing'] != null
            ? Map<String, dynamic>.from(nowPlayingData['now_playing'] as Map)
            : null;
        _presenceStatus = (nowPlayingData['presence_status'] ?? '').toString();
        _lastSeenAt = (nowPlayingData['last_seen_at'] ?? '').toString();
        _activityStatus = (nowPlayingData['activity_status'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _profileShareLink {
    final handle = _username.isNotEmpty ? _username : 'user-${widget.userId}';
    return 'https://moodwave.app/profile/$handle';
  }

  Future<void> _shareProfile() async {
    modals.showShareProfile(
      context,
      profile: {
        ..._user,
        'id': widget.userId,
        'profile_url': _profileShareLink,
      },
    );
  }

  Future<void> _copyProfileLink() async {
    await Clipboard.setData(ClipboardData(text: _profileShareLink));
    if (!mounted) return;
    _showSnack('Profile link copied');
  }

  Future<void> _copyUsername() async {
    if (_username.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: '@$_username'));
    if (!mounted) return;
    _showSnack('Username copied');
  }

  String get _presenceLabel {
    if (_activityStatus == 'live' && _nowPlaying != null) {
      return 'Listening now';
    }
    if (_activityStatus == 'recent' && _nowPlaying != null) {
      return 'Listened recently';
    }
    if (_presenceStatus == 'online') {
      return 'Online';
    }
    if (_lastSeenAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(_lastSeenAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) return 'Last seen just now';
        if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
        if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
        return 'Last seen ${diff.inDays}d ago';
      } catch (_) {}
    }
    return 'Offline';
  }

  Future<void> _toggleBlock() async {
    final blockedByMe = _relation['blocked_by_me'] == true;
    try {
      if (blockedByMe) {
        await ApiService().unblockUser(widget.userId);
        if (!mounted) return;
        _setBlockedByMe(false);
        _showSnack('User unblocked');
      } else {
        await ApiService().blockUser(widget.userId);
        if (!mounted) return;
        _setBlockedByMe(true);
        _showSnack('User blocked');
      }
      await _load();
    } on DioException catch (e) {
      final detail = _detailFromError(e, fallback: '');
      if (!blockedByMe && detail.toLowerCase().contains('already blocked')) {
        if (!mounted) return;
        _setBlockedByMe(true);
        _showSnack('User blocked');
        await _load();
        return;
      }
      if (blockedByMe && detail.toLowerCase().contains('block not found')) {
        if (!mounted) return;
        _setBlockedByMe(false);
        _showSnack('User unblocked');
        await _load();
        return;
      }
      _showSnack(
        _detailFromError(e,
            fallback: blockedByMe
                ? 'Could not unblock user'
                : 'Could not block user'),
        isError: true,
      );
    } catch (_) {
      _showSnack(
          blockedByMe ? 'Could not unblock user' : 'Could not block user',
          isError: true);
    }
  }

  Future<void> _showProfileMenu() async {
    final blockedByMe = _relation['blocked_by_me'] == true;
    MiniPlayerOverlayController.suppress();
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          Widget item(IconData icon, String label, VoidCallback onTap,
              {Color? color}) {
            final resolvedColor = color ?? AppColors.text;
            return InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: resolvedColor, size: 20),
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: resolvedColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  item(Icons.share_outlined, 'Share profile', () {
                    Navigator.pop(ctx);
                    _shareProfile();
                  }),
                  item(Icons.link_rounded, 'Copy profile link', () {
                    Navigator.pop(ctx);
                    _copyProfileLink();
                  }),
                  if (_username.isNotEmpty)
                    item(Icons.alternate_email_rounded, 'Copy username', () {
                      Navigator.pop(ctx);
                      _copyUsername();
                    }),
                  item(Icons.queue_music_rounded, 'View playlists', () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _UserProfileCollectionScreen(
                          userId: widget.userId,
                          userName: _displayName,
                          mode: _CollectionMode.playlists,
                        ),
                      ),
                    );
                  }),
                  item(
                    blockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
                    blockedByMe ? 'Unblock user' : 'Block user',
                    () {
                      Navigator.pop(ctx);
                      _toggleBlock();
                    },
                    color: blockedByMe
                        ? AppColors.text
                        : const Color(0xFFFF7676),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      MiniPlayerOverlayController.unsuppress();
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _relation['is_self'] == true) return;
    setState(() => _followBusy = true);
    try {
      if (_relation['is_following'] == true) {
        await ApiService().unfollowUser(widget.userId);
      } else {
        await ApiService().followUser(widget.userId);
      }
      await _load();
    } on DioException catch (e) {
      _showSnack(
          _detailFromError(e, fallback: 'Could not update follow status'),
          isError: true);
    } catch (_) {
      _showSnack('Could not update follow status', isError: true);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openChat() async {
    if (_messageBusy || _relation['is_self'] == true) return;
    setState(() => _messageBusy = true);
    try {
      final matchId = _relation['match_id'] as int?;
      final existingChatId = _relation['chat_id'] as int?;

      if (!mounted) return;
      if (existingChatId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: existingChatId,
              partnerName: _displayName,
              partnerId: widget.userId,
              partnerAvatarUrl: _avatarUrl,
            ),
          ),
        );
        return;
      }
      if (matchId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchId: matchId,
              partnerName: _displayName,
              partnerId: widget.userId,
              partnerAvatarUrl: _avatarUrl,
            ),
          ),
        );
        return;
      }

      final direct = await ApiService().startDirectChat(widget.userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: direct['chat_id'] as int?,
            partnerName: _displayName,
            partnerId: widget.userId,
            partnerAvatarUrl: _avatarUrl,
          ),
        ),
      );
      await _load();
    } on DioException catch (e) {
      if (e.response?.statusCode != 403) {
        _showSnack(_detailFromError(e, fallback: 'Could not open chat'),
            isError: true);
      }
    } catch (_) {
      _showSnack('Could not open chat', isError: true);
    } finally {
      if (mounted) setState(() => _messageBusy = false);
    }
  }

  void _openFollowers() {
    if (!_followersVisible) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileConnectionsScreen(
          userId: widget.userId,
          mode: _ProfileConnectionMode.followers,
          title: 'Followers',
        ),
      ),
    );
  }

  void _openFollowing() {
    if (!_followersVisible) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileConnectionsScreen(
          userId: widget.userId,
          mode: _ProfileConnectionMode.following,
          title: 'Following',
        ),
      ),
    );
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFF7f1d1d) : AppColors.surface,
      ),
    );
  }

  void _setBlockedByMe(bool value) {
    final next = Map<String, dynamic>.from(_data ?? const {});
    final relation = Map<String, dynamic>.from(
      (next['relation'] as Map?) ?? const {},
    );
    relation['blocked_by_me'] = value;
    next['relation'] = relation;
    setState(() => _data = next);
  }

  String _detailFromError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: _loading && _data == null
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.purpleLight,
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.purpleLight,
                  backgroundColor: AppColors.surface,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.zero,
                    children: [
                      _ProfileHeroBanner(
                        bannerUrl: _bannerUrl,
                        avatarUrl: _avatarUrl,
                        displayName: _displayName,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (_username.isNotEmpty) '@$_username',
                                if (_city.isNotEmpty) _city,
                                if (_pronouns.isNotEmpty) _pronouns,
                              ].join(' · '),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.text3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _presenceLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _presenceStatus == 'online' ||
                                        _activityStatus == 'live'
                                    ? AppColors.green
                                    : _activityStatus == 'recent'
                                        ? const Color(0xFFFACC15)
                                        : AppColors.text3,
                              ),
                            ),
                            if (_bio.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _bio,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppColors.text2,
                                ),
                              ),
                            ],
                            if (_nowPlaying != null) ...[
                              const SizedBox(height: 12),
                              _NowPlayingBadge(nowPlaying: _nowPlaying!),
                            ],
                            const SizedBox(height: 14),
                            _StatsRow(
                              followersCount: _user['followers_count'] as int?,
                              followingCount: _user['following_count'] as int?,
                              hidden: !_followersVisible,
                              onFollowersTap:
                                  _followersVisible ? _openFollowers : null,
                              onFollowingTap:
                                  _followersVisible ? _openFollowing : null,
                            ),
                            if (_relation['is_self'] != true) ...[
                              const SizedBox(height: 18),
                              _ActionRow(
                                following: _relation['is_following'] == true,
                                friendStatus:
                                    (_relation['friend_request_status'] ??
                                            'none')
                                        .toString(),
                                followBusy: _followBusy,
                                messageBusy: _messageBusy,
                                onFollow: _toggleFollow,
                                onMessage: _openChat,
                              ),
                            ],
                            if (!_musicTasteHidden &&
                                (_visibleGenres.isNotEmpty ||
                                    _favoriteArtists.isNotEmpty)) ...[
                              const SizedBox(height: 24),
                              _MusicTasteSummary(
                                genres: _visibleGenres,
                                artists: _favoriteArtists,
                              ),
                            ],
                            const SizedBox(height: 32),
                            _SectionHeader(
                              title: 'Playlists',
                              subtitle: _playlistSubtitle(),
                              trailingLabel:
                                  _playlists.isNotEmpty ? 'See all' : null,
                              onTrailingTap: _playlists.isNotEmpty
                                  ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              _UserProfileCollectionScreen(
                                            userId: widget.userId,
                                            userName: _displayName,
                                            mode: _CollectionMode.playlists,
                                          ),
                                        ),
                                      )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (_playlists.isEmpty)
                              const _EmptyCard(
                                icon: Icons.queue_music_rounded,
                                title: 'No visible playlists',
                                subtitle:
                                    'Public and accessible playlists will appear here.',
                              )
                            else
                              ..._playlists.take(3).map(
                                    (p) => _PlaylistCard(playlist: p),
                                  ),
                            if ((_playlistStats['hidden_private_count']
                                        as int? ??
                                    0) >
                                0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${_playlistStats['hidden_private_count']} private playlists are hidden',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ),
                            if (_recentTracks.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _SectionHeader(
                                title: 'Recently Played',
                                subtitle: 'Latest music from this profile',
                                trailingLabel:
                                    _recentTracks.isNotEmpty ? 'See all' : null,
                                onTrailingTap: _recentTracks.isNotEmpty
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                _UserProfileCollectionScreen(
                                              userId: widget.userId,
                                              userName: _displayName,
                                              mode: _CollectionMode.recent,
                                            ),
                                          ),
                                        )
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              ..._recentTracks.take(5).map(
                                    (t) => _RecentTrackItem(track: t),
                                  ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Floating back button that stays visible during scroll
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_relation['is_self'] != true)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: GestureDetector(
                          onTap: _showProfileMenu,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.42),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _playlistSubtitle() {
    final publicCount = (_playlistStats['public'] as int?) ?? 0;
    final friendsCount = (_playlistStats['friends'] as int?) ?? 0;
    final parts = <String>[
      if (publicCount > 0) '$publicCount public',
      if (friendsCount > 0) '$friendsCount friends-only',
    ];
    return parts.isEmpty
        ? 'Music collections from this user'
        : parts.join(' · ');
  }
}

// ──────────────────────────────────────────────────────────────
// Banner hero — scrolls with the page, no back button
// ──────────────────────────────────────────────────────────────

class _ProfileHeroBanner extends StatelessWidget {
  final String bannerUrl;
  final String avatarUrl;
  final String displayName;

  const _ProfileHeroBanner({
    required this.bannerUrl,
    required this.avatarUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      width: double.infinity,
      height: 200 + topPadding,
      child: Stack(
        children: [
          // Banner background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a0e2e), Color(0xFF2d1b4e), AppColors.bg],
                ),
              ),
            ),
          ),
          // Banner image
          if (bannerUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
          // Bottom fade overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.38),
                    AppColors.bg,
                  ],
                  stops: const [0, 0.68, 1],
                ),
              ),
            ),
          ),
          // Avatar overlapping the bottom of the banner
          Positioned(
            left: 20,
            bottom: 0,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
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
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicTasteSummary extends StatelessWidget {
  final List<String> genres;
  final List<Map<String, dynamic>> artists;

  const _MusicTasteSummary({
    required this.genres,
    required this.artists,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withOpacity(0.94),
            AppColors.surface2.withOpacity(0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Music Taste',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  genres.map((genre) => _GenreChip(label: genre)).toList(),
            ),
          ],
          if (artists.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artists.length.clamp(0, 5),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => _ArtistCircle(artist: artists[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Stats row
// ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;
  final bool hidden;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const _StatsRow({
    required this.followersCount,
    required this.followingCount,
    this.hidden = false,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          value: followersCount,
          label: 'Followers',
          hidden: hidden,
          onTap: onFollowersTap,
        ),
        const SizedBox(width: 20),
        _StatItem(
          value: followingCount,
          label: 'Following',
          hidden: hidden,
          onTap: onFollowingTap,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final int? value;
  final String label;
  final bool hidden;
  final VoidCallback? onTap;

  const _StatItem({
    required this.value,
    required this.label,
    this.hidden = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hidden ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: hidden ? '—' : '${value ?? 0}',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.purpleLight,
              ),
            ),
            TextSpan(
              text: hidden ? '  $label hidden' : '  $label',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Action buttons
// ──────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool following;
  final String friendStatus;
  final bool followBusy;
  final bool messageBusy;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  const _ActionRow({
    required this.following,
    required this.friendStatus,
    required this.followBusy,
    required this.messageBusy,
    required this.onFollow,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: following ? 'Following' : 'Follow',
            filled: !following,
            loading: followBusy,
            onTap: onFollow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Message',
            filled: true,
            loading: messageBusy,
            onTap: onMessage,
          ),
        ),
      ],
    );
  }
}

class _FriendStatusBadge extends StatelessWidget {
  final String text;
  const _FriendStatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.purpleLight.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.purpleLight,
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;

  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.text2,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: filled ? AppColors.primaryBtn : null,
          color: filled ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : AppColors.text,
                  ),
                ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Now Playing Badge
// ──────────────────────────────────────────────────────────────

class _NowPlayingBadge extends StatefulWidget {
  final Map<String, dynamic> nowPlaying;
  const _NowPlayingBadge({required this.nowPlaying});

  @override
  State<_NowPlayingBadge> createState() => _NowPlayingBadgeState();
}

class _NowPlayingBadgeState extends State<_NowPlayingBadge>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    final speeds = [600, 820, 520, 740];
    _bars = speeds
        .map((ms) => AnimationController(
              vsync: this,
              duration: Duration(milliseconds: ms),
            )..repeat(reverse: true))
        .toList();
    _anims = [
      Tween<double>(begin: 0.25, end: 1.0)
          .animate(CurvedAnimation(parent: _bars[0], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.5, end: 1.0)
          .animate(CurvedAnimation(parent: _bars[1], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.2, end: 0.85)
          .animate(CurvedAnimation(parent: _bars[2], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.4, end: 0.9)
          .animate(CurvedAnimation(parent: _bars[3], curve: Curves.easeInOut)),
    ];
  }

  @override
  void dispose() {
    for (final c in _bars) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.nowPlaying['title'] ?? '').toString().trim();
    final artist = (widget.nowPlaying['artist'] ?? '').toString().trim();
    final coverUrl = (widget.nowPlaying['cover_url'] ?? '').toString();
    final playedAt = widget.nowPlaying['played_at']?.toString();
    final isLive = _isRecent(playedAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLive
              ? [
                  const Color(0xFF4c1d95).withOpacity(0.35),
                  const Color(0xFF7c3aed).withOpacity(0.20),
                ]
              : [
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.02),
                ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive
              ? AppColors.purpleLight.withOpacity(0.3)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          // Cover art or music icon
          if (coverUrl.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _musicIcon(isLive),
              ),
            )
          else
            _musicIcon(isLive),
          const SizedBox(width: 10),
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7c3aed), Color(0xFFec4899)],
                          ),
                          borderRadius: BorderRadius.circular(5),
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
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title.isNotEmpty
                            ? title
                            : (isLive ? 'Listening now' : 'Recently played'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.text2,
                    ),
                  ),
              ],
            ),
          ),
          // Animated bars if live, else time ago
          if (isLive)
            AnimatedBuilder(
              animation: Listenable.merge(_bars),
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (i) {
                  return Container(
                    width: 2.5,
                    height: 20 * _anims[i].value,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            )
          else if (playedAt != null)
            Text(
              _relTime(playedAt),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.text3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _musicIcon(bool isLive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isLive
            ? AppColors.purpleDark.withOpacity(0.4)
            : Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 18,
        color: isLive ? AppColors.purpleLight : AppColors.text3,
      ),
    );
  }

  bool _isRecent(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    try {
      final normalized =
          (iso.endsWith('Z') || iso.contains('+')) ? iso : '${iso}Z';
      final dt = DateTime.parse(normalized).toLocal();
      return DateTime.now().difference(dt).inMinutes < 5;
    } catch (_) {
      return false;
    }
  }

  String _relTime(String iso) {
    try {
      final normalized =
          (iso.endsWith('Z') || iso.contains('+')) ? iso : '${iso}Z';
      final dt = DateTime.parse(normalized).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Shared section header
// ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.text3,
                  ),
                ),
            ],
          ),
        ),
        if (trailingLabel != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.purpleLight,
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Genre chip
// ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.purpleLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Favorite artist circle (Spotify-style horizontal list)
// ──────────────────────────────────────────────────────────────

class _ArtistCircle extends StatelessWidget {
  final Map<String, dynamic> artist;

  const _ArtistCircle({required this.artist});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (artist['picture_medium'] ??
            artist['picture_big'] ??
            artist['picture_xl'] ??
            artist['picture'] ??
            artist['image_url'] ??
            '')
        .toString();
    final name = (artist['name'] ?? 'Artist').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.purpleDark.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: imageUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Playlist card
// ──────────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final title = (playlist['title'] ?? 'Playlist').toString();
    final description = (playlist['description'] ?? '').toString();
    final coverUrl = (playlist['cover_url'] ?? '').toString();
    final visibility = (playlist['visibility'] ?? 'public').toString();
    final trackCount = playlist['track_count'] ?? 0;
    final playlistId = playlist['id'] as int?;

    return GestureDetector(
      onTap: playlistId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistScreen(playlistId: playlistId),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withOpacity(0.94),
              AppColors.surface2.withOpacity(0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white70),
                      ),
                    )
                  : const Icon(Icons.queue_music_rounded,
                      color: Colors.white70),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description.isNotEmpty ? description : '$trackCount tracks',
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
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.purple.withOpacity(0.24)),
              ),
              child: Text(
                visibility,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purpleLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent track item
// ──────────────────────────────────────────────────────────────

class _RecentTrackItem extends StatelessWidget {
  final Map<String, dynamic> track;
  const _RecentTrackItem({required this.track});

  @override
  Widget build(BuildContext context) {
    final title = (track['title'] ?? 'Unknown track').toString();
    final artist = (track['artist'] ?? '').toString();
    final album = (track['album'] ?? '').toString();
    final coverUrl = (track['cover_url'] ?? '').toString();
    final playedAt = (track['played_at'] ?? '').toString();
    final playCount = (track['play_count'] as num?)?.toInt() ?? 1;
    final subtitleParts = <String>[
      if (artist.isNotEmpty) artist,
      if (album.isNotEmpty) 'Album · $album',
      if (playCount > 1) '$playCount plays',
    ];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white70),
                      ),
                    )
                  : const Icon(Icons.music_note_rounded, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
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

// ──────────────────────────────────────────────────────────────
// Empty state card
// ──────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.glass,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.text2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
    );
  }
}

enum _ProfileConnectionMode { followers, following }

class _ProfileConnectionsScreen extends StatefulWidget {
  final int userId;
  final _ProfileConnectionMode mode;
  final String title;

  const _ProfileConnectionsScreen({
    required this.userId,
    required this.mode,
    required this.title,
  });

  @override
  State<_ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState extends State<_ProfileConnectionsScreen> {
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _followingUsers = [];
  List<Map<String, dynamic>> _followingArtists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = widget.mode == _ProfileConnectionMode.followers
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
        if (widget.mode == _ProfileConnectionMode.followers) {
          _followers = results[0] as List<Map<String, dynamic>>;
        } else {
          _followingUsers = results[0] as List<Map<String, dynamic>>;
          _followingArtists = results[1] as List<Map<String, dynamic>>;
        }
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Could not load')
            : 'Could not load';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load';
      });
    }
  }

  Widget _userRow(Map<String, dynamic> user) {
    final name =
        (user['display_name'] ?? user['username'] ?? 'User').toString();
    final username = (user['username'] ?? '').toString();
    final avatar = buildMediaUrl(
      user['avatar_url']?.toString(),
      version: user['updated_at'],
    );
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final rawId = user['id'] ??
        user['user_id'] ??
        user['following_id'] ??
        user['follower_id'] ??
        user['followed_id'];
    final userId =
        rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: userId == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: userId,
                      initialUser: {
                        ...user,
                        'id': userId,
                      },
                    ),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.gradMixed,
                ),
                child: ClipOval(
                  child: avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.text3,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artistRow(Map<String, dynamic> artist) {
    final name = (artist['name'] ?? '').toString();
    final image = (artist['picture_medium'] ??
            artist['picture_xl'] ??
            artist['picture'] ??
            '')
        .toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradPurple,
            ),
            child: ClipOval(
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
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
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followingAll = [..._followingUsers, ..._followingArtists];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          widget.title,
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
                strokeWidth: 2,
                color: AppColors.purpleLight,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                )
              : widget.mode == _ProfileConnectionMode.followers
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _followers.isEmpty
                          ? [
                              const _EmptyCard(
                                icon: Icons.people_outline_rounded,
                                title: 'No followers yet',
                                subtitle: 'Check back later.',
                              ),
                            ]
                          : _followers.map((item) => _userRow(item)).toList(),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: followingAll.isEmpty
                          ? [
                              const _EmptyCard(
                                icon: Icons.people_outline_rounded,
                                title: 'Not following anyone yet',
                                subtitle: 'Check back later.',
                              ),
                            ]
                          : [
                              if (_followingUsers.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 6, 20, 4),
                                  child: Text(
                                    'People',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text3,
                                    ),
                                  ),
                                ),
                                ..._followingUsers
                                    .map((item) => _userRow(item)),
                              ],
                              if (_followingArtists.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 14, 20, 4),
                                  child: Text(
                                    'Artists',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text3,
                                    ),
                                  ),
                                ),
                                ..._followingArtists
                                    .map((item) => _artistRow(item)),
                              ],
                            ],
                    ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Full collection screen (playlists or recent)
// ──────────────────────────────────────────────────────────────

enum _CollectionMode { playlists, recent }

class _UserProfileCollectionScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final _CollectionMode mode;

  const _UserProfileCollectionScreen({
    required this.userId,
    required this.userName,
    required this.mode,
  }) : super();

  @override
  State<_UserProfileCollectionScreen> createState() =>
      _UserProfileCollectionScreenState();
}

class _UserProfileCollectionScreenState
    extends State<_UserProfileCollectionScreen> {
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _recentTracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getUserProfileSummary(
        widget.userId,
        playlistLimit: 20,
        tracksLimit: 20,
      );
      final playlists = ((data['playlists'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
        ..sort((a, b) => (b['updated_at']?.toString() ?? '').compareTo(
              a['updated_at']?.toString() ?? '',
            ));
      final recentTracks = ((data['recent_tracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _recentTracks = _condenseRecentTracks(recentTracks);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsMode = widget.mode == _CollectionMode.playlists;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          playlistsMode
              ? '${widget.userName} · Playlists'
              : '${widget.userName} · Recently Played',
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
                strokeWidth: 2,
                color: AppColors.purpleLight,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.purpleLight,
              backgroundColor: AppColors.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: playlistsMode
                    ? (_playlists.isEmpty
                        ? const [
                            _EmptyCard(
                              icon: Icons.queue_music_rounded,
                              title: 'No playlists to show',
                              subtitle:
                                  'Visible playlists will appear here when available.',
                            ),
                          ]
                        : _playlists
                            .map(
                                (playlist) => _PlaylistCard(playlist: playlist))
                            .toList())
                    : (_recentTracks.isEmpty
                        ? const [
                            _EmptyCard(
                              icon: Icons.history_rounded,
                              title: 'No recent tracks',
                              subtitle:
                                  'Shared listening history will appear here.',
                            ),
                          ]
                        : _recentTracks
                            .map((track) => _RecentTrackItem(track: track))
                            .toList()),
              ),
            ),
    );
  }
}

String _relTime(String iso) {
  if (iso.isEmpty) return '';
  try {
    final normalized =
        (iso.endsWith('Z') || iso.contains('+')) ? iso : '${iso}Z';
    final dt = DateTime.parse(normalized).toLocal();
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

List<Map<String, dynamic>> _condenseRecentTracks(
  List<Map<String, dynamic>> tracks,
) {
  final sorted = [...tracks]
    ..sort((a, b) => (b['played_at']?.toString() ?? '').compareTo(
          a['played_at']?.toString() ?? '',
        ));
  final grouped = <String, Map<String, dynamic>>{};
  final ordered = <Map<String, dynamic>>[];

  for (final raw in sorted) {
    final track = Map<String, dynamic>.from(raw);
    final key = [
      (track['spotify_id'] ?? '').toString(),
      (track['title'] ?? '').toString().trim().toLowerCase(),
      (track['artist'] ?? '').toString().trim().toLowerCase(),
      (track['album'] ?? '').toString().trim().toLowerCase(),
    ].join('|');

    final existing = grouped[key];
    if (existing == null) {
      track['play_count'] = 1;
      grouped[key] = track;
      ordered.add(track);
      continue;
    }

    existing['play_count'] =
        ((existing['play_count'] as num?)?.toInt() ?? 1) + 1;
    final currentPlayedAt = (track['played_at'] ?? '').toString();
    final savedPlayedAt = (existing['played_at'] ?? '').toString();
    if (currentPlayedAt.compareTo(savedPlayedAt) > 0) {
      existing['played_at'] = currentPlayedAt;
    }
  }

  return ordered;
}
