import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/lyrics_matcher.dart';
import '../utils/media_url.dart';
import '../widgets/common_widgets.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'lyrics_screen.dart';
import 'player_screen.dart';
import 'user_profile_screen.dart';

Future<Map<String, dynamic>?> showListeningRoomCreateSheet(
  BuildContext context, {
  String initialName = 'Live Room',
  bool initialPublic = true,
}) {
  final titleCtrl = TextEditingController(text: initialName);
  final descCtrl = TextEditingController();
  Uint8List? bgBytes;
  String bgMime = 'image/jpeg';
  bool isPublic = initialPublic;
  bool requireApproval = !initialPublic;
  bool allowSuggestions = true;
  bool allowChat = true;
  bool quietMode = false;
  bool democraticQueue = false;
  bool creating = false;

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleDark.withOpacity(0.24),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradPurple,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.headphones_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Live Room',
                                style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.text)),
                            Text('Name it, decorate it, then invite people.',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _roomSheetField(titleCtrl, 'Room title', Icons.title_rounded),
                  const SizedBox(height: 10),
                  _roomSheetField(descCtrl, 'Description', Icons.notes_rounded,
                      maxLines: 2),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1400,
                        maxHeight: 900,
                        imageQuality: 82,
                      );
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      final ext = picked.name.toLowerCase();
                      setSS(() {
                        bgBytes = bytes;
                        bgMime = ext.endsWith('.png')
                            ? 'image/png'
                            : ext.endsWith('.webp')
                                ? 'image/webp'
                                : 'image/jpeg';
                      });
                    },
                    child: Container(
                      height: bgBytes == null ? 58 : 118,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(children: [
                        if (bgBytes != null)
                          Positioned.fill(
                            child: Image.memory(bgBytes!, fit: BoxFit.cover),
                          ),
                        if (bgBytes != null)
                          Positioned.fill(
                            child: Container(
                                color: Colors.black.withOpacity(0.28)),
                          ),
                        Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.image_rounded,
                                color: AppColors.purpleLight, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              bgBytes == null
                                  ? 'Upload background image'
                                  : 'Change background image',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _roomSwitch(
                    title: isPublic ? 'Public room' : 'Private room',
                    subtitle: isPublic
                        ? 'Visible in Party. People can discover it.'
                        : 'Only people with invite can request/join.',
                    icon: isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    value: isPublic,
                    onChanged: (v) => setSS(() {
                      isPublic = v;
                    }),
                  ),
                  _roomSwitch(
                    title: 'Require approval',
                    subtitle: 'Host/co-host approves join requests.',
                    icon: Icons.verified_user_rounded,
                    value: requireApproval,
                    onChanged: (v) => setSS(() => requireApproval = v),
                  ),
                  _roomSwitch(
                    title: 'Track suggestions',
                    subtitle:
                        'Participants can suggest songs from search/likes.',
                    icon: Icons.queue_music_rounded,
                    value: allowSuggestions,
                    onChanged: (v) => setSS(() => allowSuggestions = v),
                  ),
                  _roomSwitch(
                    title: 'Room chat',
                    subtitle: 'Participants can talk during the session.',
                    icon: Icons.chat_bubble_rounded,
                    value: allowChat,
                    onChanged: (v) => setSS(() => allowChat = v),
                  ),
                  _roomSwitch(
                    title: 'Quiet mode',
                    subtitle: 'Only host/co-host can write in chat.',
                    icon: Icons.volume_off_rounded,
                    value: quietMode,
                    onChanged: (v) => setSS(() => quietMode = v),
                  ),
                  _roomSwitch(
                    title: 'Democratic queue',
                    subtitle: 'Let the room vote/suggest what plays next.',
                    icon: Icons.how_to_vote_rounded,
                    value: democraticQueue,
                    onChanged: (v) => setSS(() => democraticQueue = v),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: creating
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) return;
                            setSS(() => creating = true);
                            try {
                              final room =
                                  await ApiService().createListeningRoom(
                                name: title,
                                description: descCtrl.text,
                                backgroundDataUrl: bgBytes == null
                                    ? null
                                    : 'data:$bgMime;base64,${base64Encode(bgBytes!)}',
                                isPublic: isPublic,
                                maxGuests: 20,
                                requireApproval: requireApproval,
                                allowTrackSuggestions: allowSuggestions,
                                allowChat: allowChat,
                                quietMode: quietMode,
                                democraticQueue: democraticQueue,
                              );
                              if (ctx.mounted) Navigator.pop(ctx, room);
                            } catch (_) {
                              setSS(() => creating = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not create Live Room',
                                        style:
                                            GoogleFonts.outfit(fontSize: 13)),
                                    backgroundColor: const Color(0xFFef4444),
                                  ),
                                );
                              }
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Create room',
                                style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    titleCtrl.dispose();
    descCtrl.dispose();
  });
}

Widget _roomSheetField(
    TextEditingController controller, String hint, IconData icon,
    {int maxLines = 1}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.bg,
      prefixIcon: Icon(icon, color: AppColors.text3, size: 18),
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

Widget _roomSwitch({
  required String title,
  required String subtitle,
  required IconData icon,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.purpleLight),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ]),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.purpleLight,
      ),
    ]),
  );
}

// ══════════════════════════════════════════
// LISTENING PARTY
// ══════════════════════════════════════════
class ListeningPartyScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  const ListeningPartyScreen({super.key, required this.room});
  @override
  State<ListeningPartyScreen> createState() => _ListeningPartyScreenState();
}

class _ListeningPartyScreenState extends State<ListeningPartyScreen>
    with TickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  late TabController _tabCtrl;

  Map<String, dynamic> _room = {};
  bool _loading = false;
  bool _joining = false;
  bool _joinRequested = false;
  bool _busyControl = false;

  List<dynamic> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sendingMsg = false;
  int _lastMsgCount = 0;

  List<dynamic> _queue = [];
  List<dynamic> _participants = [];
  List<dynamic> _joinRequests = [];
  List<dynamic> _pinnedMessages = [];
  Map<String, dynamic>? _activePoll;
  final Set<int> _seenJoinRequestIds = {};
  bool _joinRequestSheetOpen = false;
  Timer? _refreshTimer;
  Timer? _positionTimer;
  WebSocketChannel? _roomChannel;
  StreamSubscription? _roomChannelSub;
  int _positionMs = 0;
  int _durationMs = 0;
  String _stateTrackKey = '';
  String _syncedTrackKey = '';
  String _roomSocketKey = '';
  bool _syncedPlaying = false;
  bool _advancingTrack = false;
  bool _playerWasEnded = false;
  DateTime? _lastRoomHardSyncAt;
  bool _autoJoinAttempted = false;
  bool _savingRoomSettings = false;

  // Lyrics state
  List<String> _lyricsLines = [];
  List<int> _lyricsSyncedTimesMs = [];
  bool _lyricsLoading = false;
  bool _lyricsApproxSync = false;
  String _lyricsTrackKey = '';
  final _lyricsScrollCtrl = ScrollController();
  int _lastScrolledLyricIdx = -1;

  PlayerProvider? _playerProvider;

  int? get _roomId => (_room['room_id'] as num?)?.toInt();
  bool get _isHost => _room['my_role'] == 'host';
  bool get _canControl => _room['can_control'] == true || _isHost;
  Map<String, dynamic> get _settings =>
      (_room['settings'] as Map?)?.cast<String, dynamic>() ?? {};
  bool get _hasJoined {
    final status = (_room['my_status'] ?? '').toString();
    return _isHost || status == 'connected' || status == 'approved';
  }

  bool get _isLocked => _room['is_public'] != true;
  bool get _hasExactLyricsSync =>
      _lyricsSyncedTimesMs.isNotEmpty &&
      _lyricsSyncedTimesMs.length == _lyricsLines.length;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _room = Map<String, dynamic>.from(widget.room);
    final hasPrefetch = widget.room['room_id'] != null;
    if (!hasPrefetch) _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_handlePlayerUpdate);
    });
    _loadRoom(silent: hasPrefetch);
    // 2s refresh keeps room chat and join approvals feeling close to realtime.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    _positionTimer = null; // position timer started by _loadRoom
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _lyricsScrollCtrl.dispose();
    _refreshTimer?.cancel();
    _positionTimer?.cancel();
    _roomChannelSub?.cancel();
    _roomChannel?.sink.close();
    _playerProvider?.removeListener(_handlePlayerUpdate);
    super.dispose();
  }

  String _normalizedTrackKey({
    String? id,
    String? title,
    String? artist,
  }) {
    final safeId = (id ?? '').trim();
    if (safeId.isNotEmpty) return safeId;
    final safeTitle = (title ?? '').trim().toLowerCase();
    final safeArtist = (artist ?? '').trim().toLowerCase();
    return '$safeTitle|$safeArtist';
  }

  String _currentRoomTrackKey() {
    final track = (_room['current_track'] as Map?)?.cast<String, dynamic>();
    return _normalizedTrackKey(
      id: (track?['track_spotify_id'] ?? track?['track_id'])?.toString(),
      title: track?['track_title']?.toString(),
      artist: track?['track_artist']?.toString(),
    );
  }

  String _playerTrackKey(Map<String, dynamic>? track) {
    if (track == null) return '';
    return _normalizedTrackKey(
      id: (track['spotify_id'] ??
              track['track_id'] ??
              track['track_spotify_id'] ??
              track['deezer_id'])
          ?.toString(),
      title: (track['title'] ?? track['track_title'])?.toString(),
      artist: (track['artist'] ?? track['track_artist'])?.toString(),
    );
  }

  void _handlePlayerUpdate() {
    if (!mounted || !_canControl || !_hasJoined || _advancingTrack) return;
    final player = _playerProvider ?? context.read<PlayerProvider>();
    final roomTrackKey = _currentRoomTrackKey();
    final providerTrackKey = _playerTrackKey(player.track);
    final sameTrack = roomTrackKey.isNotEmpty &&
        providerTrackKey.isNotEmpty &&
        roomTrackKey == providerTrackKey;
    if (player.trackEnded && sameTrack && !_playerWasEnded) {
      _playerWasEnded = true;
      unawaited(_playNextTrack());
      return;
    }
    if (sameTrack && player.isPlaying != _syncedPlaying) {
      _syncedPlaying = player.isPlaying;
      unawaited(_updatePlayback({
        'event': player.isPlaying ? 'play' : 'pause',
        'is_playing': player.isPlaying,
        'position_ms': player.position.inMilliseconds,
      }));
    }
    if (!player.trackEnded) {
      _playerWasEnded = false;
    }
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 1) _loadMessages();
    if (_tabCtrl.index == 2) _loadQueue();
  }

  void _syncPositionFromPlayer() {
    final player = _playerProvider;
    if (player == null || !mounted) return;
    final playerMs = player.position.inMilliseconds;
    if (playerMs > 0 && (playerMs - _positionMs).abs() > 500) {
      setState(() => _positionMs = playerMs);
    }
  }

  int _tickCount = 0;
  void _tick() {
    _tickCount++;
    // Heartbeat every ~28s (every 14th tick at 2s interval)
    if (_tickCount % 14 == 0) {
      unawaited(ApiService().sendPresenceHeartbeat());
      if (_hasJoined && _roomId != null) {
        unawaited(ApiService().heartbeatRoom(_roomId!));
      }
    }
    // Room data refresh every 2s
    if (!_savingRoomSettings && !_joining) {
      _loadRoom(silent: true);
    }
    // Messages every tick when on chat tab, queue every 8s
    final idx = _tabCtrl.index;
    if (idx == 1) _loadMessages(silent: true);
    if (idx == 2 && _tickCount % 2 == 0) _loadQueue();
    if (idx == 0 && _tickCount % 2 == 0)
      _loadQueue(); // keep queue fresh for vote card
  }

  Future<void> _loadRoom({bool silent = false}) async {
    if (!await ApiService().hasToken()) {
      if (mounted && !silent) setState(() => _loading = false);
      return;
    }
    final roomId = _roomId;
    if (roomId == null) {
      if (!silent) setState(() => _loading = false);
      return;
    }
    try {
      var details = await ApiService().getRoomDetails(roomId);
      if (!mounted) return;
      // Room became inactive (shouldn't happen via normal API but guard anyway)
      if (details['is_active'] == false) {
        _handleRoomEnded();
        return;
      }
      var effectiveDetails = details;
      var track = details['current_track'] as Map?;
      final incomingRequests = (details['join_requests'] as List?) ?? [];
      final newRequestIds = incomingRequests
          .whereType<Map>()
          .map((req) => (req['user_id'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0 && !_seenJoinRequestIds.contains(id))
          .toList();
      setState(() {
        _room = details;
        _participants = (details['participants'] as List?) ?? [];
        _joinRequests = incomingRequests;
        _activePoll = (details['active_poll'] as Map?)?.cast<String, dynamic>();
        _loading = false;
        // Clear pending flag if we're now connected or approved
        final newStatus = (details['my_status'] ?? '').toString();
        if (newStatus == 'connected' || newStatus == 'approved') {
          _joinRequested = false;
        }
      });
      final myStatus = (details['my_status'] ?? '').toString();
      final shouldAutoJoin = !_autoJoinAttempted &&
          myStatus != 'connected' &&
          (details['is_public'] == true || myStatus == 'approved');
      if (shouldAutoJoin) {
        _autoJoinAttempted = true;
        if (mounted) {
          setState(() => _joining = true);
        }
        try {
          await ApiService().joinRoom(roomId);
          if (!mounted) return;
          final joinedDetails = await ApiService().getRoomDetails(roomId);
          if (!mounted) return;
          effectiveDetails = joinedDetails;
          track = joinedDetails['current_track'] as Map?;
          setState(() {
            _room = joinedDetails;
            _participants = (joinedDetails['participants'] as List?) ?? [];
            _joinRequests = (joinedDetails['join_requests'] as List?) ?? [];
            _activePoll =
                (joinedDetails['active_poll'] as Map?)?.cast<String, dynamic>();
            _joining = false;
          });
          await _syncRoomSocket(joinedDetails);
        } catch (_) {
          if (mounted) {
            setState(() => _joining = false);
          }
          _autoJoinAttempted = false;
        }
      }
      await _syncRoomSocket(effectiveDetails);
      if (_canControl && newRequestIds.isNotEmpty) {
        _seenJoinRequestIds.addAll(newRequestIds);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showJoinRequestPopup();
        });
      }
      _syncPositionFromState(track);
      if (track != null) {
        final tTitle = (track['track_title'] ?? '').toString();
        final tArtist = (track['track_artist'] ?? '').toString();
        final tDuration =
            ((track['track_duration_ms'] ?? track['duration_ms']) as num?)
                    ?.toInt() ??
                0;
        if (tTitle.isNotEmpty) _fetchLyrics(tTitle, tArtist, tDuration);
      }
      unawaited(_syncRoomPlaybackToPlayer(track));
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        _handleRoomEnded();
        return;
      }
      if (!silent) setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  void _handleRoomEnded() {
    _refreshTimer?.cancel();
    _positionTimer?.cancel();
    _closeRoomSocket();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Room has ended', style: GoogleFonts.outfit(fontSize: 13)),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  void _syncPositionFromState(Map<dynamic, dynamic>? track) {
    final trackKey = _normalizedTrackKey(
      id: (track?['track_spotify_id'] ?? track?['track_id'])?.toString(),
      title: (track?['track_title'] ?? track?['title'])?.toString(),
      artist: (track?['track_artist'] ?? track?['artist'])?.toString(),
    );
    final newDuration = (track?['track_duration_ms'] as num?)?.toInt() ??
        (track?['duration_ms'] as num?)?.toInt() ??
        0;
    final serverPos = (track?['position_ms'] as num?)?.toInt() ?? 0;
    final updatedAt = (track?['updated_at'] as num?)?.toDouble();
    final isPlaying = track?['is_playing'] == true;
    final elapsed = updatedAt != null
        ? ((DateTime.now().millisecondsSinceEpoch / 1000 - updatedAt) * 1000)
            .round()
            .clamp(0,
                60000) // cap at 60s to avoid stale timestamps skewing position
        : 0;
    final computedPos =
        isPlaying && updatedAt != null ? serverPos + elapsed : serverPos;
    final clampedPos = newDuration > 0
        ? computedPos.clamp(0, newDuration).toInt()
        : computedPos.clamp(0, 1 << 31).toInt();

    final durationChanged = newDuration != _durationMs;
    final diff = (clampedPos - _positionMs).abs();
    final trackChanged = trackKey.isNotEmpty && trackKey != _stateTrackKey;
    final needsReset =
        trackChanged || durationChanged || diff > 2000 || _positionTimer == null;

    setState(() {
      _stateTrackKey = trackKey;
      _durationMs = newDuration;
      if (needsReset || !isPlaying) _positionMs = clampedPos;
    });

    if (!isPlaying) {
      _positionTimer?.cancel();
      _positionTimer = null;
    } else if (needsReset) {
      _positionTimer?.cancel();
      _positionTimer = null;
      _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted) return;
        if (_advancingTrack) return;
        setState(() {
          _positionMs += 500;
          if (_durationMs > 0 && _positionMs >= _durationMs) {
            _positionMs = _durationMs;
            _positionTimer?.cancel();
            _positionTimer = null;
          }
        });
        if (_durationMs > 0 &&
            _positionMs >= _durationMs &&
            _canControl &&
            _queue.isNotEmpty) {
          unawaited(_playNextTrack());
        }
        _autoScrollLyrics();
      });
    }
  }

  Future<void> _syncRoomPlaybackToPlayer(
      Map<dynamic, dynamic>? rawTrack) async {
    if (!_hasJoined || rawTrack == null || rawTrack.isEmpty || !mounted) return;
    final track = Map<String, dynamic>.from(rawTrack);
    final id = (track['track_spotify_id'] ??
            track['track_id'] ??
            track['spotify_id'] ??
            '')
        .toString();
    final title = (track['track_title'] ?? track['title'] ?? '').toString();
    final artist = (track['track_artist'] ?? track['artist'] ?? '').toString();
    if (id.isEmpty && title.isEmpty) return;
    final isPlaying = track['is_playing'] == true;
    final playerTrack = {
      'spotify_id': id,
      'track_id': id,
      'title': title,
      'artist': artist,
      'cover_url': track['track_cover_url'] ?? track['cover_url'],
      'preview_url': track['preview_url'] ?? track['previewUrl'],
      'duration_ms': track['track_duration_ms'] ?? track['duration_ms'],
    };
    final key = '$id|$title|$artist';
    final targetPositionMs = (track['position_ms'] as num?)?.toInt() ?? 0;
    final player = context.read<PlayerProvider>();
    try {
      final roomKey = _normalizedTrackKey(id: id, title: title, artist: artist);
      final playerKey = _playerTrackKey(player.track);
      if (_canControl && roomKey.isNotEmpty && roomKey == playerKey) {
        final target = Duration(milliseconds: targetPositionMs);
        final drift = (player.position - target).inMilliseconds.abs();
        if (drift > 900) {
          await player.seekTo(target);
          if (mounted) {
            setState(() => _positionMs = targetPositionMs);
          }
        }
        if (isPlaying != player.isPlaying) {
          if (isPlaying) {
            await player.resume();
          } else {
            await player.pause();
          }
        }
        _syncedTrackKey = key;
        _syncedPlaying = isPlaying;
        return;
      }
      if (_syncedTrackKey != key) {
        _syncedTrackKey = key;
        await player.openTrack(playerTrack, refreshQueue: false);
        await player.seekTo(Duration(milliseconds: targetPositionMs));
        _lastRoomHardSyncAt = null; // allow immediate seek after track change
        if (mounted) {
          setState(() => _positionMs = targetPositionMs);
        }
        _syncedPlaying = player.isPlaying;
        if (!isPlaying) {
          await player.pause();
          _syncedPlaying = false;
        } else {
          await player.resume();
          _syncedPlaying = true;
        }
      }
      if (_canControl) {
        _syncedPlaying = isPlaying;
        return;
      }
      final target = Duration(milliseconds: _positionMs);
      final drift = (player.position - target).inMilliseconds.abs();
      final canHardSync = _lastRoomHardSyncAt == null ||
          DateTime.now().difference(_lastRoomHardSyncAt!) >
              const Duration(seconds: 5);
      if (drift > 4200 && canHardSync) {
        await player.seekTo(target);
        _lastRoomHardSyncAt = DateTime.now();
      }
      if (isPlaying != _syncedPlaying) {
        _syncedPlaying = isPlaying;
        if (isPlaying) {
          await player.resume();
        } else {
          await player.pause();
        }
      }
    } catch (_) {}
  }

  bool _loadingMessages = false;

  Future<void> _loadMessages({bool silent = false}) async {
    if (_loadingMessages) return; // prevent race condition
    final roomId = _roomId;
    if (roomId == null || !_hasJoined || !await ApiService().hasToken()) return;
    _loadingMessages = true;
    try {
      final results = await Future.wait([
        ApiService().getRoomMessages(roomId, limit: 100),
        ApiService().getRoomPinnedMessages(roomId),
      ]);
      if (!mounted) return;
      final msgs = results[0];
      setState(() {
        // Don't replace with fewer messages during silent poll (Firebase lag)
        if (msgs.isNotEmpty || !silent) _messages = msgs;
        _pinnedMessages = results[1];
      });
      final currentMsgs = msgs.isNotEmpty ? msgs : _messages;
      if (currentMsgs.length > _lastMsgCount) {
        _lastMsgCount = currentMsgs.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _loadQueue() async {
    final roomId = _roomId;
    if (roomId == null || !_hasJoined || !await ApiService().hasToken()) return;
    try {
      final q = await ApiService().getRoomQueue(roomId);
      if (mounted) setState(() => _queue = q);
    } catch (_) {}
  }

  Future<void> _closeRoomSocket() async {
    _roomSocketKey = '';
    await _roomChannelSub?.cancel();
    _roomChannelSub = null;
    await _roomChannel?.sink.close();
    _roomChannel = null;
  }

  String? _roomSocketUrl(Map<String, dynamic> details) {
    final roomId = (details['room_id'] as num?)?.toInt();
    final wsToken = (details['ws_token'] ?? '').toString().trim();
    if (roomId == null || roomId <= 0 || wsToken.isEmpty) return null;
    final apiBase = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
      path: '/ws/rooms/$roomId',
      queryParameters: {'token': wsToken},
    ).toString();
  }

  Future<void> _syncRoomSocket([Map<String, dynamic>? details]) async {
    final snapshot = details ?? _room;
    final socketUrl = _roomSocketUrl(snapshot);
    final socketKey =
        '${snapshot['room_id'] ?? ''}|${snapshot['my_status'] ?? ''}';
    if (!_hasJoined || socketUrl == null) {
      await _closeRoomSocket();
      return;
    }
    if (_roomChannel != null && _roomSocketKey == socketKey) return;
    await _closeRoomSocket();
    try {
      final channel = WebSocketChannel.connect(Uri.parse(socketUrl));
      _roomChannel = channel;
      _roomSocketKey = socketKey;
      _roomChannelSub = channel.stream.listen(
        _handleRoomSocketEvent,
        onError: (_) {
          _roomSocketKey = '';
          _roomChannel = null;
          _roomChannelSub = null;
        },
        onDone: () {
          _roomSocketKey = '';
          _roomChannel = null;
          _roomChannelSub = null;
        },
      );
    } catch (_) {
      _roomSocketKey = '';
    }
  }

  void _handleRoomSocketEvent(dynamic raw) {
    Map<String, dynamic>? payload;
    if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (!mounted || payload == null) return;
    final event = (payload['event'] ?? '').toString();
    switch (event) {
      case 'sync':
        final state = (payload['state'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() => _room = {..._room, 'current_track': state});
        _syncPositionFromState(state);
        unawaited(_syncRoomPlaybackToPlayer(state));
        final wsTitle = (state['track_title'] ?? '').toString();
        final wsArtist = (state['track_artist'] ?? '').toString();
        final wsDuration =
            ((state['track_duration_ms'] ?? state['duration_ms']) as num?)
                    ?.toInt() ??
                0;
        if (wsTitle.isNotEmpty) {
          final wsKey = '$wsTitle|$wsArtist|$wsDuration';
          if (wsKey != _lyricsTrackKey) {
            _lyricsTrackKey = '';
            _fetchLyrics(wsTitle, wsArtist, wsDuration);
          }
        }
        break;
      case 'message_created':
        final message =
            (payload['message'] as Map?)?.cast<String, dynamic>() ?? {};
        if (message.isNotEmpty) {
          _mergeIncomingRoomMessage(message);
        }
        break;
      case 'message_deleted':
        final messageId = (payload['message_id'] ?? '').toString();
        final pins =
            (payload['pinned'] as List?)?.whereType<Map>().toList() ?? const [];
        if (messageId.isNotEmpty) {
          setState(() {
            _messages = _messages.where((rawMessage) {
              if (rawMessage is! Map) return true;
              return rawMessage['message_id']?.toString() != messageId;
            }).toList();
            _pinnedMessages =
                pins.map((item) => Map<String, dynamic>.from(item)).toList();
          });
        }
        break;
      case 'message_updated':
        final updated =
            (payload['message'] as Map?)?.cast<String, dynamic>() ?? {};
        final messageId = (updated['message_id'] ?? '').toString();
        if (messageId.isNotEmpty) {
          setState(() {
            _messages = _messages.map((rawMessage) {
              if (rawMessage is! Map ||
                  rawMessage['message_id']?.toString() != messageId) {
                return rawMessage;
              }
              return updated;
            }).toList();
          });
        }
        break;
      case 'pinned_updated':
        final pins = (payload['pinned'] as List?)?.whereType<Map>().toList();
        if (pins != null) {
          setState(() {
            _pinnedMessages =
                pins.map((item) => Map<String, dynamic>.from(item)).toList();
          });
        }
        break;
      case 'poll_updated':
        final poll = (payload['poll'] as Map?)?.cast<String, dynamic>();
        setState(() => _activePoll = poll);
        break;
      case 'guest_joined':
      case 'guest_left':
        unawaited(_loadRoom(silent: true));
        break;
      case 'room_deleted':
        _handleRoomEnded();
        break;
    }
  }

  void _mergeIncomingRoomMessage(Map<String, dynamic> incoming) {
    final incomingId = (incoming['message_id'] ?? '').toString();
    final incomingSender = (incoming['sender_id'] as num?)?.toInt() ?? -1;
    final incomingText = (incoming['text'] ?? '').toString();
    final incomingSentAt = (incoming['sent_at'] ?? '').toString();
    final next = _messages
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final existingIndex = incomingId.isEmpty
        ? -1
        : next.indexWhere(
            (item) => item['message_id']?.toString() == incomingId,
          );
    if (existingIndex >= 0) {
      next[existingIndex] = incoming;
    } else {
      final optimisticIndex = next.lastIndexWhere((item) {
        final itemId = (item['message_id'] ?? '').toString();
        if (itemId.isNotEmpty) return false;
        return (item['sender_id'] as num?)?.toInt() == incomingSender &&
            (item['text'] ?? '').toString() == incomingText;
      });
      if (optimisticIndex >= 0) {
        next[optimisticIndex] = incoming;
      } else {
        next.add(incoming);
      }
    }
    next.sort(
      (a, b) => (a['sent_at'] ?? '').toString().compareTo(
            (b['sent_at'] ?? '').toString(),
          ),
    );
    setState(() {
      _messages = next;
      _lastMsgCount = next.length;
    });
    if (_tabCtrl.index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    if (incomingSentAt.isNotEmpty) {
      unawaited(_loadMessages(silent: true));
    }
  }

  Future<void> _fetchLyrics(String title, String artist, int durationMs) async {
    final key = '$title|$artist|$durationMs';
    if (key == _lyricsTrackKey) return;
    _lyricsTrackKey = key;
    if (!mounted) return;
    setState(() {
      _lyricsLoading = true;
      _lyricsLines = [];
      _lyricsSyncedTimesMs = [];
    });
    try {
      final enc = Uri.encodeComponent;
      final durationSec = durationMs ~/ 1000;
      final lyricsContext = LyricsMatchContext(
        titleVariants: buildTitleVariants(title),
        artistVariants: buildArtistVariants(artist, primaryArtist: artist),
        albumName: '',
        durationSeconds: durationSec,
      );
      final urls = <String>[
        'https://lrclib.net/api/search?track_name=${enc(title)}&artist_name=${enc(artist)}'
            '${durationSec > 0 ? '&duration=$durationSec' : ''}',
        if (artist.isNotEmpty)
          'https://lrclib.net/api/search?q=${enc('$artist $title')}',
        'https://lrclib.net/api/search?q=${enc(title)}',
      ];
      final candidates = <Map>[];
      for (final url in urls) {
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (!mounted) return;
        if (resp.statusCode != 200) continue;
        final raw = jsonDecode(resp.body);
        if (raw is List) candidates.addAll(raw.whereType<Map>());
      }
      if (candidates.isEmpty) {
        setState(() => _lyricsLoading = false);
        return;
      }
      candidates.sort((a, b) => lyricsContext
          .score(Map<String, dynamic>.from(b))
          .compareTo(lyricsContext.score(Map<String, dynamic>.from(a))));
      Map<String, dynamic>? bestMatch;
      for (final rawCandidate in candidates) {
        final candidate = Map<String, dynamic>.from(rawCandidate);
        if (lyricsContext.acceptsCandidate(candidate)) {
          bestMatch = candidate;
          break;
        }
      }
      if (bestMatch == null) {
        if (mounted) {
          setState(() {
            _lyricsLines = [];
            _lyricsSyncedTimesMs = [];
            _lyricsApproxSync = false;
            _lyricsLoading = false;
          });
        }
        return;
      }
      final synced = (bestMatch['syncedLyrics'] as String?) ?? '';
      final plain = (bestMatch['plainLyrics'] as String?) ?? '';
      if (synced.isNotEmpty) {
        final lines = <String>[];
        final timesMs = <int>[];
        for (final line in synced.split('\n')) {
          final m =
              RegExp(r'^\[(\d+):(\d+)[.:](\d+)\](.*)').firstMatch(line.trim());
          if (m == null) continue;
          final min = int.parse(m.group(1)!);
          final sec = int.parse(m.group(2)!);
          final cs = int.parse(m.group(3)!.padRight(2, '0').substring(0, 2));
          timesMs.add((min * 60 + sec) * 1000 + cs * 10);
          lines.add(m.group(4)!.trim());
        }
        if (mounted)
          setState(() {
            _lyricsLines = lines;
            _lyricsSyncedTimesMs = timesMs;
            _lyricsApproxSync = false;
            _lyricsLoading = false;
          });
      } else if (plain.isNotEmpty) {
        final lines = plain
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (mounted)
          setState(() {
            _lyricsLines = lines;
            _lyricsSyncedTimesMs = [];
            _lyricsApproxSync = true;
            _lyricsLoading = false;
          });
      } else {
        if (mounted) setState(() => _lyricsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _lyricsLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sendingMsg) return;
    final roomId = _roomId;
    if (roomId == null) return;
    final me = context.read<AuthProvider>().user;
    final optimistic = {
      'sender_id': (me?['id'] as num?)?.toInt() ?? -1,
      'display_name': me?['first_name'] ?? me?['username'] ?? 'You',
      'text': text,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'type': 'text',
    };
    _msgCtrl.clear();
    setState(() {
      _sendingMsg = true;
      _messages = [..._messages, optimistic];
    });
    try {
      final result = await ApiService().sendRoomMessage(roomId, text);
      final message = result['message'];
      if (message is Map && mounted) {
        setState(() {
          _messages = [
            ..._messages.where((m) => !identical(m, optimistic)),
            Map<String, dynamic>.from(message),
          ];
        });
      } else {
        await _loadMessages();
      }
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          unawaited(_loadMessages(silent: true));
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _sendingMsg = false);
  }

  void _openRoomLyrics(String trackTitle, String trackArtist) {
    if (trackTitle.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsScreen(
          artist: trackArtist,
          title: trackTitle,
          duration: Duration(milliseconds: _durationMs),
          lyricsLines: _lyricsLines,
          currentPosition: Duration(milliseconds: _positionMs),
          syncedLineTimesMs: _lyricsSyncedTimesMs,
          approximateSync: _lyricsApproxSync,
          positionStream: _playerProvider?.positionStream,
          onSeek: _hasExactLyricsSync ? (pos) => _seekRoomLyricsTo(pos) : null,
        ),
      ),
    );
  }

  Future<void> _seekRoomLyricsTo(Duration pos) async {
    if (_canControl) {
      await _updatePlayback({
        'event': 'seek',
        'position_ms': pos.inMilliseconds,
        'is_playing': true,
      });
      return;
    }
    final player = _playerProvider ?? context.read<PlayerProvider>();
    await player.seekTo(pos);
    if (!player.isPlaying) {
      await player.resume();
    }
    if (mounted) setState(() => _positionMs = pos.inMilliseconds);
  }

  Map<String, dynamic>? _participantFor(int userId) {
    for (final raw in _participants.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      if ((item['user_id'] as num?)?.toInt() == userId) return item;
    }
    final host = (_room['host'] as Map?)?.cast<String, dynamic>();
    if (host != null && (host['id'] as num?)?.toInt() == userId) {
      return {
        ...host,
        'user_id': userId,
        'role': 'host',
        'display_name': host['first_name'] ?? host['username'] ?? 'Host',
      };
    }
    return null;
  }

  String _roleForMessage(Map<String, dynamic> msg) {
    final explicit = (msg['role'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;
    final senderId = (msg['sender_id'] as num?)?.toInt() ?? -1;
    return (_participantFor(senderId)?['role'] ?? 'listener').toString();
  }

  String _roleLabel(String role) {
    if (role == 'host') return 'Host';
    if (role == 'co_host') return 'Co-host';
    return 'Listener';
  }

  String _messagePreview(Map<String, dynamic> msg) {
    final text = (msg['text'] ?? '').toString().trim();
    if (text.isNotEmpty)
      return text.length > 120 ? '${text.substring(0, 120)}...' : text;
    return 'Pinned message';
  }

  Future<void> _pinRoomMessage(Map<String, dynamic> msg) async {
    final roomId = _roomId;
    final messageId = (msg['message_id'] ?? '').toString();
    if (roomId == null || messageId.isEmpty) {
      _snack('Message is still sending');
      return;
    }
    try {
      final pins = await ApiService().pinRoomMessage(
        roomId,
        messageId,
        _messagePreview(msg),
      );
      if (mounted) setState(() => _pinnedMessages = pins);
      unawaited(_loadMessages(silent: true));
      _snack('Message pinned');
    } catch (_) {
      _snack('Could not pin message');
    }
  }

  Future<void> _unpinRoomMessage(String messageId) async {
    final roomId = _roomId;
    if (roomId == null || messageId.isEmpty) return;
    try {
      final pins = await ApiService().unpinRoomMessage(roomId, messageId);
      if (mounted) setState(() => _pinnedMessages = pins);
      unawaited(_loadMessages(silent: true));
    } catch (_) {
      _snack('Could not unpin message');
    }
  }

  void _showRoomMessageActions(Map<String, dynamic> msg) {
    final messageId = (msg['message_id'] ?? '').toString();
    final myId =
        (context.read<AuthProvider>().user?['id'] as num?)?.toInt() ?? 0;
    final senderId = (msg['sender_id'] as num?)?.toInt() ?? -1;
    final canDelete = _canControl || senderId == myId;
    final isPinned = _pinnedMessages
        .whereType<Map>()
        .any((pin) => pin['message_id']?.toString() == messageId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_canControl)
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: AppColors.purpleLight,
                ),
                title: Text(isPinned ? 'Unpin message' : 'Pin message',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  if (isPinned) {
                    _unpinRoomMessage(messageId);
                  } else {
                    _pinRoomMessage(msg);
                  }
                },
              ),
            if (_canControl)
              ListTile(
                leading: const Icon(Icons.poll_rounded,
                    color: AppColors.purpleLight),
                title: Text('Create poll',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _showCreatePollSheet();
                  });
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.edit_rounded,
                    color: AppColors.purpleLight),
                title: Text('Edit message',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  _editRoomMessage(msg);
                },
              ),
            if (canDelete)
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: Color(0xFFf87171)),
                title: Text('Delete message',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFf87171))),
                onTap: () {
                  Navigator.pop(context);
                  _deleteRoomMessage(messageId);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteRoomMessage(String messageId) async {
    final roomId = _roomId;
    if (roomId == null || messageId.isEmpty) return;
    final previous = List<dynamic>.from(_messages);
    setState(() {
      _messages = _messages.where((raw) {
        if (raw is! Map) return true;
        return raw['message_id']?.toString() != messageId;
      }).toList();
    });
    try {
      final pins = await ApiService().deleteRoomMessage(roomId, messageId);
      if (mounted) setState(() => _pinnedMessages = pins);
      unawaited(_loadMessages(silent: true));
    } catch (_) {
      if (mounted) setState(() => _messages = previous);
      _snack('Could not delete message');
    }
  }

  Future<void> _editRoomMessage(Map<String, dynamic> msg) async {
    final roomId = _roomId;
    final messageId = (msg['message_id'] ?? '').toString();
    final initialText = (msg['text'] ?? '').toString().trim();
    if (roomId == null || messageId.isEmpty || initialText.isEmpty) return;
    final ctrl = TextEditingController(text: initialText);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Edit message',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            const SizedBox(height: 14),
            _roomTextField(ctrl, 'Message', Icons.edit_rounded, maxLines: 4),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.gradPurple,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text('Save changes',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    final nextText = (result ?? '').trim();
    if (nextText.isEmpty || nextText == initialText) return;
    final previous = List<dynamic>.from(_messages);
    setState(() {
      _messages = _messages.map((raw) {
        if (raw is! Map || raw['message_id']?.toString() != messageId) {
          return raw;
        }
        return {
          ...Map<String, dynamic>.from(raw),
          'text': nextText,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();
    });
    try {
      final updated =
          await ApiService().updateRoomMessage(roomId, messageId, nextText);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((raw) {
          if (raw is! Map || raw['message_id']?.toString() != messageId) {
            return raw;
          }
          return updated;
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _messages = previous);
      _snack('Could not edit message');
    }
  }

  void _jumpToPinned(String messageId) {
    final index = _messages.indexWhere((raw) {
      if (raw is! Map) return false;
      return raw['message_id']?.toString() == messageId;
    });
    if (index < 0 || !_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      (index * 82).toDouble().clamp(0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _openUserProfile(int userId, {Map<String, dynamic>? initialUser}) {
    if (userId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          initialUser: initialUser,
        ),
      ),
    );
  }

  Future<void> _sendJoinRequest() async {
    final roomId = _roomId;
    if (roomId == null) return;
    setState(() => _joining = true);
    try {
      final myStatus = (_room['my_status'] ?? '').toString();
      final isPublic = _room['is_public'] == true ||
          (_room['settings'] as Map?)?['is_public'] == true ||
          _settings['is_public'] == true;
      final shouldRequest =
          _isLocked && !isPublic && myStatus != 'approved' && myStatus != 'connected';
      if (shouldRequest) {
        final response = await ApiService().sendJoinRequest(roomId);
        final status = (response['status'] ?? '').toString();
        if (status == 'approved' || status == 'connected') {
          await ApiService().joinRoom(roomId);
        }
      } else {
        await ApiService().joinRoom(roomId);
      }
      if (!mounted) return;
      setState(() {
        _joining = false;
        _joinRequested = shouldRequest;
      });
      await _loadRoom();
      await _loadMessages();
      await _loadQueue();
      if (!mounted) return;
      _snack(shouldRequest ? 'Join request sent!' : 'Joined the room!');
    } catch (e) {
      if (!mounted) return;
      String errStr = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map)
          errStr += ' ${data['detail'] ?? ''}';
        else if (data is String) errStr += ' $data';
      }
      final alreadyRequested = errStr.contains('Already in room') ||
          errStr.contains('Already requested') ||
          errStr.contains('pending');
      final alreadyJoined = errStr.contains('connected') ||
          errStr.contains('approved') ||
          errStr.contains('already in room');
      final needsApproval = errStr.contains('approval_required') ||
          errStr.contains('room_locked');
      if (alreadyJoined) {
        setState(() {
          _joining = false;
          _joinRequested = false;
        });
        _autoJoinAttempted = false;
        await _loadRoom();
        await _loadMessages();
        await _loadQueue();
        return;
      }
      if (needsApproval) {
        setState(() {
          _joining = false;
          _joinRequested = true;
        });
        _autoJoinAttempted = false;
        _snack('Join request sent — waiting for host approval');
        await _loadRoom();
        return;
      }
      setState(() {
        _joining = false;
        if (alreadyRequested) _joinRequested = true;
      });
      _autoJoinAttempted = false;
      final msg = alreadyRequested
          ? 'You already have a pending or active request.'
          : 'Could not join room. Try again.';
      _snack(msg, error: !alreadyRequested);
      if (alreadyRequested) await _loadRoom();
    }
  }

  Future<void> _approveRequest(int userId, bool approve) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      if (approve) {
        await ApiService().approveRoomJoinRequest(roomId, userId);
      } else {
        await ApiService().declineRoomJoinRequest(roomId, userId);
      }
      setState(() {
        _joinRequests = _joinRequests
            .where((r) => (r['user_id'] as num?)?.toInt() != userId)
            .toList();
      });
      await _loadRoom(silent: true);
    } catch (e) {
      if (mounted)
        _snack(approve
            ? 'Could not approve request'
            : 'Could not decline request');
    }
  }

  Future<void> _approveAllRequests() async {
    final roomId = _roomId;
    if (roomId == null || _joinRequests.isEmpty) return;
    final ids = _joinRequests
        .whereType<Map>()
        .map((req) => (req['user_id'] as num?)?.toInt() ?? 0)
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return;
    try {
      await Future.wait(
          ids.map((id) => ApiService().approveRoomJoinRequest(roomId, id)));
      await _loadRoom(silent: true);
    } catch (_) {
      _snack('Could not approve all requests');
    }
  }

  void _showJoinRequestPopup() {
    if (_joinRequestSheetOpen || !_canControl || _joinRequests.isEmpty) return;
    _joinRequestSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleDark.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.gradPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_joinRequests.length} join request${_joinRequests.length == 1 ? '' : 's'}',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text('Later',
                    style: GoogleFonts.outfit(color: AppColors.text2)),
              ),
            ]),
            const SizedBox(height: 12),
            ..._joinRequests.whereType<Map>().take(3).map((raw) {
              final req = Map<String, dynamic>.from(raw);
              final userId = (req['user_id'] as num?)?.toInt() ?? 0;
              final name =
                  (req['first_name'] ?? req['username'] ?? 'Guest').toString();
              return _personRow(
                name: name,
                subtitle: 'Wants to join your private room',
                onTap: () => _openUserProfile(userId,
                    initialUser: {...req, 'id': userId, 'display_name': name}),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_approveRequest(userId, false));
                    },
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFf87171)),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_approveRequest(userId, true));
                    },
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.purpleLight),
                  ),
                ]),
              );
            }),
            if (_joinRequests.length > 1) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_approveAllRequests());
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradPurple,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text('Approve all',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    ).whenComplete(() => _joinRequestSheetOpen = false);
  }

  Future<void> _updatePlayback(Map<String, dynamic> payload) async {
    final roomId = _roomId;
    if (roomId == null || !_canControl || _busyControl) return;
    final nextTrack = Map<String, dynamic>.from(
      (_room['current_track'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final nextEvent = (payload['event'] ?? '').toString();
    if (payload.containsKey('position_ms')) {
      nextTrack['position_ms'] = payload['position_ms'];
      _positionMs = (payload['position_ms'] as num?)?.toInt() ?? _positionMs;
    }
    if (payload.containsKey('is_playing')) {
      nextTrack['is_playing'] = payload['is_playing'] == true;
    }
    if (nextEvent == 'pause') {
      nextTrack['is_playing'] = false;
      unawaited(context.read<PlayerProvider>().pause());
    } else if (nextEvent == 'play') {
      nextTrack['is_playing'] = true;
      unawaited(context.read<PlayerProvider>().resume());
    } else if (nextEvent == 'seek') {
      final seekMs = (payload['position_ms'] as num?)?.toInt();
      if (seekMs != null) {
        unawaited(
          context.read<PlayerProvider>().seekTo(Duration(milliseconds: seekMs)),
        );
      }
      if (payload['is_playing'] == true) {
        nextTrack['is_playing'] = true;
        unawaited(context.read<PlayerProvider>().resume());
      }
    } else if (nextEvent == 'restart') {
      nextTrack['is_playing'] = true;
      nextTrack['position_ms'] = 0;
      _positionMs = 0;
      unawaited(context.read<PlayerProvider>().restartCurrentTrack());
    }
    setState(() => _busyControl = true);
    setState(() => _room = {..._room, 'current_track': nextTrack});
    try {
      final data = await ApiService().updateRoomPlayback(roomId, payload);
      if (!mounted) return;
      final state = (data['state'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() => _room = {..._room, 'current_track': state});
      unawaited(_syncRoomPlaybackToPlayer(state));
    } catch (_) {
      if (mounted) _snack('Could not update playback');
    } finally {
      if (mounted) setState(() => _busyControl = false);
    }
  }

  Future<void> _playQueueItem(int index) async {
    final roomId = _roomId;
    if (roomId == null || !_canControl) return;
    try {
      _advancingTrack = false;
      _playerWasEnded = false;
      final data = await ApiService().playRoomQueueItem(roomId, index);
      if (!mounted) return;
      setState(() {
        _room = {
          ..._room,
          'current_track': (data['state'] as Map?)?.cast<String, dynamic>() ??
              _room['current_track'],
        };
        _queue = (data['queue'] as List?) ?? _queue;
      });
      final state = (data['state'] as Map?)?.cast<String, dynamic>() ?? {};
      unawaited(_syncRoomPlaybackToPlayer(state));
    } catch (_) {
      _snack('Could not start this track');
    }
  }

  Future<void> _playNextTrack() async {
    if (!_canControl || _queue.isEmpty || _advancingTrack) return;
    _advancingTrack = true;
    final currentIndex = _queue.indexWhere((raw) {
      if (raw is! Map) return false;
      return (raw['status'] ?? '').toString() == 'playing';
    });
    final nextIndex = currentIndex >= 0 && currentIndex + 1 < _queue.length
        ? currentIndex + 1
        : 0;
    try {
      await _playQueueItem(nextIndex);
    } finally {
      _advancingTrack = false;
    }
  }

  Future<void> _removeQueueItem(int index) async {
    final roomId = _roomId;
    if (roomId == null || !_canControl) return;
    try {
      await ApiService().removeFromRoomQueue(roomId, index);
      await _loadQueue();
    } catch (_) {
      _snack('Could not remove track');
    }
  }

  Future<void> _reorderQueue(int oldIndex, int newIndex) async {
    final roomId = _roomId;
    if (roomId == null || !_canControl) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex || oldIndex < 0 || newIndex < 0) return;
    final previous = List<dynamic>.from(_queue);
    setState(() {
      final item = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, item);
    });
    try {
      await ApiService().reorderRoomQueue(roomId, oldIndex, newIndex);
      await _loadQueue();
    } catch (_) {
      if (mounted) setState(() => _queue = previous);
      _snack('Could not reorder queue');
    }
  }

  Future<void> _endRoom() async {
    final roomId = _roomId;
    if (roomId == null || !_isHost) return;
    try {
      await ApiService().closeRoom(roomId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _snack('Could not close room');
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: error
                ? const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)])
                : AppColors.gradPurple,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (error ? Colors.red : AppColors.purpleDark)
                    .withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            Icon(error ? Icons.error_outline_rounded : Icons.check_rounded,
                size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmtMs(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '0:00';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final normalized =
          iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
      final dt = DateTime.parse(normalized).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.purpleLight)),
      );
    }

    final name = (_room['name'] ?? 'Live Room').toString();
    final host = (_room['host'] as Map?)?.cast<String, dynamic>() ?? {};
    final hostName =
        (host['first_name'] ?? host['username'] ?? 'Host').toString();
    final myUser = context.read<AuthProvider>().user;
    final myId = (myUser?['id'] as num?)?.toInt() ?? 0;
    final track = (_room['current_track'] as Map?)?.cast<String, dynamic>();
    final trackTitle = track?['track_title']?.toString() ?? '';
    final trackArtist = track?['track_artist']?.toString() ?? '';
    final trackCover = track?['track_cover_url']?.toString();
    final roomState = (_room['state'] ?? 'draft').toString();
    final roomBackground =
        (_room['background_url'] ?? _settings['background_url'] ?? '')
            .toString();
    final bgImageUrl = buildMediaUrl(
        roomBackground.isNotEmpty ? roomBackground : (trackCover ?? ''));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Full-screen blurred background
          if (bgImageUrl.isNotEmpty) ...[
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bgImageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(color: AppColors.bg.withOpacity(0.72)),
              ),
            ),
          ] else
            Positioned.fill(child: Container(color: AppColors.bg)),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(name, hostName, roomState),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNowPlaying(
                        track,
                        trackTitle,
                        trackArtist,
                        trackCover,
                        roomBackground,
                        host,
                        hostName,
                      ),
                      _buildChat(myId),
                      _buildQueue(),
                      _buildPeople(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String hostName, String roomState) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedBuilder(
                animation: _blinkCtrl,
                builder: (_, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFef4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: const Color(0xFFef4444).withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Opacity(
                      opacity: 0.3 + 0.7 * _blinkCtrl.value,
                      child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFFef4444),
                              shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                        roomState == 'paused'
                            ? 'PAUSED'
                            : roomState == 'draft'
                                ? 'WAITING'
                                : _room['is_public'] != true
                                    ? 'PRIVATE'
                                    : 'LIVE PARTY',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFf87171))),
                  ]),
                ),
              ),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              Builder(builder: (_) {
                final summaryCount = _participants.length >
                        ((_room['participant_count'] as num?)?.toInt() ?? 0)
                    ? _participants.length
                    : ((_room['participant_count'] as num?)?.toInt() ?? 0);
                return Text(
                    summaryCount <= 1
                        ? 'Hosted by $hostName · Only You'
                        : 'Hosted by $hostName · $summaryCount listening',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.text2));
              }),
            ]),
          ),
          GestureDetector(
            onTap: _shareRoomInvite,
            onLongPress: _showParticipantsSheet,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.share_rounded,
                  size: 18, color: AppColors.purpleLight),
            ),
          ),
          GestureDetector(
            onTap: () => _loadRoom(silent: true),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.text2),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCover(
    String? coverUrl,
    String trackTitle,
    bool isPlaying,
    String roomBackground,
  ) {
    final rawVisualUrl =
        (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : roomBackground;
    final visualUrl = buildMediaUrl(rawVisualUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        height: 184,
        decoration: BoxDecoration(
            gradient: AppColors.gradMixed,
            borderRadius: BorderRadius.circular(20)),
        child: Stack(children: [
          if (visualUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: visualUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            )
          else
            Container(
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20))),
          if (isPlaying)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                      8,
                      (i) => AnimatedMusicBars(
                          color1: AppColors.purpleLight,
                          color2: AppColors.pink,
                          barCount: 1,
                          barWidth: 4,
                          maxHeight: 26)),
                ),
              ),
            ),
          if (!isPlaying && trackTitle.isEmpty && visualUrl.isEmpty)
            const Center(child: Text('🎙', style: TextStyle(fontSize: 44))),
        ]),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle:
            GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.text3,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7c3aed), Color(0xFFec4899)]),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Now'),
          Tab(text: 'Chat'),
          Tab(text: 'Queue'),
          Tab(text: 'People'),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(
      Map<String, dynamic>? track,
      String trackTitle,
      String trackArtist,
      String? trackCover,
      String roomBackground,
      Map<String, dynamic> host,
      String hostName) {
    final participantCount = _room['participant_count'] ?? 0;
    final visibleParticipantCount = _participants.length > participantCount
        ? _participants.length
        : participantCount;
    final positionMs = _positionMs;
    final durationMs = _durationMs;
    final isPlaying = track?['is_playing'] == true;
    final roomVisual = buildMediaUrl(roomBackground);
    final trackVisual = buildMediaUrl(trackCover ?? '');
    final primaryVisual = roomVisual.isNotEmpty ? roomVisual : trackVisual;
    final currentLyric = _currentLyricLine();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            mainAxisAlignment: (trackTitle.isEmpty || !_hasJoined)
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (trackTitle.isEmpty || !_hasJoined)
                SizedBox(
                  height: (constraints.maxHeight * 0.18)
                      .clamp(72.0, 132.0)
                      .toDouble(),
                ),
              Container(
                height: 212,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.38),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: primaryVisual.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: primaryVisual,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed)),
                          )
                        : Container(
                            decoration:
                                BoxDecoration(gradient: AppColors.gradMixed)),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.18),
                            Colors.black.withOpacity(0.58),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (trackVisual.isNotEmpty)
                    Positioned(
                      left: 16,
                      bottom: 24,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: trackVisual,
                          width: 66,
                          height: 66,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _historyCoverFallback(56),
                        ),
                      ),
                    ),
                  Positioned(
                    left: trackVisual.isNotEmpty ? 94 : 18,
                    right: 18,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trackTitle.isNotEmpty
                              ? trackTitle
                              : 'Waiting for music',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trackArtist.isNotEmpty
                              ? trackArtist
                              : 'Add a track to start listening together',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trackTitle.isNotEmpty && isPlaying)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: const AnimatedMusicBars(
                        color1: AppColors.purpleLight,
                        color2: AppColors.pink,
                        barCount: 8,
                        barWidth: 4,
                        maxHeight: 24,
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              if (trackTitle.isNotEmpty &&
                  (_lyricsLoading || currentLyric.isNotEmpty)) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openRoomLyrics(trackTitle, trackArtist),
                  child: _buildNowLyricsCard(currentLyric),
                ),
                const SizedBox(height: 16),
              ],

              // Seek slider (draggable for host, read-only for listener)
              if (durationMs > 0) ...[
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: _canControl ? 7 : 0,
                        disabledThumbRadius: 0),
                    activeTrackColor: AppColors.purpleLight,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.purpleLight,
                    overlayColor: AppColors.purpleLight.withOpacity(0.15),
                  ),
                  child: Slider(
                    value:
                        positionMs.toDouble().clamp(0.0, durationMs.toDouble()),
                    min: 0,
                    max: durationMs.toDouble(),
                    onChanged: _canControl
                        ? (v) => setState(() => _positionMs = v.toInt())
                        : null,
                    onChangeEnd: _canControl
                        ? (v) => _updatePlayback({
                              'event': 'seek',
                              'position_ms': v.toInt(),
                              'is_playing': true,
                            })
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtMs(positionMs),
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.text3)),
                        Text(_fmtMs(durationMs),
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.text3)),
                      ]),
                ),
                const SizedBox(height: 8),
              ],

              // Playback controls
              if (!_hasJoined) ...[
                const SizedBox(height: 8),
                _primaryRoomButton(
                  label: _joinRequested
                      ? 'Request sent — waiting for host'
                      : _joining
                          ? (_isLocked
                              ? 'Sending request...'
                              : 'Joining room...')
                          : _isLocked
                              ? 'Request to Join'
                              : 'Join Room',
                  icon: _joinRequested
                      ? Icons.hourglass_empty_rounded
                      : Icons.headphones_rounded,
                  disabled: _joining || _joinRequested,
                  onTap: _sendJoinRequest,
                ),
              ] else if (_canControl) ...[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  GestureDetector(
                    onTap: () => _updatePlayback({
                      'event': 'restart',
                      'position_ms': 0,
                      'is_playing': true
                    }),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.glass2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.skip_previous_rounded,
                          size: 24, color: AppColors.text2),
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => _updatePlayback({
                      'event': isPlaying ? 'pause' : 'play',
                      'is_playing': !isPlaying,
                      'position_ms': positionMs,
                    }),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purpleDark.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: _playNextTrack,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.glass2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.skip_next_rounded,
                          size: 24, color: AppColors.text2),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _showTrackPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.glass2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.queue_music_rounded,
                            size: 18, color: AppColors.purpleLight),
                        const SizedBox(width: 8),
                        Text(
                          'Add track to queue',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // End room button
                GestureDetector(
                  onTap: _endRoom,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x18EF4444),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x55EF4444)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stop_circle_rounded,
                              size: 18, color: Color(0xFFf87171)),
                          const SizedBox(width: 8),
                          Text('End room',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFf87171))),
                        ]),
                  ),
                ),
              ] else ...[
                // Listener view: sync status
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_rounded,
                            size: 17, color: AppColors.purpleLight),
                        const SizedBox(width: 8),
                        Text(
                            isPlaying ? 'Synced with host' : 'Waiting for host',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                      ]),
                ),
              ],

              const SizedBox(height: 20),
              Text(
                visibleParticipantCount <= 1
                    ? 'Only You'
                    : '$visibleParticipantCount listeners with $hostName',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowLyricsCard(String currentLyric) {
    final activeIndex = _hasExactLyricsSync ? _activeLyricIndex() : -1;
    final previous = activeIndex > 0 ? _lyricsLines[activeIndex - 1] : '';
    final next = activeIndex >= 0 && activeIndex + 1 < _lyricsLines.length
        ? _lyricsLines[activeIndex + 1]
        : '';
    final hasLyrics = currentLyric.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.subtitles_rounded,
              size: 16, color: AppColors.purpleLight),
          const SizedBox(width: 8),
          Text('Live lyrics',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
        ]),
        const SizedBox(height: 12),
        if (_lyricsLoading)
          Row(children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight),
            ),
            const SizedBox(width: 10),
            Text('Finding lyrics...',
                style:
                    GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
          ])
        else if (!hasLyrics)
          Text('Lyrics unavailable for this track version',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2))
        else ...[
          if (previous.isNotEmpty)
            Text(previous,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 5),
          Text(currentLyric,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(next,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ],
        ],
      ]),
    );
  }

  Widget _primaryRoomButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: disabled ? null : AppColors.gradPurple,
          color: disabled ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(16),
          border: disabled ? Border.all(color: AppColors.border) : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_joining)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.purpleLight))
          else
            Icon(icon,
                size: 18, color: disabled ? AppColors.text2 : Colors.white),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: disabled ? AppColors.text2 : Colors.white)),
        ]),
      ),
    );
  }

  Widget _smallControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: danger ? const Color(0x22EF4444) : AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: danger ? const Color(0x66EF4444) : AppColors.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18,
              color: danger ? const Color(0xFFf87171) : AppColors.purpleLight),
          const SizedBox(width: 7),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: danger ? const Color(0xFFf87171) : AppColors.text)),
        ]),
      ),
    );
  }

  Widget _buildChat(int myId) {
    if (!_hasJoined) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              child: Column(children: [
                SizedBox(
                  height: (constraints.maxHeight * 0.14)
                      .clamp(42.0, 96.0)
                      .toDouble(),
                ),
                const Text('🔒', style: TextStyle(fontSize: 42)),
                const SizedBox(height: 12),
                Text('Join to chat',
                    style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 8),
                Text('Messages and live events appear after you enter the room.',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                const SizedBox(height: 18),
                _primaryRoomButton(
                  label: _joining
                      ? (_isLocked ? 'Sending request...' : 'Joining room...')
                      : _isLocked
                          ? 'Request to Join'
                          : 'Join Room',
                  icon: Icons.headphones_rounded,
                  disabled: _joining || _joinRequested,
                  onTap: _sendJoinRequest,
                ),
              ]),
            ),
          ),
        ),
      );
    }
    return Column(children: [
      if (_activePoll != null) _buildActivePollCard(),
      if (_pinnedMessages.isNotEmpty) _buildPinnedRoomBar(),
      _buildNextUpVoteCard(),
      Expanded(
        child: _messages.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('💬', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No messages',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 6),
                Text('Start the conversation with everyone',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.text2)),
              ]))
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = Map<String, dynamic>.from(_messages[i] as Map);
                  final senderId = (msg['sender_id'] as num?)?.toInt() ?? -1;
                  final isMe = senderId == myId;
                  final isSystem = (msg['type'] ?? '').toString() == 'system' ||
                      senderId == 0;
                  final senderName = (msg['display_name'] ?? 'User').toString();
                  final text = (msg['text'] ?? '').toString();
                  final isEdited =
                      (msg['edited_at'] ?? '').toString().trim().isNotEmpty;
                  final time = _fmtTime(msg['sent_at']?.toString());
                  final role = _roleForMessage(msg);
                  final isImportant = role == 'host' || role == 'co_host';
                  final participant = _participantFor(senderId);

                  if (isSystem) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.glass,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(text,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text2)),
                        ),
                      ),
                    );
                  }

                  final nameColor = _chatNameColor(senderId, senderName);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openUserProfile(
                      senderId,
                      initialUser: participant,
                    ),
                    onLongPress: () => _showRoomMessageActions(msg),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: isImportant
                            ? nameColor.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isImportant
                            ? Border.all(color: nameColor.withOpacity(0.18))
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(time,
                                style: GoogleFonts.outfit(
                                    fontSize: 10, color: AppColors.text3)),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: nameColor.withOpacity(0.16),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: nameColor.withOpacity(0.5)),
                            ),
                            child: Center(
                              child: Text(
                                  senderName.isNotEmpty
                                      ? senderName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: nameColor)),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    height: 1.28,
                                    color: AppColors.text),
                                children: [
                                  TextSpan(
                                    text:
                                        isMe ? '$senderName ' : '$senderName ',
                                    style: TextStyle(
                                      color: nameColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (isImportant)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5),
                                        child: _rolePill(_roleLabel(role)),
                                      ),
                                    ),
                                  TextSpan(
                                    text: isEdited ? '$text (edited)' : text,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          border: const Border(top: BorderSide(color: Color(0x15FFFFFF))),
        ),
        child: Row(children: [
          if (_canControl) ...[
            GestureDetector(
              onTap: _showCreatePollSheet,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.poll_rounded,
                    size: 18, color: AppColors.purpleLight),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF7c3aed), Color(0xFFec4899)]),
                  shape: BoxShape.circle),
              child: _sendingMsg
                  ? const Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _rolePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purpleLight.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.purpleLight.withOpacity(0.26)),
      ),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.purpleLight)),
    );
  }

  Color _chatNameColor(int userId, String name) {
    const palette = [
      Color(0xFFa78bfa),
      Color(0xFF22d3ee),
      Color(0xFFfb7185),
      Color(0xFFf59e0b),
      Color(0xFF34d399),
      Color(0xFF60a5fa),
      Color(0xFFf472b6),
      Color(0xFFc084fc),
    ];
    final seed = userId > 0
        ? userId
        : name.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return palette[seed.abs() % palette.length];
  }

  Widget _buildNextUpVoteCard() {
    if (_activePoll != null) return const SizedBox.shrink();
    // Show top-voted (or first pending) track from queue if any
    final suggestions = _queue
        .whereType<Map>()
        .where((t) =>
            (t['status'] ?? '').toString() == 'suggested' ||
            (t['status'] ?? '').toString() == 'pending' ||
            (t['status'] ?? '').toString().isEmpty)
        .toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    // Sort by votes descending
    suggestions.sort((a, b) {
      final bv = _queueVoteCount(Map<String, dynamic>.from(b));
      final av = _queueVoteCount(Map<String, dynamic>.from(a));
      return bv.compareTo(av);
    });
    final top = Map<String, dynamic>.from(suggestions.first);
    final title = (top['track_title'] ?? top['title'] ?? '').toString();
    final artist = (top['track_artist'] ?? top['artist'] ?? '').toString();
    final votes = _queueVoteCount(top);
    final cover = (top['track_cover_url'] ?? top['cover_url'] ?? '').toString();
    final idx = _queue.indexWhere((t) {
      if (t is! Map) return false;
      return (t['track_title'] ?? t['title'] ?? '').toString() == title;
    });
    if (title.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        if (cover.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: buildMediaUrl(cover),
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded,
                  size: 20, color: AppColors.text3),
            ),
          )
        else
          const Icon(Icons.music_note_rounded,
              size: 20, color: AppColors.text3),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NEXT UP VOTE',
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.purpleLight,
                    letterSpacing: 0.8)),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            if (artist.isNotEmpty)
              Text(artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text2)),
          ]),
        ),
        const SizedBox(width: 8),
        // Vote button
        GestureDetector(
          onTap: idx >= 0 ? () => _voteQueueItem(idx) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (top['my_vote'] == true)
                  ? AppColors.purpleDark.withOpacity(0.3)
                  : AppColors.glass2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (top['my_vote'] == true)
                      ? AppColors.purpleLight
                      : AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                Icons.thumb_up_rounded,
                size: 14,
                color: (top['my_vote'] == true)
                    ? AppColors.purpleLight
                    : AppColors.text2,
              ),
              if (votes > 0) ...[
                const SizedBox(width: 4),
                Text('$votes',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (top['my_vote'] == true)
                            ? AppColors.purpleLight
                            : AppColors.text2)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  int _queueVoteCount(Map<String, dynamic> item) {
    final rawCount = item['vote_count'];
    if (rawCount is num) return rawCount.toInt();
    final rawVotes = item['votes'];
    if (rawVotes is List) return rawVotes.length;
    if (rawVotes is num) return rawVotes.toInt();
    return 0;
  }

  Widget _buildPinnedRoomBar() {
    final pin = Map<String, dynamic>.from(_pinnedMessages.last as Map);
    final preview = (pin['preview'] ?? 'Pinned message').toString();
    final messageId = (pin['message_id'] ?? '').toString();
    return GestureDetector(
      onTap: () => _jumpToPinned(messageId),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.purpleDark.withOpacity(0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.32)),
        ),
        child: Row(children: [
          const Icon(Icons.push_pin_rounded,
              size: 17, color: AppColors.purpleLight),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pinned message',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purpleLight)),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text)),
            ]),
          ),
          if (_pinnedMessages.length > 1)
            Text('${_pinnedMessages.length}',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text2)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _unpinRoomMessage(messageId),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.text3),
          ),
        ]),
      ),
    );
  }

  Widget _buildActivePollCard() {
    final poll = _activePoll!;
    final question = (poll['question'] ?? '').toString();
    final options = ((poll['options'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final counts = ((poll['counts'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt() ?? 0)
        .toList();
    final total = (poll['total'] as num?)?.toInt() ?? 0;
    final myVote = (poll['my_vote'] as num?)?.toInt();
    if (question.isEmpty || options.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF25164A).withOpacity(0.96),
            const Color(0xFF171326).withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purpleLight.withOpacity(0.38)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleDark.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.purpleLight.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: AppColors.purpleLight.withOpacity(0.24)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.poll_rounded,
                  size: 13, color: AppColors.purpleLight),
              const SizedBox(width: 5),
              Text('Live poll',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purpleLight)),
            ]),
          ),
          const Spacer(),
          if (_canControl)
            GestureDetector(
              onTap: _closePoll,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 17, color: AppColors.text2),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(question,
            style: GoogleFonts.outfit(
                fontSize: 16,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        const SizedBox(height: 9),
        ...options.asMap().entries.map((entry) {
          final i = entry.key;
          final text = entry.value;
          final count = i < counts.length ? counts[i] : 0;
          final pct = total <= 0 ? 0.0 : count / total;
          final voted = myVote == i;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _votePoll(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(voted ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: voted
                          ? AppColors.pink.withOpacity(0.64)
                          : Colors.white.withOpacity(0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.purpleLight.withOpacity(0.34),
                          AppColors.pink.withOpacity(0.28),
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: voted ? AppColors.gradMixed : null,
                          border: Border.all(
                            color: voted
                                ? Colors.white.withOpacity(0.5)
                                : AppColors.text3.withOpacity(0.45),
                          ),
                        ),
                        child: voted
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      Expanded(
                        child: Text(text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text)),
                      ),
                      Text('${(pct * 100).round()}% ($count)',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: voted ? Colors.white : AppColors.text2)),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Future<void> _showCreatePollSheet() async {
    if (!_canControl) return;
    final questionCtrl = TextEditingController(text: 'What should play next?');
    final optionCtrls = <TextEditingController>[];
    final queueOptions = _queue
        .whereType<Map>()
        .map((item) => (item['title'] ?? item['track_title'] ?? '').toString())
        .where((title) => title.trim().isNotEmpty)
        .take(4)
        .toList();
    for (final title in queueOptions) {
      optionCtrls.add(TextEditingController(text: title));
    }
    while (optionCtrls.length < 2) {
      optionCtrls
          .add(TextEditingController(text: 'Option ${optionCtrls.length + 1}'));
    }
    var submitting = false;
    Future<void> submit(StateSetter setSheetState, BuildContext ctx) async {
      if (submitting) return;
      final question = questionCtrl.text.trim();
      final options = optionCtrls
          .map((ctrl) => ctrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (question.isEmpty || options.length < 2) {
        _snack('Poll needs a question and at least 2 options');
        return;
      }
      final roomId = _roomId;
      if (roomId == null) return;
      setSheetState(() => submitting = true);
      var closedSheet = false;
      try {
        final poll = await ApiService().createRoomPoll(roomId, question, options);
        if (!mounted) return;
        setState(() => _activePoll = poll);
        _tabCtrl.animateTo(1);
        closedSheet = true;
        Navigator.of(ctx).pop();
        unawaited(_loadMessages(silent: true));
      } catch (_) {
        if (mounted) _snack('Could not create poll');
      } finally {
        if (mounted && !closedSheet) setSheetState(() => submitting = false);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.38),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.poll_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Create poll',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text)),
                  ),
                ]),
                const SizedBox(height: 14),
                _roomTextField(questionCtrl, 'Question', Icons.poll_rounded),
                const SizedBox(height: 9),
                ...optionCtrls.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _roomTextField(
                        entry.value,
                        'Option ${entry.key + 1}',
                        Icons.music_note_rounded,
                      ),
                    )),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: submitting ? null : () => submit(setSheetState, ctx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: submitting ? null : AppColors.gradPurple,
                      color: submitting ? AppColors.glass2 : null,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.purpleLight,
                              ),
                            )
                          : Text('Start poll',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    questionCtrl.dispose();
    for (final ctrl in optionCtrls) {
      ctrl.dispose();
    }
  }

  Future<void> _votePoll(int optionIndex) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final poll = await ApiService().voteRoomPoll(roomId, optionIndex);
      if (mounted) setState(() => _activePoll = poll);
      unawaited(_loadMessages(silent: true));
    } catch (_) {
      _snack('Could not vote');
    }
  }

  Future<void> _closePoll() async {
    final roomId = _roomId;
    if (roomId == null || !_canControl) return;
    try {
      await ApiService().closeRoomPoll(roomId);
      if (mounted) setState(() => _activePoll = null);
      unawaited(_loadMessages(silent: true));
    } catch (_) {
      _snack('Could not close poll');
    }
  }

  Widget _buildQueue() {
    if (!_hasJoined) {
      return Center(
        child: Text('Join the room to see the queue',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
      );
    }
    final canAdd = _canControl || _settings['allow_track_suggestions'] != false;
    if (_queue.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎵', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Queue is empty',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text(
              _canControl
                  ? 'Add the first track for everyone'
                  : 'Suggest a track or wait for the host',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
          if (canAdd) ...[
            const SizedBox(height: 18),
            _primaryRoomButton(
                label: 'Add track',
                icon: Icons.add_rounded,
                onTap: _showTrackPicker),
          ],
        ]),
      ));
    }
    // Detect album mode: all tracks share same non-empty cover URL
    final covers = _queue
        .map((q) =>
            (Map<String, dynamic>.from(q as Map)['cover_url'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet();
    final albumMode = _queue.length >= 2 && covers.length == 1;
    final sharedCover = albumMode ? buildMediaUrl(covers.first) : '';

    return Column(children: [
      if (albumMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface2,
              ),
              child: CachedNetworkImage(
                imageUrl: sharedCover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.album_rounded, color: AppColors.text3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From one album',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.text3)),
                    Text('${_queue.length} tracks',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                  ]),
            ),
            if (canAdd)
              GestureDetector(
                onTap: _showTrackPicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.glass2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('+ Add',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                ),
              ),
          ]),
        )
      else if (canAdd)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _smallControl(
              icon: Icons.add_rounded,
              label: 'Add track to queue',
              onTap: _showTrackPicker),
        ),
      Expanded(
        child: _canControl
            ? ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: EdgeInsets.fromLTRB(20, albumMode ? 8 : 12, 20, 24),
                itemCount: _queue.length,
                physics: const BouncingScrollPhysics(),
                proxyDecorator: (child, _, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
                  child: child,
                ),
                onReorder: _reorderQueue,
                itemBuilder: (_, i) =>
                    _queueItemTile(i, key: _queueKey(i), compact: albumMode),
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(20, albumMode ? 8 : 12, 20, 24),
                itemCount: _queue.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (_, i) => _queueItemTile(i, compact: albumMode),
              ),
      ),
    ]);
  }

  Key _queueKey(int i) {
    final t = Map<String, dynamic>.from(_queue[i] as Map);
    return ValueKey('${t['track_id']}-${t['added_at']}-$i');
  }

  Widget _queueItemTile(int i, {Key? key, bool compact = false}) {
    final t = Map<String, dynamic>.from(_queue[i] as Map);
    final title = (t['title'] ?? 'Unknown').toString();
    final artist = (t['artist'] ?? '').toString();
    final coverUrl = buildMediaUrl(t['cover_url']?.toString() ?? '');
    final addedBy = (t['added_by'] ?? '').toString();
    final status = (t['status'] ?? 'queued').toString();
    final isPlaying = status == 'playing';
    final myId =
        (context.read<AuthProvider>().user?['id'] as num?)?.toInt() ?? 0;
    final votes = (t['votes'] as List?) ?? const [];
    final voted = votes.any((v) {
      if (v is num) return v.toInt() == myId;
      return v.toString() == '$myId';
    });
    final voteCount = (t['vote_count'] as num?)?.toInt() ?? votes.length;
    final democratic = _settings['democratic_queue'] == true;
    final showQueueVoting = democratic && _activePoll == null;

    if (compact) {
      // Album-style: compact row, no card border, track number on left
      return Container(
        key: key,
        decoration: isPlaying
            ? BoxDecoration(
                color: AppColors.purpleDark.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          leading: SizedBox(
            width: 40,
            child: Center(
              child: isPlaying
                  ? const Icon(Icons.volume_up_rounded,
                      color: AppColors.purpleLight, size: 18)
                  : Text('${i + 1}',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text3)),
            ),
          ),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
                  color: isPlaying ? AppColors.purpleLight : AppColors.text)),
          subtitle: Text(
            artist.isNotEmpty
                ? (status == 'suggested' ? '$artist · Suggested' : artist)
                : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (showQueueVoting)
              GestureDetector(
                onTap: () => _toggleQueueVote(i, voted),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      voted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: voted ? AppColors.purpleLight : AppColors.text3,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text('$voteCount',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.text3)),
                  ]),
                ),
              ),
            if (_canControl)
              Row(mainAxisSize: MainAxisSize.min, children: [
                PopupMenuButton<String>(
                  color: AppColors.surface2,
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.text3, size: 18),
                  onSelected: (v) {
                    if (v == 'play') _playQueueItem(i);
                    if (v == 'remove') _removeQueueItem(i);
                    if (v == 'approve') _approveSuggestion(i);
                  },
                  itemBuilder: (_) => [
                    if (status == 'suggested')
                      PopupMenuItem(
                        value: 'approve',
                        child: Text('Approve',
                            style: GoogleFonts.outfit(color: AppColors.text)),
                      ),
                    PopupMenuItem(
                      value: 'play',
                      child: Text('Play now',
                          style: GoogleFonts.outfit(color: AppColors.text)),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove',
                          style: GoogleFonts.outfit(color: Colors.red)),
                    ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.drag_indicator_rounded,
                        color: AppColors.text3, size: 18),
                  ),
                ),
              ])
            else
              const Icon(Icons.more_vert_rounded,
                  color: AppColors.text3, size: 18),
          ]),
        ),
      );
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.purpleDark.withOpacity(0.22)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPlaying
                  ? AppColors.purpleLight.withOpacity(0.5)
                  : AppColors.border)),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(10)),
          child: coverUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                      child: Icon(Icons.music_note_rounded,
                          color: Colors.white, size: 20)),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.music_note_rounded,
                          color: Colors.white, size: 20)),
                )
              : const Center(
                  child: Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          if (artist.isNotEmpty)
            Text(artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
          if (addedBy.isNotEmpty)
            Text(
                status == 'suggested'
                    ? 'Suggested by $addedBy'
                    : 'Added by $addedBy',
                style:
                    GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
          if (democratic)
            Text('$voteCount vote${voteCount == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purpleLight)),
        ])),
        if (showQueueVoting)
          GestureDetector(
            onTap: () => _toggleQueueVote(i, voted),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: voted
                    ? AppColors.purpleDark.withOpacity(0.22)
                    : AppColors.glass2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: voted
                      ? AppColors.purpleLight.withOpacity(0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  voted
                      ? Icons.how_to_vote_rounded
                      : Icons.how_to_vote_outlined,
                  color: voted ? AppColors.purpleLight : AppColors.text3,
                  size: 17,
                ),
                if (voteCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$voteCount',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: voted ? AppColors.purpleLight : AppColors.text3,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        if (_canControl) ...[
          if (status == 'suggested')
            IconButton(
              tooltip: 'Approve suggestion',
              onPressed: () => _approveSuggestion(i),
              icon: const Icon(Icons.check_rounded,
                  color: AppColors.purpleLight, size: 20),
            ),
          IconButton(
            tooltip: 'Play now',
            onPressed: () => _playQueueItem(i),
            icon: const Icon(Icons.play_arrow_rounded,
                color: AppColors.purpleLight, size: 22),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeQueueItem(i),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.text3, size: 20),
          ),
          ReorderableDragStartListener(
            index: i,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.drag_indicator_rounded,
                  color: AppColors.text2, size: 19),
            ),
          ),
        ] else
          Text('${i + 1}',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3)),
      ]),
    );
  }

  void _showParticipantsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('People',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const Spacer(),
              Text('${_participants.length}',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.purpleLight)),
            ]),
            if (_canControl && _joinRequests.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                Text('Requests',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text2)),
                const Spacer(),
                GestureDetector(
                  onTap: _approveAllRequests,
                  child: Text('Approve all',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.purpleLight)),
                ),
              ]),
              const SizedBox(height: 8),
              ..._joinRequests.whereType<Map>().map((raw) {
                final req = Map<String, dynamic>.from(raw);
                final userId = (req['user_id'] as num?)?.toInt() ?? 0;
                final name = (req['first_name'] ?? req['username'] ?? 'Guest')
                    .toString();
                return _personRow(
                  name: name,
                  subtitle: 'Wants to join',
                  onTap: () => _openUserProfile(
                    userId,
                    initialUser: {
                      ...req,
                      'id': userId,
                      'display_name': name,
                    },
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: () => _approveRequest(userId, false),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFf87171)),
                    ),
                    IconButton(
                      onPressed: () => _approveRequest(userId, true),
                      icon: const Icon(Icons.check_rounded,
                          color: AppColors.purpleLight),
                    ),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Participants',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text2)),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: _participants.whereType<Map>().map((raw) {
                  final person = Map<String, dynamic>.from(raw);
                  final name =
                      (person['display_name'] ?? person['username'] ?? 'User')
                          .toString();
                  final role = (person['role'] ?? 'participant').toString();
                  final online = person['is_online'] == true;
                  return _personRow(
                    name: name,
                    subtitle:
                        '${role == 'host' ? 'Host' : 'Participant'} · ${online ? 'online' : 'offline'}',
                    onTap: () => _openUserProfile(
                      (person['user_id'] as num?)?.toInt() ??
                          (person['id'] as num?)?.toInt() ??
                          0,
                      initialUser: {
                        ...person,
                        'id': (person['user_id'] as num?)?.toInt() ??
                            (person['id'] as num?)?.toInt() ??
                            0,
                        'display_name': name,
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _chatDestinationName(Map<String, dynamic> chat) {
    final kind = (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct')
        .toString();
    if (kind == 'group') {
      final partner =
          (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
      final title =
          (chat['title'] ??
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

  String _chatDestinationSubtitle(Map<String, dynamic> chat) {
    final kind = (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct')
        .toString();
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

  String _chatDestinationAvatar(Map<String, dynamic> chat) {
    final kind = (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct')
        .toString();
    if (kind == 'user') {
      return buildMediaUrl((chat['avatar_url'] ?? '').toString());
    }
    final partner =
        (chat['partner'] as Map?)?.cast<String, dynamic>() ?? const {};
    return buildMediaUrl((partner['avatar_url'] ?? chat['avatar_url'] ?? '')
        .toString());
  }

  String _shareDestinationKey(Map<String, dynamic> chat) {
    final kind = (chat['destination_type'] ?? chat['chat_kind'] ?? 'direct')
        .toString();
    if (kind == 'user' || kind == 'direct' || kind == 'match') {
      final personId = (chat['user_id'] ??
              chat['id'] ??
              (chat['partner'] as Map?)?['id'])
          ?.toString();
      if (personId != null && personId.isNotEmpty) {
        return 'person:$personId';
      }
    }
    if (kind == 'group') {
      final groupId = (chat['group_chat_id'] ?? chat['chat_id'])?.toString();
      if (groupId != null && groupId.isNotEmpty) {
        return 'group:$groupId';
      }
    }
    return [
      kind,
      chat['match_id'],
      chat['chat_id'],
      chat['group_chat_id'],
      chat['user_id'] ?? chat['id'],
    ].join(':');
  }

  Future<List<Map<String, dynamic>>> _loadRoomShareDestinations() async {
    final byKey = <String, Map<String, dynamic>>{};
    final directUserIds = <int>{};
    int priority(Map<String, dynamic> item) {
      final kind =
          (item['destination_type'] ?? item['chat_kind'] ?? 'direct').toString();
      if (kind == 'match') return 0;
      if (kind == 'direct') return 1;
      if (kind == 'group') return 2;
      return 3;
    }
    void add(Map<String, dynamic> item) {
      final key = _shareDestinationKey(item);
      if (key.trim().replaceAll(':', '').isEmpty) return;
      final existing = byKey[key];
      if (existing == null || priority(item) < priority(existing)) {
        byKey[key] = item;
      }
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
      final me = context.read<AuthProvider>().user;
      final myId = (me?['id'] as num?)?.toInt();
      if (myId != null) {
        final following = await ApiService().getUserFollowing(myId, limit: 100);
        for (final user in following) {
          final userId = (user['id'] as num?)?.toInt();
          if (userId == null || userId == myId) continue;
          if (directUserIds.contains(userId)) continue;
          add({
            ...user,
            'destination_type': 'user',
            'user_id': userId,
          });
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
        add({
          ...user,
          'destination_type': 'user',
          'user_id': userId,
        });
      }
    } catch (_) {}

    return byKey.values.toList()
      ..sort((a, b) {
        final ak = (a['destination_type'] ?? '').toString();
        final bk = (b['destination_type'] ?? '').toString();
        if (ak == bk) {
          return _chatDestinationName(a)
              .toLowerCase()
              .compareTo(_chatDestinationName(b).toLowerCase());
        }
        if (ak == 'group') return -1;
        if (bk == 'group') return 1;
        return ak.compareTo(bk);
      });
  }

  Future<void> _shareRoomInvite() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final roomName = (_room['name'] ?? 'Live Room').toString();
      final inviteCode = (_room['invite_code'] ?? '').toString();
      final isPublic = _room['is_public'] == true;
      final shareText = StringBuffer()
        ..writeln('Join my MoodWave Live Party: $roomName')
        ..writeln()
        ..writeln(isPublic
            ? 'This room is public — join right away.'
            : 'This room is private — use the invite code below.')
        ..writeln('Invite code: $inviteCode')
        ..writeln('Room ID: $roomId');
      final text = shareText.toString().trim();
      final destinations = await _loadRoomShareDestinations();
      if (!mounted) return;
      final sentInviteKeys = <String>{};
      final sendingInviteKeys = <String>{};
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        useRootNavigator: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                ),
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('Share Live Party',
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text(
                      'Send this room to people from Social, Following, real groups, or open the system share menu.',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradPurple,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.ios_share_rounded,
                            color: Colors.white, size: 18),
                      ),
                      title: Text('System share',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      subtitle: Text('Open device share menu',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Share.share(
                          text,
                          subject: 'Join my MoodWave Live Party',
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('MoodWave people and groups',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text2)),
                    const SizedBox(height: 8),
                    if (destinations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('No chats yet',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: destinations.map((chat) {
                            final key = _shareDestinationKey(chat);
                            final sent = sentInviteKeys.contains(key);
                            final sending = sendingInviteKeys.contains(key);
                            return _personRow(
                              name: _chatDestinationName(chat),
                              subtitle: _chatDestinationSubtitle(chat),
                              avatarUrl: _chatDestinationAvatar(chat),
                              trailing: TextButton(
                                onPressed: sent || sending
                                    ? null
                                    : () async {
                                        try {
                                          setSheetState(
                                              () => sendingInviteKeys.add(key));
                                          final kind =
                                              (chat['destination_type'] ??
                                                      chat['chat_kind'] ??
                                                      'direct')
                                                  .toString();
                                          final matchId =
                                              (chat['match_id'] as num?)
                                                  ?.toInt();
                                          final chatId =
                                              (chat['chat_id'] as num?)
                                                  ?.toInt();
                                          final groupChatId =
                                              (chat['group_chat_id'] as num?)
                                                  ?.toInt();
                                          int? directChatId = chatId;
                                          if (kind == 'user') {
                                            final userId =
                                                ((chat['user_id'] ??
                                                            chat['id'])
                                                        as num?)
                                                    ?.toInt();
                                            if (userId == null) {
                                              throw StateError(
                                                  'Missing user id');
                                            }
                                            final started = await ApiService()
                                                .startDirectChat(userId);
                                            directChatId =
                                                (started['chat_id'] as num?)
                                                    ?.toInt();
                                          }
                                          await ApiService()
                                              .sendRoomInviteMessage(
                                            matchId: kind == 'match'
                                                ? matchId
                                                : null,
                                            chatId: kind == 'direct' ||
                                                    kind == 'user'
                                                ? directChatId
                                                : null,
                                            groupChatId: kind == 'group'
                                                ? groupChatId
                                                : null,
                                            room: _room,
                                            inviteRole: 'listener',
                                          );
                                          if (!mounted) return;
                                          setSheetState(() {
                                            sendingInviteKeys.remove(key);
                                            sentInviteKeys.add(key);
                                          });
                                          _snack('Invite sent');
                                        } catch (_) {
                                          setSheetState(() =>
                                              sendingInviteKeys.remove(key));
                                          if (mounted) {
                                            _snack('Could not send invite',
                                                error: true);
                                          }
                                        }
                                      },
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (sending)
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.purpleLight,
                                          ),
                                        )
                                      else if (sent)
                                        const Icon(Icons.check_rounded,
                                            size: 15, color: AppColors.green),
                                      if (sending || sent)
                                        const SizedBox(width: 5),
                                      Text(sent ? 'Sent' : 'Send',
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: sent
                                                  ? AppColors.green
                                                  : AppColors.purpleLight)),
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          });
        },
      );
    } catch (_) {
      if (mounted) _snack('Could not share invite', error: true);
    }
  }

  Widget _personRow({
    required String name,
    required String subtitle,
    String avatarUrl = '',
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final infoRow = Row(children: [
      Container(
        width: 36,
        height: 36,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: avatarUrl.isEmpty
              ? const LinearGradient(
                  colors: [Color(0xFF7c3aed), Color(0xFFec4899)])
              : null,
          color: avatarUrl.isNotEmpty ? AppColors.glass : null,
          shape: BoxShape.circle,
        ),
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Center(
                  child: Text(initial,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              )
            : Center(
                child: Text(initial,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
      ),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        Text(subtitle,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
      ])),
      if (trailing == null && onTap != null)
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.text3),
    ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: infoRow,
            ),
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: trailing,
          ),
      ]),
    );
  }

  Widget _buildPeople() {
    final roomDescription = (_room['description'] ?? '').toString().trim();
    final roomBackground =
        (_room['background_url'] ?? _settings['background_url'] ?? '')
            .toString()
            .trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_canControl) ...[
          Text('Room settings',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _editRoomDetails,
                  child: Container(
                    height: 108,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 18, color: AppColors.purpleLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Room name & description',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text)),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 18, color: AppColors.text3),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (_room['name'] ?? 'Live Room').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          roomDescription.isNotEmpty
                              ? roomDescription
                              : 'Tap to update the room details',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _changeBackground,
                  child: Container(
                    height: 108,
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: roomBackground.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: buildMediaUrl(roomBackground),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                )
                              : Container(color: AppColors.surface),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(
                                roomBackground.isNotEmpty ? 0.34 : 0.0),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.image_outlined,
                                      size: 17, color: AppColors.purpleLight),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 18, color: AppColors.text3),
                                ],
                              ),
                              const Spacer(),
                              Text('Room background',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text)),
                              const SizedBox(height: 3),
                              Text(
                                roomBackground.isNotEmpty
                                    ? 'Tap to change image'
                                    : 'Tap to set image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                    fontSize: 11, color: AppColors.text3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _settingSwitch(
            label: 'Public room',
            subtitle: 'Show this room in Party',
            value: _room['is_public'] == true,
            onChanged: (v) => _saveRoomSettings({
              'is_public': v,
              'locked': !v,
              'require_approval':
                  v ? false : (_settings['require_approval'] != false),
            }),
          ),
          _settingSwitch(
            label: 'Require approval',
            subtitle: 'Host/co-host approves join requests',
            value: _settings['require_approval'] == true,
            onChanged: (v) => _saveRoomSettings({'require_approval': v}),
          ),
          _settingSwitch(
            label: 'Allow suggestions',
            subtitle: 'Listeners can suggest tracks',
            value: _settings['allow_track_suggestions'] != false,
            onChanged: (v) => _saveRoomSettings({'allow_track_suggestions': v}),
          ),
          _settingSwitch(
            label: 'Quiet mode',
            subtitle: 'Only host/co-host can chat',
            value: _settings['quiet_mode'] == true,
            onChanged: (v) => _saveRoomSettings({'quiet_mode': v}),
          ),
          _settingSwitch(
            label: 'Democratic queue',
            subtitle: 'Listeners vote for what should play next',
            value: _settings['democratic_queue'] == true,
            onChanged: (v) => _saveRoomSettings({'democratic_queue': v}),
          ),
          const SizedBox(height: 18),
        ],
        if (_canControl && _joinRequests.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.purpleDark.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.purpleLight.withOpacity(0.28)),
            ),
            child: Row(children: [
              const Icon(Icons.person_add_alt_1_rounded,
                  color: AppColors.purpleLight, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '${_joinRequests.length} pending join request${_joinRequests.length == 1 ? '' : 's'}',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
              ),
              GestureDetector(
                onTap: _approveAllRequests,
                child: Text('Approve all',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.purpleLight)),
              ),
            ]),
          ),
        ],
        Text('Participants',
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        const SizedBox(height: 10),
        if (_participants.isEmpty) ...[
          if (_room['host'] != null) ...[
            () {
              final h = Map<String, dynamic>.from(_room['host'] as Map);
              final hName =
                  (h['display_name'] ?? h['username'] ?? 'Host').toString();
              return _personRow(
                name: hName,
                subtitle: 'Host · online',
                onTap: () => _openUserProfile(
                  (h['id'] as num?)?.toInt() ??
                      (h['user_id'] as num?)?.toInt() ??
                      0,
                  initialUser: {
                    ...h,
                    'display_name': hName,
                  },
                ),
              );
            }(),
          ] else
            Text('No participants yet',
                style:
                    GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
        ] else
          ..._participants.whereType<Map>().map((raw) {
            final person = Map<String, dynamic>.from(raw);
            final userId = (person['user_id'] as num?)?.toInt() ?? 0;
            final name =
                (person['display_name'] ?? person['username'] ?? 'User')
                    .toString();
            final role = (person['role'] ?? 'participant').toString();
            final online = person['is_online'] == true;
            final muted = person['is_muted'] == true;
            return _personRow(
              name: name,
              subtitle:
                  '${role == 'co_host' ? 'Co-host' : role == 'host' ? 'Host' : 'Listener'} · ${online ? 'online' : 'offline'}${muted ? ' · muted' : ''}',
              onTap: () => _openUserProfile(
                userId,
                initialUser: {
                  ...person,
                  'id': userId,
                  'display_name': name,
                },
              ),
              trailing: _canControl && role != 'host'
                  ? PopupMenuButton<String>(
                      color: AppColors.surface,
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: AppColors.text2),
                      onSelected: (value) => _handleParticipantAction(
                          userId: userId, role: role, action: value),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value:
                                role == 'co_host' ? 'participant' : 'co_host',
                            child: Text(
                                role == 'co_host'
                                    ? 'Remove co-host'
                                    : 'Make co-host',
                                style:
                                    GoogleFonts.outfit(color: AppColors.text))),
                        PopupMenuItem(
                            value: muted ? 'unmute' : 'mute',
                            child: Text(muted ? 'Unmute' : 'Mute',
                                style:
                                    GoogleFonts.outfit(color: AppColors.text))),
                        PopupMenuItem(
                            value: 'kick',
                            child: Text('Kick',
                                style:
                                    GoogleFonts.outfit(color: AppColors.text))),
                        PopupMenuItem(
                            value: 'ban',
                            child: Text('Ban',
                                style: GoogleFonts.outfit(
                                    color: const Color(0xFFf87171)))),
                      ],
                    )
                  : null,
            );
          }),
      ]),
    );
  }

  Widget _settingSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        Switch(
          value: value,
          activeColor: AppColors.purpleLight,
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Future<void> _changeBackground() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1280, imageQuality: 82);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 6 * 1024 * 1024) {
        _snack('Image must be under 6 MB');
        return;
      }
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final b64 = base64Encode(bytes);
      final dataUrl = 'data:$mime;base64,$b64';
      await _saveRoomSettings({'background_data_url': dataUrl});
      _snack('Background updated');
    } catch (_) {
      if (mounted) _snack('Could not update background');
    }
  }

  Future<void> _editRoomDetails() async {
    final nameCtrl =
        TextEditingController(text: (_room['name'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (_room['description'] ?? '').toString());
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Edit room',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
                const SizedBox(height: 14),
                _roomTextField(nameCtrl, 'Room name', Icons.title_rounded),
                const SizedBox(height: 10),
                _roomTextField(descCtrl, 'Description', Icons.notes_rounded,
                    maxLines: 3),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      _snack('Room name is required');
                      return;
                    }
                    Navigator.of(ctx).pop({
                      'name': name,
                      'description': descCtrl.text.trim(),
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text('Save changes',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    if (result == null || !mounted) return;
    try {
      await _saveRoomSettings(result);
    } catch (_) {
      if (mounted) _snack('Could not update room');
    }
  }

  Widget _roomTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.text3, size: 19),
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.text3),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
      ),
    );
  }

  Future<void> _saveRoomSettings(Map<String, dynamic> data) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final previous = Map<String, dynamic>.from(_room);
    final nextSettings = {..._settings, ...data};
    _savingRoomSettings = true;
    setState(() {
      _room = {
        ..._room,
        'settings': nextSettings,
        if (data.containsKey('is_public')) 'is_public': data['is_public'],
        if (data.containsKey('name')) 'name': data['name'],
        if (data.containsKey('description')) 'description': data['description'],
      };
    });
    try {
      final result = await ApiService().updateRoomSettings(roomId, data);
      if (!mounted) return;
      setState(() {
        _room = {
          ..._room,
          'settings': result['settings'] ?? _settings,
          'is_public': result['is_public'] ?? _room['is_public'],
          if (result['name'] != null) 'name': result['name'],
          if (result['description'] != null)
            'description': result['description'],
          if (result['background_url'] != null)
            'background_url': result['background_url'],
        };
      });
    } catch (_) {
      if (mounted) setState(() => _room = previous);
      _snack('Could not update room settings');
      rethrow;
    } finally {
      _savingRoomSettings = false;
    }
  }

  Future<void> _handleParticipantAction({
    required int userId,
    required String role,
    required String action,
  }) async {
    final roomId = _roomId;
    if (roomId == null || userId <= 0) return;
    try {
      switch (action) {
        case 'co_host':
        case 'participant':
          await ApiService().setRoomParticipantRole(roomId, userId, action);
          break;
        case 'mute':
          await ApiService().muteRoomParticipant(roomId, userId);
          break;
        case 'unmute':
          await ApiService().unmuteRoomParticipant(roomId, userId);
          break;
        case 'kick':
          await ApiService().kickRoomParticipant(roomId, userId);
          break;
        case 'ban':
          await ApiService().banRoomParticipant(roomId, userId);
          break;
      }
      await _loadRoom(silent: true);
    } catch (_) {
      _snack('Could not update participant');
    }
  }

  Future<void> _approveSuggestion(int index) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final data = await ApiService().approveRoomQueueItem(roomId, index);
      if (!mounted) return;
      setState(() => _queue = (data['queue'] as List?) ?? _queue);
    } catch (_) {}
  }

  Future<void> _voteQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final item = _queue[index];
    final voted = (item is Map) && item['my_vote'] == true;
    await _toggleQueueVote(index, voted);
  }

  Future<void> _toggleQueueVote(int index, bool voted) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final data = voted
          ? await ApiService().unvoteRoomQueueItem(roomId, index)
          : await ApiService().voteRoomQueueItem(roomId, index);
      if (!mounted) return;
      setState(() => _queue = (data['queue'] as List?) ?? _queue);
    } catch (_) {
      _snack('Could not update vote');
    }
  }

  Future<void> _addTrackToRoom(Map<String, dynamic> t) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final payload = _roomTrackPayload(t);
    if (payload == null) {
      _snack('Could not read this track');
      return;
    }
    try {
      final result = await ApiService().addToRoomQueue(roomId, payload);
      final returnedQueue = result['queue'] as List?;
      if (mounted) {
        setState(() {
          if (returnedQueue != null) _queue = returnedQueue;
        });
      }
      final noTrackPlaying = (_room['current_track'] as Map?)?.isEmpty ?? true;
      if (_canControl && noTrackPlaying && _queue.isNotEmpty) {
        await _playQueueItem(_queue.length - 1);
      }
      _snack(_canControl ? 'Added to queue' : 'Suggested to host');
    } catch (_) {
      _snack('Could not add this track');
    }
  }

  Future<void> _addTracksToRoom(List<Map<String, dynamic>> tracks) async {
    if (tracks.isEmpty) return;
    final roomId = _roomId;
    if (roomId == null) return;
    final payloads = tracks
        .map(_roomTrackPayload)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (payloads.isEmpty) {
      _snack('Could not add these tracks');
      return;
    }
    try {
      final result = await ApiService().addBulkToRoomQueue(roomId, payloads);
      final returnedQueue = result['queue'] as List?;
      final added = (result['added'] as num?)?.toInt() ?? payloads.length;
      if (mounted) {
        setState(() {
          if (returnedQueue != null) _queue = returnedQueue;
        });
      }
      final noTrackPlaying = (_room['current_track'] as Map?)?.isEmpty ?? true;
      if (_canControl && noTrackPlaying && _queue.isNotEmpty) {
        await _playQueueItem(0);
      }
      _snack(added == 1
          ? (_canControl ? 'Added to queue' : 'Suggested to host')
          : '$added tracks ${_canControl ? 'added' : 'suggested'}');
    } catch (_) {
      _snack('Could not add these tracks');
    }
  }

  Map<String, dynamic>? _roomTrackPayload(Map<String, dynamic> raw) {
    final nested = raw['track'];
    final track = <String, dynamic>{
      ...raw,
      if (nested is Map) ...Map<String, dynamic>.from(nested),
    };
    final id = (track['spotify_id'] ??
            track['spotify_track_id'] ??
            track['track_spotify_id'] ??
            track['track_id'] ??
            track['deezer_id'] ??
            track['deezer_track_id'] ??
            track['id'] ??
            '')
        .toString();
    final title = (track['title'] ??
            track['track_title'] ??
            track['trackName'] ??
            track['name'] ??
            '')
        .toString()
        .trim();
    final rawArtist = track['artist'];
    final artist = (rawArtist is Map
            ? rawArtist['name']
            : rawArtist ??
                track['track_artist'] ??
                track['artist_name'] ??
                track['artistName'] ??
                '')
        .toString()
        .trim();
    final cover = (track['cover_url'] ??
            track['track_cover_url'] ??
            track['cover'] ??
            track['album_cover_url'] ??
            track['artworkUrl100'] ??
            track['picture_medium'] ??
            '')
        .toString();
    final preview =
        (track['preview_url'] ?? track['previewUrl'] ?? '').toString();
    final duration = track['duration_ms'] ??
        track['durationMillis'] ??
        track['trackTimeMillis'] ??
        track['duration'];
    if (id.isEmpty || id == 'null' || title.isEmpty) return null;
    return {
      'track_id': id,
      'title': title,
      'artist': artist.isEmpty ? 'Unknown artist' : artist,
      'cover_url': cover.isEmpty ? null : cover,
      'preview_url': preview.isEmpty ? null : preview,
      if (duration is num)
        'duration_ms':
            duration > 1000 ? duration.toInt() : (duration * 1000).toInt(),
    };
  }

  void _showTrackPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomTrackPickerSheet(
        canControl: _canControl,
        onSelected: (tracks) async {
          Navigator.of(context).pop();
          await _addTracksToRoom(tracks);
        },
      ),
    );
  }

  Widget _buildLyrics(String trackTitle, String trackArtist) {
    if (!_hasJoined) {
      return Center(
        child: Text('Join the room to see lyrics',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
      );
    }
    if (trackTitle.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎤', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text('No track playing',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Lyrics will appear here when a song plays',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2),
              textAlign: TextAlign.center),
        ]),
      );
    }
    if (_lyricsLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.purpleLight),
          ),
          const SizedBox(height: 14),
          Text('Finding lyrics…',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
        ]),
      );
    }
    if (_lyricsLines.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎵', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text('No lyrics found',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('$trackTitle — $trackArtist',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2),
              textAlign: TextAlign.center),
        ]),
      );
    }

    final activeIdx = _activeLyricIndex();
    final canSeek = _hasJoined &&
        _lyricsSyncedTimesMs.isNotEmpty &&
        _lyricsSyncedTimesMs.length == _lyricsLines.length;

    return ListView.builder(
      controller: _lyricsScrollCtrl,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
      physics: const BouncingScrollPhysics(),
      itemCount: _lyricsLines.length,
      itemBuilder: (_, i) {
        final isActive = i == activeIdx;
        final isPast = i < activeIdx;
        final lineWidget = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _lyricsLines[i],
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isActive ? 22 : 16,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive
                  ? Colors.white
                  : isPast
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.55),
              height: 1.4,
            ),
          ),
        );
        if (!canSeek) return lineWidget;
        return GestureDetector(
          onTap: () => unawaited(
            _seekRoomLyricsTo(Duration(milliseconds: _lyricsSyncedTimesMs[i])),
          ),
          child: lineWidget,
        );
      },
    );
  }

  int _activeLyricIndex() {
    if (_lyricsLines.isEmpty) return -1;
    // Prefer actual player position for accurate sync
    final posMs = _playerProvider != null
        ? _playerProvider!.position.inMilliseconds
        : _positionMs;
    var activeIdx = -1;
    if (_lyricsSyncedTimesMs.isNotEmpty &&
        _lyricsSyncedTimesMs.length == _lyricsLines.length) {
      if (posMs < _lyricsSyncedTimesMs.first) {
        return 0;
      }
      for (int i = 0; i < _lyricsSyncedTimesMs.length; i++) {
        if (_lyricsSyncedTimesMs[i] <= posMs) activeIdx = i;
      }
    } else if (_lyricsApproxSync && _durationMs > 0) {
      activeIdx = ((posMs / _durationMs) * _lyricsLines.length)
          .floor()
          .clamp(0, _lyricsLines.length - 1);
    }
    return activeIdx;
  }

  String _currentLyricLine() {
    if (!_hasExactLyricsSync) return '';
    final idx = _activeLyricIndex();
    if (_lyricsLines.isEmpty) return '';
    if (idx < 0) return _lyricsLines.first;
    if (idx >= _lyricsLines.length) return _lyricsLines.last;
    return _lyricsLines[idx];
  }

  void _autoScrollLyrics() {
    final idx = _activeLyricIndex();
    if (idx < 0 || idx == _lastScrolledLyricIdx) return;
    _lastScrolledLyricIdx = idx;
    if (!_lyricsScrollCtrl.hasClients) return;
    // Estimate offset: 16px top padding + ~36px per line
    const lineH = 36.0;
    final viewH = _lyricsScrollCtrl.position.viewportDimension;
    final offset = (16.0 + idx * lineH - viewH / 2 + lineH / 2)
        .clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent);
    _lyricsScrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class _RoomTrackPickerSheet extends StatefulWidget {
  final bool canControl;
  final ValueChanged<List<Map<String, dynamic>>> onSelected;

  const _RoomTrackPickerSheet({
    required this.canControl,
    required this.onSelected,
  });

  @override
  State<_RoomTrackPickerSheet> createState() => _RoomTrackPickerSheetState();
}

class _RoomTrackPickerSheetState extends State<_RoomTrackPickerSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  bool _searchError = false;
  String _searchErrorDetail = '';
  bool _loadingLibrary = true;
  List<Map<String, dynamic>> _search = [];
  List<Map<String, dynamic>> _liked = [];
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _playlistTracks = [];
  String _playlistTitle = '';
  final Map<String, Map<String, dynamic>> _selected = {};
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final results = await Future.wait([
        ApiService().getLikedTracks(limit: 60),
        ApiService().getRecentlyPlayed(limit: 60),
        ApiService().getPlaylists(),
      ]);
      var recent = _normalizeList(results[1]);
      if (recent.isEmpty) {
        final history = await ApiService().getListeningHistory(limit: 80);
        final flattened = <dynamic>[];
        for (final section in history) {
          if (section is Map) {
            flattened.addAll((section['tracks'] as List?) ?? const []);
          } else {
            flattened.add(section);
          }
        }
        recent = _normalizeList(flattened);
      }
      if (!mounted) return;
      setState(() {
        _liked = _normalizeList(results[0]);
        _recent = recent;
        _playlists = _normalizeList(results[2]);
        _loadingLibrary = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLibrary = false);
    }
  }

  List<Map<String, dynamic>> _normalizeList(List<dynamic> raw) {
    final seen = <String>{};
    final tracks = <Map<String, dynamic>>[];
    for (final item in raw.whereType<Map>()) {
      final track = _normalizeTrackMap(Map<String, dynamic>.from(item));
      final key = _dedupeTrackKey(track);
      if (key.isEmpty || !seen.add(key)) continue;
      tracks.add(track);
    }
    return tracks;
  }

  Map<String, dynamic> _normalizeTrackMap(Map<String, dynamic> raw) {
    final nested = raw['track'];
    final item = <String, dynamic>{
      ...raw,
      if (nested is Map) ...Map<String, dynamic>.from(nested),
    };
    final id = item['spotify_id'] ??
        item['spotify_track_id'] ??
        item['track_spotify_id'] ??
        item['track_id'] ??
        item['deezer_id'] ??
        item['deezer_track_id'] ??
        item['id'];
    if (id != null && id.toString().isNotEmpty && id.toString() != 'null') {
      item['spotify_id'] ??= id.toString();
      item['track_id'] ??= id.toString();
    }
    if ((item['title'] == null || item['title'].toString().isEmpty) &&
        (item['track_title'] != null ||
            item['trackName'] != null ||
            item['name'] != null)) {
      item['title'] =
          (item['track_title'] ?? item['trackName'] ?? item['name']).toString();
    }
    final artistMap = item['artist'];
    if (artistMap is Map) {
      item['artist'] =
          (artistMap['name'] ?? artistMap['title'] ?? '').toString();
    }
    final albumMap = item['album'];
    if (albumMap is Map &&
        (item['cover_url'] == null || item['cover_url'].toString().isEmpty)) {
      dynamic albumCover = albumMap['cover_url'] ??
          albumMap['cover'] ??
          albumMap['cover_medium'] ??
          albumMap['picture_medium'];
      final images = albumMap['images'];
      if ((albumCover == null || albumCover.toString().isEmpty) &&
          images is List &&
          images.isNotEmpty) {
        final firstImage = images.first;
        if (firstImage is Map) albumCover = firstImage['url'];
      }
      if (albumCover != null && albumCover.toString().isNotEmpty) {
        item['cover_url'] = albumCover.toString();
      }
    }
    if ((item['artist'] == null || item['artist'].toString().isEmpty) &&
        (item['track_artist'] != null ||
            item['artist_name'] != null ||
            item['artistName'] != null)) {
      item['artist'] =
          (item['track_artist'] ?? item['artist_name'] ?? item['artistName'])
              .toString();
    }
    if ((item['cover_url'] == null || item['cover_url'].toString().isEmpty) &&
        (item['track_cover_url'] != null ||
            item['cover'] != null ||
            item['album_cover_url'] != null ||
            item['artworkUrl100'] != null ||
            item['picture_medium'] != null ||
            item['picture_big'] != null ||
            item['image_url'] != null)) {
      item['cover_url'] = (item['track_cover_url'] ??
              item['cover'] ??
              item['album_cover_url'] ??
              item['artworkUrl100'] ??
              item['picture_medium'] ??
              item['picture_big'] ??
              item['image_url'])
          .toString();
    }
    if ((item['preview_url'] == null ||
            item['preview_url'].toString().isEmpty) &&
        (item['previewUrl'] != null || item['preview'] != null)) {
      item['preview_url'] = (item['previewUrl'] ?? item['preview']).toString();
    }
    return item;
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _search = [];
        _searching = false;
      });
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _searchError = false;
    });
    try {
      final raw = await ApiService().searchTracksWithFallback(query, limit: 20);
      if (!mounted) return;
      if (generation != _searchGeneration) return;
      var found = raw
          .map((e) => _normalizeTrackMap(Map<String, dynamic>.from(e)))
          .where((item) => _trackKey(item).isNotEmpty)
          .toList();
      if (found.isEmpty) {
        final needle = query.toLowerCase();
        found = [..._liked, ..._recent]
            .where((track) =>
                _title(track).toLowerCase().contains(needle) ||
                _artist(track).toLowerCase().contains(needle))
            .toList();
      }
      setState(() {
        _search = found;
        _searching = false;
        _searchError = false;
      });
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _search = [];
          _searching = false;
          _searchError = true;
          _searchErrorDetail = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openPlaylist(Map<String, dynamic> playlist) async {
    final id = (playlist['id'] as num?)?.toInt() ??
        (playlist['playlist_id'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      _loadingLibrary = true;
      _playlistTitle =
          (playlist['title'] ?? playlist['name'] ?? 'Playlist').toString();
      _playlistTracks = [];
    });
    try {
      final detail = await ApiService().getPlaylist(id);
      final tracks = (detail['tracks'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _playlistTracks = _normalizeList(tracks);
        _loadingLibrary = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLibrary = false);
    }
  }

  String _title(Map<String, dynamic> t) => (t['title'] ??
          t['track_title'] ??
          t['trackName'] ??
          t['name'] ??
          'Unknown')
      .toString();
  String _artist(Map<String, dynamic> t) => (t['artist'] ??
          t['track_artist'] ??
          t['artist_name'] ??
          t['artistName'] ??
          '')
      .toString();
  String _cover(Map<String, dynamic> t) => (t['cover_url'] ??
          t['track_cover_url'] ??
          t['cover'] ??
          t['album_cover_url'] ??
          t['artworkUrl100'] ??
          '')
      .toString();
  String _trackKey(Map<String, dynamic> t) => (t['spotify_id'] ??
          t['spotify_track_id'] ??
          t['track_spotify_id'] ??
          t['track_id'] ??
          t['deezer_id'] ??
          t['deezer_track_id'] ??
          t['id'] ??
          '${_title(t)}-${_artist(t)}')
      .toString();

  String _dedupeTrackKey(Map<String, dynamic> t) {
    final title = _title(t).trim().toLowerCase();
    final artist = _artist(t).trim().toLowerCase();
    if (title.isEmpty) return _trackKey(t).trim();
    return '$title|$artist';
  }

  void _toggleTrack(Map<String, dynamic> track) {
    final key = _trackKey(track);
    setState(() {
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = track;
      }
    });
  }

  Widget _trackList(List<Map<String, dynamic>> tracks, String empty) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(empty,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        final cover = buildMediaUrl(_cover(t));
        final selected = _selected.containsKey(_trackKey(t));
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.gradMixed,
            ),
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Icon(Icons.music_note_rounded,
                        color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white),
                  )
                : const Icon(Icons.music_note_rounded, color: Colors.white),
          ),
          title: Text(_title(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          subtitle: Text(_artist(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
          trailing: GestureDetector(
            onTap: () => _toggleTrack(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.purpleLight
                    : AppColors.purpleLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                  selected ? 'Added' : (widget.canControl ? 'Add' : 'Suggest'),
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.purpleLight)),
            ),
          ),
          onTap: () => _toggleTrack(t),
        );
      },
    );
  }

  Widget _playlistList() {
    if (_playlistTracks.isNotEmpty || _playlistTitle.isNotEmpty) {
      return Column(children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() {
              _playlistTitle = '';
              _playlistTracks = [];
            }),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text2),
          ),
          Expanded(
            child: Text(_playlistTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
        ]),
        Expanded(
            child: _trackList(_playlistTracks, 'No tracks in this playlist')),
      ]);
    }
    if (_playlists.isEmpty) {
      return Center(
        child: Text('No playlists yet',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _playlists.length,
      itemBuilder: (_, i) {
        final p = _playlists[i];
        final title = (p['title'] ?? p['name'] ?? 'Playlist').toString();
        final cover = buildMediaUrl((p['cover_url'] ?? '').toString());
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.gradPurple,
            ),
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white),
                  )
                : const Icon(Icons.queue_music_rounded, color: Colors.white),
          ),
          title: Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          subtitle: Text('${p['track_count'] ?? p['tracks_count'] ?? 0} tracks',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
          onTap: () => _openPlaylist(p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.74,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Text('Add track',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: GoogleFonts.outfit(color: AppColors.text),
                onChanged: (value) {
                  _debounce?.cancel();
                  if (_selected.isNotEmpty) {
                    setState(() => _selected.clear());
                  }
                  _debounce = Timer(const Duration(milliseconds: 120),
                      () => _runSearch(value));
                },
                decoration: InputDecoration(
                  hintText: 'Search tracks...',
                  hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.text3),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.text3,
                indicator: BoxDecoration(
                  gradient: AppColors.gradPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'Search'),
                  Tab(text: 'Liked'),
                  Tab(text: 'Recent'),
                  Tab(text: 'Playlists'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(children: [
                  _searching
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.purpleLight))
                      : _searchError
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppColors.text2, size: 36),
                                    const SizedBox(height: 12),
                                    const Text('Search failed',
                                        style: TextStyle(
                                            color: AppColors.text2,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                    if (_searchErrorDetail.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(_searchErrorDetail,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: AppColors.text2,
                                              fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : _trackList(
                              _search,
                              _searchCtrl.text.trim().length < 2
                                  ? 'Search for a song above'
                                  : 'No tracks found',
                            ),
                  _loadingLibrary
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.purpleLight))
                      : _trackList(_liked, 'No liked tracks yet'),
                  _loadingLibrary
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.purpleLight))
                      : _trackList(_recent, 'No recent tracks yet'),
                  _loadingLibrary
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.purpleLight))
                      : _playlistList(),
                ]),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => widget.onSelected(_selected.values.toList()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.canControl ? 'Add' : 'Suggest'} ${_selected.length} track${_selected.length == 1 ? '' : 's'}',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// DISCOVER / GLOBAL
// ══════════════════════════════════════════
class DiscoverScreen extends StatefulWidget {
  final int initialTab;

  const DiscoverScreen({super.key, this.initialTab = 0});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _tab = 0;
  final _tabs = ['🌍 Global', '🔥 Viral', '🆕 New Releases', '📈 Rising'];
  final _tabGenres = ['', 'viral', 'pop', 'indie'];

  List<dynamic> _tracks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTab(widget.initialTab.clamp(0, _tabs.length - 1));
  }

  Future<void> _loadTab(int tab) async {
    setState(() {
      _loading = true;
      _tab = tab;
    });
    try {
      final genre = _tabGenres[tab];
      final data = await ApiService().getCharts(genre: genre, limit: 20);
      if (!mounted) return;
      setState(() {
        _tracks = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discover',
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.02 * 26)),
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppColors.glass,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.tune_rounded,
                              size: 18, color: AppColors.text2)),
                    ]),
              ),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  itemCount: _tabs.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _loadTab(i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: _tab == i ? AppColors.gradPurple : null,
                        color: _tab == i ? null : AppColors.glass,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: _tab == i
                                ? AppColors.purple
                                : AppColors.border),
                      ),
                      child: Text(_tabs[i],
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  _tab == i ? Colors.white : AppColors.text2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Global card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF14062D).withOpacity(0.9),
                      const Color(0xFF08081C).withOpacity(0.9),
                    ]),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.purple.withOpacity(0.2)),
                  ),
                  child: Stack(children: [
                    Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  AppColors.purple.withOpacity(0.15),
                                  Colors.transparent
                                ])))),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🌍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text('Global Top 50',
                              style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.02 * 22)),
                          Text('Updated every 24 hours',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0x99C8B4FF))),
                          const SizedBox(height: 14),
                          Row(children: [
                            _GcStat('2.1B', 'plays today'),
                            const SizedBox(width: 20),
                            _GcStat('184', 'countries'),
                            const SizedBox(width: 20),
                            _GcStat('47M', 'listeners'),
                          ]),
                        ]),
                  ]),
                ),
              ),
              const SectionHeader(
                  title: 'Trending by Country', action: 'All →'),
              const SizedBox(height: 8),
              _CountryRow(
                  '🇺🇸', 'United States', "APT. — Rose ft. Bruno Mars", '1',
                  isGold: true),
              _CountryRow('🇰🇷', 'South Korea', 'How Sweet — NewJeans', '2',
                  isSilver: true),
              _CountryRow('🇰🇿', 'Kazakhstan',
                  'Sweater Weather — The Neighbourhood', '3',
                  isBronze: true),
              _CountryRow('🇬🇧', 'United Kingdom',
                  "Good Luck Babe! — Chappell Roan", '4'),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Viral This Week', action: 'More →'),
              const SizedBox(height: 12),
              _TrendBar(
                  "APT. · Rose ft. Bruno Mars",
                  "412M plays",
                  0.95,
                  const LinearGradient(
                      colors: [Color(0xFF7c3aed), AppColors.pink])),
              const SizedBox(height: 10),
              _TrendBar(
                  "Die With A Smile · Lady Gaga",
                  "389M",
                  0.82,
                  const LinearGradient(
                      colors: [Color(0xFF1e3a8a), AppColors.blue])),
              const SizedBox(height: 10),
              _TrendBar(
                  "Espresso · Sabrina Carpenter",
                  "340M",
                  0.74,
                  const LinearGradient(
                      colors: [Color(0xFF92400e), Color(0xFFf59e0b)])),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Top Tracks Now'),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purpleLight)),
                )
              else
                ..._tracks.asMap().entries.map((e) {
                  final i = e.key;
                  final track = Map<String, dynamic>.from(e.value as Map)
                    ..['queue'] = _tracks;
                  final title = track['title']?.toString() ?? 'Unknown';
                  final artist = track['artist']?.toString() ?? '';
                  final coverUrl = track['cover_url']?.toString();
                  final dur = _fmt(track['duration_ms']);
                  return GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlayerScreen(track: track))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      child: Row(children: [
                        SizedBox(
                            width: 22,
                            child: Text('${i + 1}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3))),
                        const SizedBox(width: 12),
                        Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                gradient: AppColors.gradMixed,
                                borderRadius: BorderRadius.circular(11)),
                            child: coverUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.network(coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                                child: Text('🎵',
                                                    style: TextStyle(
                                                        fontSize: 20)))))
                                : const Center(
                                    child: Text('🎵',
                                        style: TextStyle(fontSize: 20)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text)),
                              if (artist.isNotEmpty)
                                Text(artist,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text2)),
                            ])),
                        if (dur.isNotEmpty)
                          Text(dur,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3)),
                      ]),
                    ),
                  );
                }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GcStat extends StatelessWidget {
  final String value, label;
  const _GcStat(this.value, this.label);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xE6C8B4FF))),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, color: const Color(0x80C8B4FF))),
      ]);
}

class _CountryRow extends StatelessWidget {
  final String flag, country, track, pos;
  final bool isGold, isSilver, isBronze;
  const _CountryRow(this.flag, this.country, this.track, this.pos,
      {this.isGold = false, this.isSilver = false, this.isBronze = false});
  @override
  Widget build(BuildContext context) {
    Color posColor = isGold
        ? const Color(0xFFf59e0b)
        : isSilver
            ? const Color(0xFF94a3b8)
            : isBronze
                ? const Color(0xFFc2774a)
                : AppColors.text3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(country,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          Text(track,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2),
              overflow: TextOverflow.ellipsis),
        ])),
        Text(pos,
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w800, color: posColor)),
      ]),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final String label, plays;
  final double pct;
  final LinearGradient gradient;
  const _TrendBar(this.label, this.plays, this.pct, this.gradient);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                    overflow: TextOverflow.ellipsis)),
            Text(plays,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ]),
          const SizedBox(height: 6),
          Stack(children: [
            Container(
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(100))),
            FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(100)))),
          ]),
        ]),
      );
}

List<Map<String, dynamic>> _deriveCityArtists(List<dynamic> tracks) {
  final seen = <String>{};
  final artists = <Map<String, dynamic>>[];
  for (final raw in tracks.whereType<Map>()) {
    final track = Map<String, dynamic>.from(raw);
    final id = (track['artist_id'] ?? track['artistId'] ?? '').toString();
    final name = (track['artist'] ?? track['artistName'] ?? '').toString();
    final key = id.isNotEmpty ? id : name.toLowerCase();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    artists.add({
      'id': id,
      'name': name,
      'image': track['artist_picture'] ??
          track['cover_url'] ??
          track['artworkUrl100'],
    });
  }
  return artists.take(10).toList();
}

List<Map<String, dynamic>> _deriveCityAlbums(List<dynamic> tracks) {
  final seen = <String>{};
  final albums = <Map<String, dynamic>>[];
  for (final raw in tracks.whereType<Map>()) {
    final track = Map<String, dynamic>.from(raw);
    final id = (track['album_id'] ?? '').toString();
    final name = (track['album'] ?? track['collectionName'] ?? '').toString();
    final key = id.isNotEmpty ? id : name.toLowerCase();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    albums.add({
      'id': id,
      'title': name,
      'artist': track['artist'] ?? track['artistName'] ?? '',
      'cover': track['cover_url'] ?? track['artworkUrl100'],
    });
  }
  return albums.take(10).toList();
}

List<Map<String, dynamic>> _deriveCityPlaylists(
  String city,
  List<dynamic> tracks,
) {
  final chunks = [
    {
      'name': '$city Top Hits',
      'emoji': '🏙️',
      'tracks': tracks.take(20).toList()
    },
    {
      'name': '$city Fresh Picks',
      'emoji': '🌊',
      'tracks': tracks.skip(3).take(20).toList()
    },
    {
      'name': '$city Night Drive',
      'emoji': '🌙',
      'tracks': tracks.skip(6).take(20).toList()
    },
  ];
  return chunks.where((item) => (item['tracks'] as List).isNotEmpty).toList();
}

Widget _buildCityShelf(String title, List<Widget> children) {
  if (children.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(title,
          style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text)),
    ),
    SizedBox(
      height: 142,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        children: children,
      ),
    ),
  ]);
}

// ══════════════════════════════════════════
// CITY CHARTS
// ══════════════════════════════════════════
class CityChartsScreen extends StatefulWidget {
  const CityChartsScreen({super.key});
  @override
  State<CityChartsScreen> createState() => _CityChartsScreenState();
}

class _CityChartsScreenState extends State<CityChartsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  List<dynamic> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    try {
      final data = await ApiService().getChartsByCity(city);
      if (!mounted) return;
      setState(() {
        _tracks = data['tracks'] as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    final listeners = _tracks.length * 120 + 821;

    final rankColors = [
      const Color(0xFFf59e0b),
      const Color(0xFF94a3b8),
      const Color(0xFFc2774a),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border)),
                              child: const Icon(Icons.arrow_back_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                          Text('City Charts',
                              style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text)),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    // City hero
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF080A28), Color(0xFF0D0D1A)]),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.blue.withOpacity(0.2)),
                        ),
                        child: Stack(children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: RadialGradient(
                                    center: const Alignment(0.7, 0),
                                    colors: [
                                      AppColors.blue.withOpacity(0.1),
                                      Colors.transparent
                                    ]),
                              ),
                            ),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('📍',
                                      style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 10),
                                  Text(city,
                                      style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text)),
                                ]),
                                const SizedBox(height: 4),
                                AnimatedBuilder(
                                  animation: _blinkCtrl,
                                  builder: (_, __) => Row(children: [
                                    Opacity(
                                      opacity: 0.3 + 0.7 * _blinkCtrl.value,
                                      child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                              color: Color(0xFF22c55e),
                                              shape: BoxShape.circle)),
                                    ),
                                    const SizedBox(width: 5),
                                    Text('Updated live · just now',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF22c55e))),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                      colors: [
                                        AppColors.blueLight,
                                        AppColors.cyan
                                      ]).createShader(b),
                                  child: Text('$listeners',
                                      style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)),
                                ),
                                Text('people streaming right now in your city',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text2)),
                              ]),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight),
                ),
              )
            else if (_tracks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('📊', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('Charts are loading',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text('Play some tracks to see local charts',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.text3)),
                  ]),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCityShelf(
                      'Top artists in $city',
                      _deriveCityArtists(_tracks)
                          .map((artist) => _CityArtistCard(artist: artist))
                          .toList(),
                    ),
                    _buildCityShelf(
                      'Albums people replay',
                      _deriveCityAlbums(_tracks)
                          .map((album) => _CityAlbumCard(album: album))
                          .toList(),
                    ),
                    _buildCityShelf(
                      'City playlists',
                      _deriveCityPlaylists(city, _tracks)
                          .map((playlist) => _CityPlaylistCard(
                                playlist: playlist,
                              ))
                          .toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                      child: Text('Tracks',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                    ),
                  ],
                ),
              ),
            if (!_loading && _tracks.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final track = Map<String, dynamic>.from(_tracks[i] as Map)
                      ..['queue'] = _tracks;
                    final title = track['title']?.toString() ?? 'Unknown';
                    final artist = track['artist']?.toString() ?? '';
                    final coverUrl = track['cover_url']?.toString();
                    final dur = _fmt(track['duration_ms']);
                    final rankColor = i < 3 ? rankColors[i] : AppColors.text3;

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlayerScreen(track: track)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(children: [
                          SizedBox(
                            width: 24,
                            child: Text('${i + 1}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: rankColor)),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: coverUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.network(coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                                child: Text('🎵',
                                                    style: TextStyle(
                                                        fontSize: 20)))))
                                : const Center(
                                    child: Text('🎵',
                                        style: TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                  Text(artist,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.text2)),
                                ]),
                          ),
                          if (dur.isNotEmpty)
                            Text(dur,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.text3)),
                        ]),
                      ),
                    );
                  },
                  childCount: _tracks.length.clamp(0, 20),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _CityArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _CityArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['name']?.toString() ?? 'Artist';
    final id = artist['id']?.toString() ?? '';
    final image = artist['image']?.toString();
    return GestureDetector(
      onTap: id.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistScreen(artistId: id, artistName: name),
                ),
              ),
      child: Container(
        width: 104,
        margin: const EdgeInsets.only(right: 14),
        child: Column(children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradMixed,
            ),
            child: image != null && image.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Center(child: Icon(Icons.person_rounded)),
                    ),
                  )
                : const Center(child: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: 8),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
        ]),
      ),
    );
  }
}

class _CityAlbumCard extends StatelessWidget {
  final Map<String, dynamic> album;
  const _CityAlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final title = album['title']?.toString() ?? 'Album';
    final artist = album['artist']?.toString() ?? '';
    final cover = album['cover']?.toString();
    final rawId = album['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    return GestureDetector(
      onTap: id == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AlbumScreen(albumId: id)),
              ),
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 104,
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppColors.gradBlue,
            ),
            child: cover != null && cover.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Center(child: Icon(Icons.album_rounded)),
                    ),
                  )
                : const Center(child: Icon(Icons.album_rounded)),
          ),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          Text(artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ]),
      ),
    );
  }
}

class _CityPlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  const _CityPlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final tracks = (playlist['tracks'] as List?) ?? [];
    final name = playlist['name']?.toString() ?? 'City playlist';
    final emoji = playlist['emoji']?.toString() ?? '🎧';
    return GestureDetector(
      onTap: tracks.isEmpty
          ? null
          : () {
              final queue = tracks
                  .whereType<Map>()
                  .map((track) => Map<String, dynamic>.from(track))
                  .toList();
              if (queue.isEmpty) return;
              final first = Map<String, dynamic>.from(queue.first)
                ..['queue'] = queue;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
              );
            },
      child: Container(
        width: 138,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.gradPurple,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const Spacer(),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text('${tracks.length} tracks',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// RADIO
// ══════════════════════════════════════════
class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Radio',
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.02 * 26)),
                      Text('Create Station',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.purpleLight)),
                    ]),
              ),
              // Live now card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(children: [
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                        Color(0xFF1a0533),
                        Color(0xFF7c3aed),
                        Color(0xFF0d1a3d)
                      ])),
                      child: Stack(children: [
                        Container(color: Colors.black.withOpacity(0.1)),
                        const Center(
                            child: Text('📻', style: TextStyle(fontSize: 64))),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                              height: 40,
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(
                                      7,
                                      (i) => const AnimatedMusicBars(
                                          color1: AppColors.purpleLight,
                                          color2: AppColors.pink,
                                          barCount: 1,
                                          barWidth: 4,
                                          maxHeight: 28)))),
                        ),
                      ]),
                    ),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                        color: AppColors.pink,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text('ON AIR',
                                    style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.pink,
                                        letterSpacing: 0.12)),
                              ]),
                              const SizedBox(height: 4),
                              Text('MoodWave Indie Radio',
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                      letterSpacing: -0.01 * 18)),
                              Text('Sweater Weather — The Neighbourhood',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13, color: AppColors.text2)),
                              Text('🎧 1,284 listeners now',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11, color: AppColors.text3)),
                            ])),
                        Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.pink.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.pink.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  color: AppColors.pink, size: 18)),
                          const SizedBox(width: 8),
                          Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradPurple,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          AppColors.purpleDark.withOpacity(0.4),
                                      blurRadius: 14)
                                ],
                              ),
                              child: const Icon(Icons.pause_rounded,
                                  color: Colors.white, size: 22)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SectionHeader(title: 'Featured Stations', action: 'All →'),
              const SizedBox(height: 12),
              _RadioCard(
                  '🎸',
                  'Indie Night Radio',
                  'Indie · Alt Rock',
                  '847',
                  const LinearGradient(
                      colors: [Color(0xFF1a0533), Color(0xFF7c3aed)])),
              _RadioCard(
                  '❄️',
                  'Winter Chill Radio',
                  'Ambient · Lo-fi · Snow vibes',
                  '2,134',
                  const LinearGradient(
                      colors: [Color(0xFF164e63), Color(0xFF06b6d4)])),
              _RadioCard(
                  '✨',
                  'K-Pop Hits Radio',
                  'K-Pop · Korean Pop · BTS, NewJeans',
                  '5,412',
                  const LinearGradient(
                      colors: [Color(0xFF9d174d), Color(0xFFec4899)])),
              _RadioCard(
                  '🎤',
                  'Hip-Hop Central',
                  'Hip-Hop · Trap · R&B',
                  '3,891',
                  const LinearGradient(
                      colors: [Color(0xFF1c1917), Color(0xFF57534e)])),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  final String emoji, name, genre, listeners;
  final LinearGradient gradient;
  const _RadioCard(
      this.emoji, this.name, this.genre, this.listeners, this.gradient);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 100,
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(children: [
            Container(color: Colors.black.withOpacity(0.2)),
            Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
            Positioned(
                bottom: 12,
                left: 16,
                right: 60,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(genre,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6))),
                    ])),
            Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(children: [
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22c55e), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(listeners,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.8))),
                  ]),
                )),
            Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20))),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// RECENT HISTORY
// ══════════════════════════════════════════
class RecentHistoryScreen extends StatefulWidget {
  const RecentHistoryScreen({super.key});

  @override
  State<RecentHistoryScreen> createState() => _RecentHistoryScreenState();
}

class _RecentHistoryScreenState extends State<RecentHistoryScreen> {
  List<dynamic> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService().getListeningHistory();
    if (!mounted) return;
    setState(() {
      _sections = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(children: [
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
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Listening History',
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.5),
                ),
              ]),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.purpleLight),
              ),
            )
          else if (_sections.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 48, color: AppColors.text3),
                    const SizedBox(height: 12),
                    Text('No listening history yet',
                        style: GoogleFonts.outfit(
                            fontSize: 15, color: AppColors.text3)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.purpleLight,
                backgroundColor: AppColors.surface,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _sections.length,
                  itemBuilder: (context, i) {
                    final section = _sections[i] as Map<String, dynamic>;
                    final label = section['date'] as String? ?? '';
                    final tracks = (section['tracks'] as List?) ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Text(
                            label,
                            style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text),
                          ),
                        ),
                        ..._buildHistoryEntries(
                          tracks
                              .whereType<Map>()
                              .map((t) => Map<String, dynamic>.from(t))
                              .toList(),
                        ).map((entry) {
                          final kind = (entry['_kind'] ?? 'track').toString();
                          if (kind == 'album_summary') {
                            return _HistoryAlbumSummary(entry: entry);
                          }
                          return _HistoryTrackRow(track: entry);
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTrackRow extends StatelessWidget {
  final Map<String, dynamic> track;
  const _HistoryTrackRow({required this.track});

  Future<void> _openArtist(BuildContext context) async {
    final artistName = track['artist']?.toString() ?? '';
    final directId = track['artist_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ArtistScreen(artistId: directId, artistName: artistName)));
      return;
    }
    try {
      final result = await ApiService().searchArtist(artistName);
      final a = result['artist'] as Map<String, dynamic>?;
      if (!context.mounted || a == null) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ArtistScreen(
                    artistId: a['id'].toString(),
                    artistName: a['name']?.toString() ?? artistName,
                  )));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = track['cover_url'] as String?;
    final title = track['title'] as String? ?? 'Unknown';
    final artist = track['artist'] as String? ?? '';
    final album = track['album'] as String? ?? '';
    final playCount = (track['play_count'] as num?)?.toInt() ?? 1;
    final subtitle = <String>[
      if (artist.isNotEmpty) artist,
      if (album.isNotEmpty) 'Album · $album',
      if (playCount > 1) 'Played $playCount times',
    ].join(' · ');
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl != null && coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(),
                    errorWidget: (_, __, ___) => _coverFallback(),
                  )
                : _coverFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(artist,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty && subtitle != artist) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showTrackMenu(
              context,
              track,
              onPlayNow: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: track))),
              onGoToArtist:
                  artist.isNotEmpty ? () => _openArtist(context) : null,
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.text3),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _coverFallback() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note_rounded,
            color: Colors.white54, size: 20),
      );
}

class _HistoryAlbumSummary extends StatefulWidget {
  final Map<String, dynamic> entry;
  const _HistoryAlbumSummary({required this.entry});

  @override
  State<_HistoryAlbumSummary> createState() => _HistoryAlbumSummaryState();
}

class _HistoryAlbumSummaryState extends State<_HistoryAlbumSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final title = (entry['album'] ?? 'Album').toString();
    final artist = (entry['artist'] ?? '').toString();
    final coverUrl = (entry['cover_url'] ?? '').toString();
    final trackCount = (entry['track_count'] as num?)?.toInt() ?? 0;
    final playCount = (entry['play_count'] as num?)?.toInt() ?? trackCount;
    final tracks = (entry['tracks'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    final subtitle = [
      'Played ${trackCount > 0 ? trackCount : playCount} track${(trackCount > 1 || playCount > 1) ? 's' : ''}',
      'Album',
      if (artist.isNotEmpty) artist,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.purpleDark.withOpacity(0.24),
            AppColors.pink.withOpacity(0.10),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.24)),
        ),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget: (_, __, ___) =>
                                _historyCoverFallback(56),
                          )
                        : _historyCoverFallback(56),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
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
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 24, color: AppColors.text2),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0x14FFFFFF)),
                ...tracks.map((track) => _HistoryExpandedTrack(track: track)),
                const SizedBox(height: 6),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ]),
      ),
    );
  }
}

class _HistoryExpandedTrack extends StatelessWidget {
  final Map<String, dynamic> track;
  const _HistoryExpandedTrack({required this.track});

  @override
  Widget build(BuildContext context) {
    final title =
        (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
    final artist = (track['artist'] ?? track['artistName'] ?? '').toString();
    final coverUrl =
        (track['cover_url'] ?? track['artworkUrl100'] ?? '').toString();
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _historyCoverFallback(44),
                  )
                : _historyCoverFallback(44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 2),
              Text(artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          const Icon(Icons.play_arrow_rounded,
              size: 18, color: AppColors.purpleLight),
        ]),
      ),
    );
  }
}

Widget _historyCoverFallback(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.gradMixed,
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
      child: const Icon(Icons.album_rounded, color: Colors.white54, size: 22),
    );

List<Map<String, dynamic>> _buildHistoryEntries(
  List<Map<String, dynamic>> tracks,
) {
  final normalized =
      tracks.map((item) => Map<String, dynamic>.from(item)).toList()
        ..sort((a, b) => (b['played_at']?.toString() ?? '').compareTo(
              a['played_at']?.toString() ?? '',
            ));

  final albumGroups = <String, List<Map<String, dynamic>>>{};
  for (final track in normalized) {
    final album = (track['album'] ?? '').toString().trim();
    final artist = (track['artist'] ?? '').toString().trim();
    if (album.isEmpty) continue;
    final key = '${album.toLowerCase()}|${artist.toLowerCase()}';
    albumGroups.putIfAbsent(key, () => []).add(track);
  }

  final duplicateCounts = <String, int>{};
  for (final track in normalized) {
    final key = _historyTrackKey(track);
    duplicateCounts[key] = (duplicateCounts[key] ?? 0) + 1;
  }

  final emittedAlbums = <String>{};
  final emittedTracks = <String>{};
  final entries = <Map<String, dynamic>>[];

  for (final track in normalized) {
    final album = (track['album'] ?? '').toString().trim();
    final artist = (track['artist'] ?? '').toString().trim();
    final albumKey =
        album.isEmpty ? '' : '${album.toLowerCase()}|${artist.toLowerCase()}';
    final albumItems = albumKey.isEmpty
        ? const <Map<String, dynamic>>[]
        : (albumGroups[albumKey] ?? const <Map<String, dynamic>>[]);

    final uniqueTracks =
        albumItems.map((item) => _historyTrackKey(item)).toSet().length;

    if (uniqueTracks >= 2 && !emittedAlbums.contains(albumKey)) {
      emittedAlbums.add(albumKey);
      for (final item in albumItems) {
        emittedTracks.add(_historyTrackKey(item));
      }
      final uniqueAlbumTracks = <String, Map<String, dynamic>>{};
      for (final item in albumItems) {
        uniqueAlbumTracks.putIfAbsent(
          _historyTrackKey(item),
          () => Map<String, dynamic>.from(item),
        );
      }
      entries.add({
        '_kind': 'album_summary',
        'album': album,
        'artist': artist,
        'cover_url': track['cover_url'],
        'track_count': uniqueTracks,
        'play_count': albumItems.length,
        'tracks': uniqueAlbumTracks.values.toList(),
      });
      continue;
    }

    final trackKey = _historyTrackKey(track);
    if (emittedTracks.contains(trackKey)) {
      continue;
    }
    emittedTracks.add(trackKey);
    final item = Map<String, dynamic>.from(track);
    item['play_count'] = duplicateCounts[trackKey] ?? 1;
    entries.add(item);
  }

  return entries;
}

String _historyTrackKey(Map<String, dynamic> track) {
  return [
    (track['spotify_id'] ?? '').toString(),
    (track['title'] ?? '').toString().trim().toLowerCase(),
    (track['artist'] ?? '').toString().trim().toLowerCase(),
    (track['album'] ?? '').toString().trim().toLowerCase(),
  ].join('|');
}

// ══════════════════════════════════════════
// BROWSE ROOMS
// ══════════════════════════════════════════
class BrowseRoomsScreen extends StatefulWidget {
  const BrowseRoomsScreen({super.key});
  @override
  State<BrowseRoomsScreen> createState() => _BrowseRoomsScreenState();
}

class _BrowseRoomsScreenState extends State<BrowseRoomsScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroIfNeeded());
  }

  Future<void> _createRoom() async {
    final room = await showListeningRoomCreateSheet(
      context,
      initialName: 'Live Room',
      initialPublic: true,
    );
    if (room == null || !mounted) return;
    await _load();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListeningPartyScreen(room: room)),
    );
  }

  Future<void> _showIntroIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('party_rooms_intro_seen_v1') == true || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Party rooms',
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.text)),
        content: Text(
          'Public Live Rooms are live music parties. Join a room, listen in sync with the host, chat with people, suggest tracks, and follow the queue together.',
          style: GoogleFonts.outfit(
              fontSize: 14, height: 1.45, color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800, color: AppColors.purpleLight)),
          ),
        ],
      ),
    );
    await prefs.setBool('party_rooms_intro_seen_v1', true);
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoomHistoryScreen()),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getActiveRooms();
      if (!mounted) return;
      setState(() {
        _rooms = data;
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Live Rooms',
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      Text('Join a live session',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3)),
                    ])),
                Row(children: [
                  GestureDetector(
                    onTap: _createRoom,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          gradient: AppColors.gradPurple,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openHistory,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.history_rounded,
                          size: 18, color: AppColors.text2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.text2),
                    ),
                  ),
                ]),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purpleLight))
                  : _rooms.isEmpty
                      ? Align(
                          alignment: const Alignment(0, -0.18),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🎧', style: TextStyle(fontSize: 52)),
                            const SizedBox(height: 14),
                            Text('No active rooms',
                                style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            const SizedBox(height: 6),
                            Text('Tap + to create a room or check back later',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: AppColors.text3),
                                textAlign: TextAlign.center),
                          ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.purpleLight,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _rooms.length,
                            itemBuilder: (_, i) {
                              final room =
                                  Map<String, dynamic>.from(_rooms[i] as Map);
                              final name =
                                  (room['name'] ?? 'Live Room').toString();
                              final host = (room['host'] as Map?)
                                      ?.cast<String, dynamic>() ??
                                  {};
                              final hostName = (host['first_name'] ??
                                      host['username'] ??
                                      'Host')
                                  .toString();
                              final count = room['participant_count'] ?? 0;
                              final description =
                                  (room['description'] ?? '').toString();
                              final background = buildMediaUrl(
                                  (room['background_url'] ?? '').toString());
                              final track = (room['current_track'] as Map?)
                                  ?.cast<String, dynamic>();
                              final trackTitle =
                                  track?['track_title']?.toString() ?? '';
                              final trackCoverUrl = buildMediaUrl(
                                  track?['track_cover_url']?.toString() ??
                                      track?['cover_url']?.toString() ??
                                      track?['track_cover']?.toString() ??
                                      '');
                              final cardBg = background.isNotEmpty
                                  ? background
                                  : trackCoverUrl;
                              final tileCover = trackCoverUrl.isNotEmpty
                                  ? trackCoverUrl
                                  : cardBg;
                              final isPublic = room['is_public'] == true;
                              final state =
                                  (room['state'] ?? 'live').toString();
                              final badge = state == 'draft'
                                  ? 'WAITING'
                                  : state == 'paused'
                                      ? 'PAUSED'
                                      : 'LIVE';
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  try {
                                    final details = await ApiService()
                                        .getRoomDetails(
                                            (room['room_id'] as num).toInt());
                                    if (!context.mounted) return;
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                ListeningPartyScreen(
                                                    room: details)));
                                  } catch (_) {
                                    await _load();
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  height: 154,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Stack(children: [
                                    if (cardBg.isNotEmpty)
                                      Positioned.fill(
                                        child: CachedNetworkImage(
                                          imageUrl: cardBg,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.black.withOpacity(0.88),
                                              Colors.black.withOpacity(0.42),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 14, 16, 14),
                                      child: Row(children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            color: AppColors.surface2,
                                          ),
                                          child: tileCover.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: tileCover,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      const Center(
                                                          child: Text('🎉',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      22))),
                                                )
                                              : const Center(
                                                  child: Text('🎉',
                                                      style: TextStyle(
                                                          fontSize: 22))),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(children: [
                                                Expanded(
                                                  child: Text(name,
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: badge == 'LIVE'
                                                        ? const Color(
                                                                0xFFef4444)
                                                            .withOpacity(0.9)
                                                        : Colors.white
                                                            .withOpacity(0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(badge,
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Colors.white,
                                                          letterSpacing: 0.8)),
                                                ),
                                              ]),
                                              const SizedBox(height: 3),
                                              Text(
                                                  '$hostName · $count listening',
                                                  style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: Colors.white70)),
                                              if (description.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(description,
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        color: Colors.white60),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ],
                                              if (trackTitle.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(children: [
                                                  const Icon(
                                                      Icons.music_note_rounded,
                                                      size: 11,
                                                      color: Color(0xFFa78bfa)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(trackTitle,
                                                        style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: const Color(
                                                                0xFFa78bfa)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                  ),
                                                ]),
                                              ],
                                              const SizedBox(height: 5),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                    isPublic
                                                        ? 'Public room'
                                                        : 'Private room',
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white70)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: Colors.white54, size: 20),
                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomHistoryScreen extends StatefulWidget {
  const RoomHistoryScreen({super.key});

  @override
  State<RoomHistoryScreen> createState() => _RoomHistoryScreenState();
}

class _RoomHistoryScreenState extends State<RoomHistoryScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  void _snack(String text, {bool error = false}) {
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rooms = await ApiService().getRoomHistory(limit: 40);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  Future<void> _openRoom(Map<String, dynamic> room) async {
    final roomId = (room['room_id'] as num?)?.toInt();
    if (roomId == null) return;
    try {
      final details = await ApiService().getRoomDetails(roomId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ListeningPartyScreen(room: details)),
      );
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open room', error: true);
    }
  }

  Future<void> _deleteRoom(int roomId) async {
    try {
      await ApiService().deleteRoom(roomId);
      await _load();
    } catch (_) {
      if (!mounted) return;
      _snack('Could not delete room', error: true);
    }
  }

  String _historyTimeLabel(Map<String, dynamic> room) {
    final raw = (room['closed_at'] ?? room['created_at'] ?? '').toString();
    if (raw.isEmpty) return 'Previous room';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month · $hour:$minute';
    } catch (_) {
      return 'Previous room';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Room History',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Created and managed Live Rooms',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.purpleLight,
                      ),
                    )
                  : _rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🕰', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 14),
                              Text(
                                'No room history yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ended rooms will appear here.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.text2,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.purpleLight,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _rooms.length,
                            itemBuilder: (_, index) {
                              final room = Map<String, dynamic>.from(
                                  _rooms[index] as Map);
                              final roomId =
                                  (room['room_id'] as num?)?.toInt() ?? 0;
                              final host = (room['host'] as Map?)
                                      ?.cast<String, dynamic>() ??
                                  const {};
                              final name =
                                  (room['name'] ?? 'Live Room').toString();
                              final hostName = (host['first_name'] ??
                                      host['username'] ??
                                      'Host')
                                  .toString();
                              final description =
                                  (room['description'] ?? '').toString();
                              final track = (room['current_track'] as Map?)
                                  ?.cast<String, dynamic>();
                              final trackTitle =
                                  (track?['track_title'] ?? '').toString();
                              final background = buildMediaUrl(
                                (room['background_url'] ?? '').toString(),
                              );
                              final trackCover = buildMediaUrl(
                                (track?['track_cover_url'] ?? '').toString(),
                              );
                              final cardBg = background.isNotEmpty
                                  ? background
                                  : trackCover;
                              final tileCover =
                                  trackCover.isNotEmpty ? trackCover : cardBg;
                              return GestureDetector(
                                onTap: () => _openRoom(room),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          color: AppColors.surface2,
                                        ),
                                        child: tileCover.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: tileCover,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _historyCoverFallback(64),
                                              )
                                            : _historyCoverFallback(64),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.text,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Hosted by $hostName',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: AppColors.text2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              trackTitle.isNotEmpty
                                                  ? trackTitle
                                                  : description.isNotEmpty
                                                      ? description
                                                      : 'Tap to reopen this room',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: trackTitle.isNotEmpty
                                                    ? AppColors.purpleLight
                                                    : AppColors.text3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _historyTimeLabel(room),
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: AppColors.text3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        color: AppColors.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'delete' && roomId > 0) {
                                            _deleteRoom(roomId);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text(
                                              'Delete',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFf87171),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            color: AppColors.text3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
