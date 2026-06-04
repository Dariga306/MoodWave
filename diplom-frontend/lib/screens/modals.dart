import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import 'album_screen.dart';
import 'artist_screen.dart';

/// Shows Add to Playlist bottom sheet
void showAddToPlaylist(BuildContext context, {Map<String, dynamic>? track}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

/// Shows Share Track bottom sheet
void showShareTrack(BuildContext context, {Map<String, dynamic>? track}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareTrackSheet(track: track),
  );
}

/// Shows Share Playlist bottom sheet
void showSharePlaylist(
  BuildContext context, {
  required Map<String, dynamic> playlist,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareTrackSheet(playlist: playlist),
  );
}

/// Shows Share Profile bottom sheet
void showShareProfile(
  BuildContext context, {
  required Map<String, dynamic> profile,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareTrackSheet(profile: profile),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final Map<String, dynamic>? track;
  const _AddToPlaylistSheet({this.track});
  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  List<dynamic> _playlists = [];
  bool _loading = true;
  final Set<int> _addedIds = {};
  final Set<int> _loadingIds = {};

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final data = await ApiService().getPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToPlaylist(int playlistId) async {
    final track = widget.track;
    if (track == null) return;
    setState(() => _loadingIds.add(playlistId));
    try {
      await ApiService().addTrackToPlaylist(playlistId, {
        'spotify_track_id': track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            '',
        'title': track['title'] ?? track['trackName'] ?? 'Unknown',
        'artist': track['artist'] ?? track['artistName'] ?? '',
        'album': track['album'],
        'cover_url': track['cover_url'] ?? track['artworkUrl100'],
        'preview_url': track['preview_url'] ?? track['previewUrl'],
        'duration_ms': track['duration_ms'] ?? track['trackTimeMillis'] ?? 0,
      });
      if (mounted) setState(() => _addedIds.add(playlistId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added to playlist',
              style: GoogleFonts.outfit(fontSize: 13)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1a1a2e),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Already in playlist or error',
              style: GoogleFonts.outfit(fontSize: 13)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2a0a0a),
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(playlistId));
    }
  }

  Future<void> _createNew() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Playlist',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.purple)),
            filled: true,
            fillColor: AppColors.glass,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text('Create',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      try {
        await ApiService().createPlaylist(ctrl.text.trim());
        await _loadPlaylists();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackTitle = widget.track?['title']?.toString() ??
        widget.track?['trackName']?.toString() ??
        'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ??
        '';
    final coverUrl = widget.track?['cover_url']?.toString() ??
        widget.track?['artworkUrl100']?.toString();
    final duration =
        _fmt(widget.track?['duration_ms'] ?? widget.track?['trackTimeMillis']);
    final subtitle = [artist, if (duration.isNotEmpty) duration]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Add to Playlist',
                style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          // Track preview row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradMixed,
                      borderRadius: BorderRadius.circular(13)),
                  child: coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.network(coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Text('🎵',
                                      style: TextStyle(fontSize: 24)))))
                      : const Center(
                          child: Text('🎵', style: TextStyle(fontSize: 24)))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(trackTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text2)),
                  ])),
            ]),
          ),
          Divider(color: AppColors.border, height: 1),
          // New playlist button
          GestureDetector(
            onTap: _createNew,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.purpleDark.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.purple.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.purpleLight, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Playlist',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purpleLight)),
                  Text('Create a new playlist',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ]),
              ]),
            ),
          ),
          // Real playlists
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight),
            )
          else if (_playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No playlists yet',
                  style:
                      GoogleFonts.outfit(fontSize: 14, color: AppColors.text3)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _playlists.length,
                itemBuilder: (_, i) {
                  final pl = _playlists[i] as Map<String, dynamic>;
                  final plId = pl['id'] as int? ?? 0;
                  final plTitle = pl['title']?.toString() ?? 'Playlist';
                  final trackCount = pl['track_count'] ?? 0;
                  final isAdded = _addedIds.contains(plId);
                  final isLoading = _loadingIds.contains(plId);
                  return GestureDetector(
                    onTap: isAdded || isLoading
                        ? null
                        : () => _addToPlaylist(plId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Color(0x08FFFFFF)))),
                      child: Row(children: [
                        Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                gradient: AppColors.gradPurple,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Center(
                                child: Text('🎵',
                                    style: TextStyle(fontSize: 20)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(plTitle,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text)),
                              Text('$trackCount songs',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                            ])),
                        if (isLoading)
                          const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.purpleLight))
                        else if (isAdded)
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  gradient: AppColors.gradPurple,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 12))
                        else
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.border2, width: 1.5))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.gradPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.purpleDark.withOpacity(0.4),
                        blurRadius: 20)
                  ],
                ),
                child: Text('Done',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareTrackSheet extends StatefulWidget {
  final Map<String, dynamic>? track;
  final Map<String, dynamic>? playlist;
  final Map<String, dynamic>? profile;
  const _ShareTrackSheet({this.track, this.playlist, this.profile});
  @override
  State<_ShareTrackSheet> createState() => _ShareTrackSheetState();
}

class _ShareTrackSheetState extends State<_ShareTrackSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _searchUsers = [];
  bool _loading = true;
  bool _searchingUsers = false;
  Timer? _searchDebounce;
  final Set<String> _sendingKeys = {};
  final Set<String> _sentKeys = {};

  bool get _isPlaylist => widget.playlist != null;
  bool get _isProfile => widget.profile != null;
  Map<String, dynamic>? get _playlist => widget.playlist;
  Map<String, dynamic>? get _profile => widget.profile;
  String get _trackId => (widget.track?['spotify_id'] ??
          widget.track?['deezer_id'] ??
          widget.track?['track_id'] ??
          '')
      .toString();
  String get _trackTitle =>
      (widget.track?['title'] ?? widget.track?['trackName'] ?? 'Unknown')
          .toString();
  String get _trackArtist =>
      (widget.track?['artist'] ?? widget.track?['artistName'] ?? '').toString();
  String? get _trackCover =>
      (widget.track?['cover_url'] ?? widget.track?['artworkUrl100'])
          ?.toString();
  String? get _trackPreview =>
      (widget.track?['preview_url'] ?? widget.track?['previewUrl'])?.toString();
  int get _playlistId => (_playlist?['id'] as num?)?.toInt() ?? 0;
  int get _playlistTrackCount {
    final raw = _playlist?['track_count'] ?? _playlist?['tracks_count'];
    if (raw is num) return raw.toInt();
    if (raw != null) return int.tryParse(raw.toString()) ?? 0;
    return (_playlist?['tracks'] as List?)?.length ?? 0;
  }

  String get _profileName => (_profile?['display_name'] ??
          _profile?['first_name'] ??
          _profile?['username'] ??
          'MoodWave user')
      .toString();
  String get _profileUsername => (_profile?['username'] ?? '').toString();
  String get _profileLink {
    final raw =
        (_profile?['profile_url'] ?? _profile?['share_url'])?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final id = (_profile?['id'] ?? _profile?['user_id'])?.toString();
    final handle = _profileUsername.isNotEmpty ? _profileUsername : 'user-$id';
    return 'https://moodwave.app/profile/$handle';
  }

  String get _shareTitle => _isProfile
      ? _profileName
      : (_isPlaylist
          ? (_playlist?['title'] ?? 'Playlist').toString()
          : _trackTitle);
  String get _shareSubtitle {
    if (_isProfile) {
      return _profileUsername.isNotEmpty
          ? '@$_profileUsername'
          : 'MoodWave profile';
    }
    if (_isPlaylist) {
      final count = _playlistTrackCount;
      return count > 0 ? '$count songs' : 'Playlist';
    }
    return _trackArtist;
  }

  String? get _shareCover {
    if (_isProfile) {
      final avatar =
          (_profile?['avatar_url'] ?? _profile?['image_url'])?.toString();
      return avatar == null || avatar.isEmpty ? null : buildMediaUrl(avatar);
    }
    if (!_isPlaylist) return _trackCover;
    final direct = (_playlist?['cover_url'] ??
            _playlist?['image_url'] ??
            _playlist?['artwork_url'] ??
            _playlist?['thumbnail_url'])
        ?.toString();
    if (direct != null && direct.isNotEmpty) return buildMediaUrl(direct);
    final tracks = _playlist?['tracks'] as List?;
    if (tracks != null && tracks.isNotEmpty && tracks.first is Map) {
      final first = Map<String, dynamic>.from(tracks.first as Map);
      final trackCover =
          (first['cover_url'] ?? first['artworkUrl100'] ?? first['image_url'])
              ?.toString();
      if (trackCover != null && trackCover.isNotEmpty) return trackCover;
    }
    return null;
  }

  Widget _buildPreviewAvatar() {
    final emoji = _isProfile ? '👤' : (_isPlaylist ? '▦' : '🎵');
    final child = _shareCover != null
        ? Image.network(_shareCover!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 24, color: Colors.white))))
        : Center(
            child: Text(emoji,
                style: const TextStyle(fontSize: 24, color: Colors.white)));
    final bg = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: AppColors.gradMixed,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14)],
      ),
      child: child,
    );
    if (_isProfile) {
      return ClipOval(child: bg);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: bg,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _destKey(Map<String, dynamic> chat) {
    final kind =
        (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct').toString();
    if (kind == 'user' || kind == 'direct' || kind == 'match') {
      final personId =
          (chat['user_id'] ?? chat['id'] ?? (chat['partner'] as Map?)?['id'])
              ?.toString();
      if (personId != null && personId.isNotEmpty) return 'person:$personId';
    }
    if (kind == 'group') {
      final groupId = (chat['group_chat_id'] ?? chat['chat_id'])?.toString();
      if (groupId != null && groupId.isNotEmpty) return 'group:$groupId';
    }
    return [
      kind,
      chat['match_id'],
      chat['chat_id'],
      chat['group_chat_id'],
      chat['user_id'] ?? chat['id']
    ].join(':');
  }

  Future<void> _loadDestinations() async {
    // Capture user ID synchronously before first await to avoid context-across-async-gap
    final myId = (context.read<AuthProvider>().user?['id'] as num?)?.toInt();
    try {
      final byKey = <String, Map<String, dynamic>>{};
      final directUserIds = <int>{};

      int priority(Map<String, dynamic> item) {
        final kind = (item['destination_type'] ?? item['chat_kind'] ?? 'direct')
            .toString();
        if (kind == 'direct' || kind == 'match') return 0;
        if (kind == 'group') return 1;
        if (kind == 'user') return 2;
        return 3;
      }

      void add(Map<String, dynamic> item) {
        final key = _destKey(item);
        if (key.trim().replaceAll(':', '').isEmpty) return;
        final existing = byKey[key];
        if (existing == null || priority(item) < priority(existing))
          byKey[key] = item;
      }

      final chats = await ApiService().getChats();
      for (final raw in chats.whereType<Map>()) {
        final chat = Map<String, dynamic>.from(raw);
        final kind = (chat['chat_kind'] ?? 'direct').toString();
        if (kind == 'group') {
          final groupId = (chat['group_chat_id'] as num?)?.toInt();
          final memberCount = (chat['member_count'] as num?)?.toInt() ?? 0;
          if (groupId == null || memberCount <= 0) continue;
          chat['destination_type'] = 'group';
          add(chat);
        } else {
          final chatId = (chat['chat_id'] as num?)?.toInt();
          final matchId = (chat['match_id'] as num?)?.toInt();
          if (chatId == null && matchId == null) continue;
          final partner =
              (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
          final partnerId = (partner['id'] as num?)?.toInt();
          if (partnerId != null) directUserIds.add(partnerId);
          chat['destination_type'] = kind == 'match' ? 'match' : 'direct';
          add(chat);
        }
      }

      try {
        if (myId != null) {
          final following =
              await ApiService().getUserFollowing(myId, limit: 100);
          for (final user in following) {
            final userId = (user['id'] as num?)?.toInt();
            if (userId == null || userId == myId) continue;
            if (directUserIds.contains(userId)) continue;
            add({...user, 'destination_type': 'user', 'user_id': userId});
          }
        }
      } catch (_) {}

      try {
        final friends = await ApiService().getFriends();
        for (final raw in friends.whereType<Map>()) {
          final user = Map<String, dynamic>.from(raw);
          final userId = (user['id'] as num?)?.toInt();
          if (userId == null) continue;
          if (directUserIds.contains(userId)) continue;
          add({...user, 'destination_type': 'user', 'user_id': userId});
        }
      } catch (_) {}

      final sorted = byKey.values.toList()
        ..sort((a, b) {
          final ap = priority(a);
          final bp = priority(b);
          if (ap != bp) return ap.compareTo(bp);
          final ar = _destRecentMs(a);
          final br = _destRecentMs(b);
          if (ar != br) return br.compareTo(ar);
          return _destName(a)
              .toLowerCase()
              .compareTo(_destName(b).toLowerCase());
        });

      if (!mounted) return;
      setState(() {
        _destinations = sorted;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _destName(Map<String, dynamic> chat) {
    final kind =
        (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct').toString();
    if (kind == 'group') {
      final partner =
          (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
      final title = (chat['title'] ??
              chat['name'] ??
              chat['display_name'] ??
              partner['display_name'] ??
              partner['name'] ??
              '')
          .toString()
          .trim();
      return title.isNotEmpty ? title : 'Group chat';
    }
    if (kind == 'user') {
      return (chat['display_name'] ??
              chat['first_name'] ??
              chat['username'] ??
              'User')
          .toString();
    }
    final partner =
        (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
    return (partner['display_name'] ??
            partner['first_name'] ??
            partner['username'] ??
            'Chat')
        .toString();
  }

  String _destSubtitle(Map<String, dynamic> chat) {
    final kind =
        (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct').toString();
    if (kind == 'group') {
      final memberCount = (chat['member_count'] as num?)?.toInt() ?? 0;
      return memberCount > 0 ? '$memberCount members' : 'Group chat';
    }
    if (kind == 'user') {
      final username = (chat['username'] ?? '').toString().trim();
      return username.isNotEmpty ? '@$username' : 'Following';
    }
    final partner =
        (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
    final username = (partner['username'] ?? '').toString().trim();
    return username.isNotEmpty ? '@$username' : 'Direct chat';
  }

  String _destAvatar(Map<String, dynamic> chat) {
    final kind =
        (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct').toString();
    if (kind == 'user')
      return buildMediaUrl((chat['avatar_url'] ?? '').toString());
    final partner =
        (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
    return buildMediaUrl(
        (partner['avatar_url'] ?? chat['avatar_url'] ?? '').toString());
  }

  int _destRecentMs(Map<String, dynamic> chat) {
    final raw = chat['last_message_at'] ??
        chat['updated_at'] ??
        chat['last_message_time'] ??
        chat['created_at'];
    if (raw is num) return raw.toInt();
    return DateTime.tryParse(raw?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  bool _matchesQuery(Map<String, dynamic> chat, String query) {
    if (query.isEmpty) return true;
    final haystack = [
      _destName(chat),
      _destSubtitle(chat),
      chat['username'],
      chat['display_name'],
      chat['first_name'],
      (chat['partner'] as Map?)?['username'],
      (chat['partner'] as Map?)?['display_name'],
      (chat['partner'] as Map?)?['first_name'],
    ].whereType<Object>().join(' ').toLowerCase();
    return haystack.contains(query.toLowerCase());
  }

  List<Map<String, dynamic>> get _visibleDestinations {
    final query = _searchCtrl.text.trim();
    final byKey = <String, Map<String, dynamic>>{};
    for (final dest in _destinations) {
      if (_matchesQuery(dest, query)) byKey[_destKey(dest)] = dest;
    }
    for (final user in _searchUsers) {
      byKey.putIfAbsent(_destKey(user), () => user);
    }
    return byKey.values.toList();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _searchUsers = [];
        _searchingUsers = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _searchUsersRemote(q);
    });
  }

  Future<void> _searchUsersRemote(String query) async {
    setState(() => _searchingUsers = true);
    try {
      final myId = (context.read<AuthProvider>().user?['id'] as num?)?.toInt();
      final users = await ApiService().searchUsers(query, limit: 20);
      if (!mounted || query != _searchCtrl.text.trim()) return;
      setState(() {
        _searchUsers = users
            .where((user) => (user['id'] as num?)?.toInt() != myId)
            .map((user) => {
                  ...user,
                  'destination_type': 'user',
                  'user_id': (user['id'] as num?)?.toInt(),
                })
            .where((user) => user['user_id'] != null)
            .toList();
        _searchingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  Future<void> _sendTo(Map<String, dynamic> chat) async {
    final key = _destKey(chat);
    if (_sendingKeys.contains(key) || _sentKeys.contains(key)) return;
    setState(() => _sendingKeys.add(key));
    try {
      final kind = (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct')
          .toString();
      final matchId = (chat['match_id'] as num?)?.toInt();
      final chatId = (chat['chat_id'] as num?)?.toInt();
      final groupChatId = (chat['group_chat_id'] as num?)?.toInt();

      if (_isPlaylist) {
        if (_playlistId <= 0) throw StateError('Missing playlist id');
        if (kind == 'match' && matchId != null) {
          await ApiService().sendPlaylistInChat(
            matchId,
            playlistId: _playlistId,
            title: _shareTitle,
            coverUrl: _shareCover,
            trackCount: _playlistTrackCount,
          );
        } else if (kind == 'group' && groupChatId != null) {
          await ApiService().sendPlaylistInGroupChat(
            groupChatId,
            playlistId: _playlistId,
            title: _shareTitle,
            coverUrl: _shareCover,
            trackCount: _playlistTrackCount,
          );
        } else if (kind == 'direct' && chatId != null) {
          await ApiService().sendPlaylistInDirectChat(
            chatId,
            playlistId: _playlistId,
            title: _shareTitle,
            coverUrl: _shareCover,
            trackCount: _playlistTrackCount,
          );
        } else if (kind == 'user') {
          final userId = ((chat['user_id'] ?? chat['id']) as num?)?.toInt();
          if (userId == null) throw StateError('Missing user id');
          final started = await ApiService().startDirectChat(userId);
          final newChatId = (started['chat_id'] as num?)?.toInt();
          if (newChatId == null) throw StateError('No chat_id');
          await ApiService().sendPlaylistInDirectChat(
            newChatId,
            playlistId: _playlistId,
            title: _shareTitle,
            coverUrl: _shareCover,
            trackCount: _playlistTrackCount,
          );
        }
      } else if (_isProfile) {
        final profileUserId = (_profile?['id'] ?? _profile?['user_id'] as num?)?.toInt() ?? 0;
        final avatarUrl = _shareCover;
        if (kind == 'match' && matchId != null) {
          await ApiService().sendProfileInChat(matchId,
              userId: profileUserId,
              displayName: _profileName,
              username: _profileUsername,
              avatarUrl: avatarUrl,
              profileUrl: _profileLink);
        } else if (kind == 'group' && groupChatId != null) {
          await ApiService().sendProfileInGroupChat(groupChatId,
              userId: profileUserId,
              displayName: _profileName,
              username: _profileUsername,
              avatarUrl: avatarUrl,
              profileUrl: _profileLink);
        } else if (kind == 'direct' && chatId != null) {
          await ApiService().sendProfileInDirectChat(chatId,
              userId: profileUserId,
              displayName: _profileName,
              username: _profileUsername,
              avatarUrl: avatarUrl,
              profileUrl: _profileLink);
        } else if (kind == 'user') {
          final userId = ((chat['user_id'] ?? chat['id']) as num?)?.toInt();
          if (userId == null) throw StateError('Missing user id');
          final started = await ApiService().startDirectChat(userId);
          final newChatId = (started['chat_id'] as num?)?.toInt();
          if (newChatId == null) throw StateError('No chat_id');
          await ApiService().sendProfileInDirectChat(newChatId,
              userId: profileUserId,
              displayName: _profileName,
              username: _profileUsername,
              avatarUrl: avatarUrl,
              profileUrl: _profileLink);
        }
      } else if (kind == 'match' && matchId != null) {
        await ApiService().sendTrackInChat(matchId,
            trackId: _trackId,
            title: _trackTitle,
            artist: _trackArtist,
            coverUrl: _trackCover,
            previewUrl: _trackPreview);
      } else if (kind == 'group' && groupChatId != null) {
        await ApiService().sendTrackInGroupChat(groupChatId,
            trackId: _trackId,
            title: _trackTitle,
            artist: _trackArtist,
            coverUrl: _trackCover,
            previewUrl: _trackPreview);
      } else if (kind == 'direct' && chatId != null) {
        await ApiService().sendTrackInDirectChat(chatId,
            trackId: _trackId,
            title: _trackTitle,
            artist: _trackArtist,
            coverUrl: _trackCover,
            previewUrl: _trackPreview);
      } else if (kind == 'user') {
        final userId = ((chat['user_id'] ?? chat['id']) as num?)?.toInt();
        if (userId == null) throw StateError('Missing user id');
        final started = await ApiService().startDirectChat(userId);
        final newChatId = (started['chat_id'] as num?)?.toInt();
        if (newChatId == null) throw StateError('No chat_id');
        await ApiService().sendTrackInDirectChat(newChatId,
            trackId: _trackId,
            title: _trackTitle,
            artist: _trackArtist,
            coverUrl: _trackCover,
            previewUrl: _trackPreview);
      }

      if (!mounted) return;
      setState(() {
        _sendingKeys.remove(key);
        _sentKeys.add(key);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingKeys.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not send. Try again.',
            style: GoogleFonts.outfit(fontSize: 13)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      padding: EdgeInsets.fromLTRB(
          18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(100)))),
          Text(
              _isProfile
                  ? 'Share Profile'
                  : (_isPlaylist ? 'Share Playlist' : 'Share Track'),
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: GoogleFonts.outfit(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Search username or name...',
              hintStyle: GoogleFonts.outfit(color: AppColors.text3),
              filled: true,
              fillColor: AppColors.bg,
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.text3),
              suffixIcon: _searchingUsers
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.purpleLight,
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
          const SizedBox(height: 14),
          // Track preview
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFF1a0533),
                Color(0xFF7c3aed),
                Color(0xFF0d1a3d)
              ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border2),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _buildPreviewAvatar(),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_shareTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    if (_shareSubtitle.isNotEmpty)
                      Text(_shareSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: const Color(0xB3C8B4FF))),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.graphic_eq_rounded,
                          size: 10, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text('MoodWave',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white54)),
                    ]),
                  ])),
            ]),
          ),
          const SizedBox(height: 14),
          // System share
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    gradient: AppColors.gradPurple,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.ios_share_rounded,
                    color: Colors.white, size: 18)),
            title: Text('System share',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            subtitle: Text('Open device share menu',
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            onTap: () async {
              Navigator.pop(context);
              final text = _isPlaylist
                  ? 'Check out "$_shareTitle" on MoodWave'
                  : (_isProfile
                      ? 'Check out $_profileName on MoodWave\n$_profileLink'
                      : (_trackArtist.isNotEmpty
                          ? 'Listen to $_trackTitle by $_trackArtist on MoodWave'
                          : 'Listen to $_trackTitle on MoodWave'));
              await Share.share(
                text,
                subject: _isProfile
                    ? 'MoodWave profile'
                    : (_isPlaylist ? 'MoodWave playlist' : 'MoodWave track'),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('People & groups',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight)))
          else if (_visibleDestinations.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('No contacts yet',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.text3)))
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _visibleDestinations.map((dest) {
                  final key = _destKey(dest);
                  final name = _destName(dest);
                  final subtitle = _destSubtitle(dest);
                  final avatarUrl = _destAvatar(dest);
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                  final sending = _sendingKeys.contains(key);
                  final sent = _sentKeys.contains(key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Container(
                          width: 38,
                          height: 38,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              gradient: avatarUrl.isEmpty
                                  ? const LinearGradient(colors: [
                                      Color(0xFF7c3aed),
                                      Color(0xFFec4899)
                                    ])
                                  : null,
                              color:
                                  avatarUrl.isNotEmpty ? AppColors.glass : null,
                              shape: BoxShape.circle),
                          child: avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                      child: Text(initial,
                                          style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white))))
                              : Center(
                                  child: Text(initial,
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            Text(subtitle,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                          ])),
                      TextButton(
                        onPressed: sent || sending ? null : () => _sendTo(dest),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (sending)
                            const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.purpleLight))
                          else if (sent)
                            const Icon(Icons.check_rounded,
                                size: 15, color: AppColors.green),
                          if (sending || sent) const SizedBox(width: 5),
                          Text(sent ? 'Sent' : 'Send',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: sent
                                      ? AppColors.green
                                      : AppColors.purpleLight)),
                        ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Full Track Context Menu ─────────────────────────────────────────────────

void showTrackMenu(
  BuildContext context, {
  required Map<String, dynamic> track,
  int? playlistId,
  VoidCallback? onRemoveFromPlaylist,
  List<Map<String, dynamic>>? queue,
  int? currentQueueIndex,
}) {
  final title = track['title'] ?? track['trackName'] ?? 'Unknown';
  final artist = track['artist'] ?? track['artistName'] ?? '';
  final coverUrl = track['cover_url'] ?? track['artworkUrl100'];

  void snack(String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontSize: 13)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget menuItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, size: 22, color: color ?? AppColors.text3),
      title: Text(label,
          style:
              GoogleFonts.outfit(fontSize: 15, color: color ?? AppColors.text)),
      onTap: onTap,
      dense: true,
    );
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          // Track preview
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(10)),
                child: coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(coverUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text('🎵',
                                    style: TextStyle(fontSize: 22)))))
                    : const Center(
                        child: Text('🎵', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    Text(artist.toString(),
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.text3)),
                  ])),
            ]),
          ),
          const Divider(color: AppColors.border, height: 1),
          menuItem(Icons.share_outlined, 'Share', () {
            Navigator.pop(ctx);
            showShareTrack(context, track: track);
          }),
          menuItem(Icons.playlist_add_rounded, 'Add to playlist', () {
            Navigator.pop(ctx);
            showAddToPlaylist(context, track: track);
          }),
          menuItem(Icons.block_rounded, 'Exclude from recommendations', () {
            Navigator.pop(ctx);
            snack('Track excluded from recommendations');
            final trackId = track['spotify_id'] ??
                track['deezer_id'] ??
                track['track_id'] ??
                '';
            if (trackId.toString().isNotEmpty) {
              ApiService().skipTrack(trackId.toString()).catchError((_) {});
            }
          }),
          if (playlistId != null && onRemoveFromPlaylist != null)
            menuItem(
                Icons.remove_circle_outline_rounded, 'Remove from playlist',
                () {
              Navigator.pop(ctx);
              onRemoveFromPlaylist();
            }, color: Colors.redAccent),
          menuItem(Icons.queue_music_rounded, 'Go to queue', () {
            Navigator.pop(ctx);
            snack('Open the player to see the queue');
          }),
          menuItem(Icons.person_outline_rounded, 'Go to artist', () async {
            Navigator.pop(ctx);
            final directId = track['artist_id']?.toString();
            if (directId != null && directId.isNotEmpty) {
              if (context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistScreen(
                          artistId: directId, artistName: artist.toString()),
                    ));
              }
              return;
            }
            if (artist.toString().isEmpty) return;
            try {
              final result = await ApiService().searchArtist(artist.toString());
              final a = result['artist'] as Map<String, dynamic>?;
              if (a == null || !context.mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistScreen(
                        artistId: a['id'].toString(),
                        artistName: a['name']?.toString() ?? artist.toString()),
                  ));
            } catch (_) {
              if (context.mounted) snack('Artist not found');
            }
          }),
          menuItem(Icons.album_rounded, 'Go to album', () {
            Navigator.pop(ctx);
            final albumId = track['album_id'];
            if (albumId != null) {
              final id =
                  albumId is int ? albumId : int.tryParse(albumId.toString());
              if (id != null && context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumScreen(albumId: id),
                    ));
                return;
              }
            }
            snack('Album not found');
          }),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
