import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';
import '../widgets/common_widgets.dart';
import 'create_playlist_screen.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final int? playlistId;
  final String? playlistTitle;

  const PlaylistScreen({super.key, this.playlistId, this.playlistTitle});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Map<String, dynamic>? _playlist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.playlistId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await ApiService().getPlaylist(widget.playlistId!);
      if (!mounted) return;
      setState(() {
        _playlist = data;
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

  String _totalDuration(List tracks) {
    int total = 0;
    for (final t in tracks) {
      final ms = (t as Map)['duration_ms'];
      total += ms is int ? ms : int.tryParse('$ms') ?? 0;
    }
    if (total == 0) return '';
    final h = total ~/ 3600000;
    final m = (total % 3600000) ~/ 60000;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _playAll(List tracks) {
    if (tracks.isEmpty) return;
    var queue = tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    if (context.read<PlayerProvider>().shuffleOn) {
      final rng = Random();
      for (int i = queue.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = queue[i];
        queue[i] = queue[j];
        queue[j] = tmp;
      }
    }
    final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: first)),
    );
  }

  void _shufflePlay(List tracks) {
    if (tracks.isEmpty) return;
    final queue = tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    // Fisher-Yates shuffle
    final rng = Random();
    for (int i = queue.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = queue[i];
      queue[i] = queue[j];
      queue[j] = tmp;
    }
    final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Shuffle on', style: GoogleFonts.outfit(fontSize: 13)),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1)),
    );
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
  }

  Future<void> _renamePlaylist() async {
    if (widget.playlistId == null) return;
    final current = _playlist?['title']?.toString() ?? '';
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Playlist',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            filled: true,
            fillColor: AppColors.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      await ApiService()
          .updatePlaylist(widget.playlistId!, title: ctrl.text.trim());
      if (mounted) {
        showSuccessSnackBar(context, 'Renamed to "${ctrl.text.trim()}"');
        _load();
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not rename playlist');
    }
  }

  Future<void> _deletePlaylistAndPop() async {
    if (widget.playlistId == null) return;
    final title = _playlist?['title']?.toString() ?? 'this playlist';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Playlist?',
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: Text('This will permanently delete "$title".',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFef4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deletePlaylist(widget.playlistId!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not delete playlist');
    }
  }

  void _showPlaylistMenu() {
    final title = _playlist?['title']?.toString() ?? 'Playlist';

    Widget item(IconData icon, String label, VoidCallback onTap,
        {Color? color}) {
      final c = color ?? Colors.white;
      return ListTile(
        leading: Icon(icon, color: color ?? Colors.white70, size: 22),
        title: Text(label, style: GoogleFonts.outfit(fontSize: 15, color: c)),
        onTap: onTap,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            item(Icons.play_arrow_rounded, 'Play now', () {
              Navigator.pop(ctx);
              final trackList = (_playlist?['tracks'] as List?) ?? [];
              _playAll(trackList);
            }),
            item(Icons.shuffle_rounded, 'Shuffle and play', () {
              Navigator.pop(ctx);
              final trackList = (_playlist?['tracks'] as List?) ?? [];
              _shufflePlay(trackList);
            }),
            item(Icons.add_rounded, 'Add tracks', () {
              Navigator.pop(ctx);
              _addTracksDialog();
            }),
            item(Icons.edit_rounded, 'Edit playlist', () {
              Navigator.pop(ctx);
              if (_playlist == null) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreatePlaylistScreen(existingPlaylist: _playlist),
                  )).then((_) => _load());
            }),
            item(Icons.share_outlined, 'Share', () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(
                  text: 'Check out my playlist: $title on MoodWave'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 2),
              ));
            }),
            item(Icons.delete_outline_rounded, 'Delete', () {
              Navigator.pop(ctx);
              _deletePlaylistAndPop();
            }, color: const Color(0xFFef4444)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editDescriptionDialog() async {
    if (widget.playlistId == null) return;
    final current = _playlist?['description']?.toString() ?? '';
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Description',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 300,
          style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Describe your playlist...',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            filled: true,
            fillColor: AppColors.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService()
          .updatePlaylist(widget.playlistId!, description: ctrl.text.trim());
      if (mounted) {
        showSuccessSnackBar(context, 'Description updated');
        _load();
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not update description');
    }
  }

  Future<void> _addTracksDialog() async {
    if (widget.playlistId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddTracksSheet(
        playlistId: widget.playlistId!,
        onAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = (_playlist?['tracks'] as List?) ?? [];
    final title =
        _playlist?['title']?.toString() ?? widget.playlistTitle ?? 'Playlist';
    final coverUrl = _playlist?['cover_url']?.toString();
    final isCollab = _playlist?['is_collaborative'] == true;
    final trackCount = _playlist?['track_count'] ?? tracks.length;
    final totalDur = _totalDuration(tracks);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC280A50), Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top nav
                            Row(
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
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(Icons.arrow_back_rounded,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                                Text(title,
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text)),
                                const SizedBox(width: 40),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Cover + meta
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1a0533),
                                        Color(0xFF7c3aed),
                                        Color(0xFF0d1a3d)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20)),
                                    ],
                                  ),
                                  child: coverUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const SizedBox(),
                                            errorWidget: (_, __, ___) =>
                                                const Center(
                                                    child: Text('🎵',
                                                        style: TextStyle(
                                                            fontSize: 52))),
                                          ))
                                      : const Center(
                                          child: Text('🎵',
                                              style: TextStyle(fontSize: 52))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('Playlist',
                                            style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.purpleLight,
                                                letterSpacing: 0.1)),
                                        if (isCollab) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.purple
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                  color: AppColors.purple
                                                      .withOpacity(0.25)),
                                            ),
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.people_alt_rounded,
                                                  size: 10,
                                                  color: AppColors.purpleLight),
                                              const SizedBox(width: 4),
                                              Text('Collab',
                                                  style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors
                                                          .purpleLight)),
                                            ]),
                                          ),
                                        ],
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(title,
                                          style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.text,
                                              height: 1.2)),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          '$trackCount songs',
                                          if (totalDur.isNotEmpty) totalDur,
                                        ].join(' · '),
                                        style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: AppColors.text2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Controls
                            Row(children: [
                              Consumer<PlayerProvider>(
                                builder: (_, provider, __) => GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    provider.toggleShuffle();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: provider.shuffleOn
                                          ? AppColors.purpleLight
                                              .withOpacity(0.2)
                                          : AppColors.glass,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: provider.shuffleOn
                                            ? AppColors.purpleLight
                                            : AppColors.border,
                                        width: provider.shuffleOn ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Icon(Icons.shuffle_rounded,
                                        size: 22,
                                        color: provider.shuffleOn
                                            ? AppColors.purpleLight
                                            : AppColors.text3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: tracks.isEmpty
                                      ? null
                                      : () => _playAll(tracks),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: tracks.isEmpty
                                          ? null
                                          : AppColors.gradPurple,
                                      color: tracks.isEmpty
                                          ? AppColors.glass
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: tracks.isEmpty
                                          ? []
                                          : [
                                              BoxShadow(
                                                  color: AppColors.purpleDark
                                                      .withOpacity(0.35),
                                                  blurRadius: 20)
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow_rounded,
                                            color: tracks.isEmpty
                                                ? AppColors.text3
                                                : Colors.white,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text('Play All',
                                            style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: tracks.isEmpty
                                                    ? AppColors.text3
                                                    : Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _showPlaylistMenu,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.glass,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(Icons.more_horiz_rounded,
                                      size: 22, color: AppColors.text2),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (tracks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🎵', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No tracks yet',
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text)),
                        const SizedBox(height: 6),
                        Text('Add songs from search or player',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                      ]),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final track =
                            Map<String, dynamic>.from(tracks[i] as Map)
                              ..['queue'] = tracks;
                        final trackTitle =
                            track['title']?.toString() ?? 'Unknown';
                        final artist = track['artist']?.toString() ?? '';
                        final coverUrl = track['cover_url']?.toString();
                        final duration = _fmt(track['duration_ms']);

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(track: track)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0x0AFFFFFF))),
                            ),
                            child: Row(children: [
                              SizedBox(
                                width: 20,
                                child: Text('${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text3)),
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
                                        child: CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              const SizedBox(),
                                          errorWidget: (_, __, ___) =>
                                              const Center(
                                                  child: Text(
                                                      '🎵',
                                                      style: TextStyle(
                                                          fontSize: 20))),
                                        ))
                                    : const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 20))),
                              ),
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
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    if (artist.isNotEmpty)
                                      Text(artist,
                                          style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: AppColors.text2)),
                                  ],
                                ),
                              ),
                              if (duration.isNotEmpty)
                                Text(duration,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AppColors.text3)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => showTrackMenu(
                                  context,
                                  track,
                                  onPlayNow: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PlayerScreen(track: track)),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.more_vert_rounded,
                                      size: 18, color: AppColors.text3),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }
}

class _AddTracksSheet extends StatefulWidget {
  final int playlistId;
  final VoidCallback onAdded;
  const _AddTracksSheet({required this.playlistId, required this.onAdded});

  @override
  State<_AddTracksSheet> createState() => _AddTracksSheetState();
}

class _AddTracksSheetState extends State<_AddTracksSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  final Set<String> _addedIds = {};
  final Set<String> _loadingIds = {};

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final raw = await ApiService().searchTracks(q.trim());
      if (!mounted) return;
      setState(() {
        _results = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Map<String, dynamic> track) async {
    final id = track['spotify_id']?.toString() ??
        track['deezer_id']?.toString() ??
        track['track_id']?.toString() ??
        track['id']?.toString() ??
        '';
    if (id.isEmpty || _addedIds.contains(id) || _loadingIds.contains(id)) {
      return;
    }
    setState(() => _loadingIds.add(id));
    try {
      await ApiService().addTrackToPlaylist(widget.playlistId, track);
      if (!mounted) return;
      setState(() => _addedIds.add(id));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Track added successfully'),
          duration: Duration(seconds: 1)));

      widget.onAdded();
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Could not add track: ${errorMsg.contains('Exception') ? 'Error' : errorMsg}')));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text('Add Tracks',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: AppColors.text),
              onChanged: (v) => _search(v),
              decoration: InputDecoration(
                hintText: 'Search for a track...',
                hintStyle: GoogleFonts.outfit(color: AppColors.text3),
                filled: true,
                fillColor: AppColors.surface3,
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.text3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.purpleLight),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final t = _results[i];
                  final id = t['spotify_id']?.toString() ??
                      t['deezer_id']?.toString() ??
                      t['track_id']?.toString() ??
                      t['id']?.toString() ??
                      '';
                  final added = _addedIds.contains(id);
                  final loading = _loadingIds.contains(id);
                  final cover = t['cover_url']?.toString();
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradMixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: cover != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox()))
                          : const Icon(Icons.music_note_rounded,
                              color: Colors.white70, size: 20),
                    ),
                    title: Text(t['title']?.toString() ?? 'Unknown',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(t['artist']?.toString() ?? '',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.text3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (added || loading) ? null : () => _add(t),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient:
                              (added || loading) ? null : AppColors.gradPurple,
                          color: (added || loading) ? AppColors.surface3 : null,
                          shape: BoxShape.circle,
                        ),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                added ? Icons.check_rounded : Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}
