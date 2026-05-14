import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
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
      setState(() { _playlists = data; _loading = false; });
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
        'spotify_track_id': track['spotify_id'] ?? track['deezer_id'] ?? track['track_id'] ?? '',
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
          content: Text('Added to playlist', style: GoogleFonts.outfit(fontSize: 13)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1a1a2e),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Already in playlist or error', style: GoogleFonts.outfit(fontSize: 13)),
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.purple)),
            filled: true, fillColor: AppColors.glass,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Create',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
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
        widget.track?['trackName']?.toString() ?? 'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ?? '';
    final coverUrl = widget.track?['cover_url']?.toString() ??
        widget.track?['artworkUrl100']?.toString();
    final duration = _fmt(widget.track?['duration_ms'] ?? widget.track?['trackTimeMillis']);
    final subtitle = [artist, if (duration.isNotEmpty) duration]
        .where((s) => s.isNotEmpty).join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface3, borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Add to Playlist', style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          ),
          // Track preview row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(13)),
                child: coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(coverUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Text('🎵', style: TextStyle(fontSize: 24)))))
                    : const Center(child: Text('🎵', style: TextStyle(fontSize: 24)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trackTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
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
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.purpleDark.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.purpleLight, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Playlist', style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                  Text('Create a new playlist',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                ]),
              ]),
            ),
          ),
          // Real playlists
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight),
            )
          else if (_playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No playlists yet',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3)),
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
                    onTap: isAdded || isLoading ? null : () => _addToPlaylist(plId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x08FFFFFF)))),
                      child: Row(children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                              gradient: AppColors.gradPurple,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('🎵', style: TextStyle(fontSize: 20)))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(plTitle, style: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                          Text('$trackCount songs', style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3)),
                        ])),
                        if (isLoading)
                          const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight))
                        else if (isAdded)
                          Container(width: 24, height: 24,
                            decoration: BoxDecoration(
                                gradient: AppColors.gradPurple, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12))
                        else
                          Container(width: 24, height: 24,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border2, width: 1.5))),
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
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.gradPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 20)],
                ),
                child: Text('Done', textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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
  const _ShareTrackSheet({this.track});
  @override
  State<_ShareTrackSheet> createState() => _ShareTrackSheetState();
}

class _ShareTrackSheetState extends State<_ShareTrackSheet> {
  List<dynamic> _matches = [];
  bool _loadingMatches = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final data = await ApiService().getMyMatches();
      if (!mounted) return;
      setState(() { _matches = data.take(5).toList(); _loadingMatches = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMatches = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontSize: 13)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _copyLink() async {
    final title = widget.track?['title']?.toString() ??
        widget.track?['trackName']?.toString() ?? 'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ?? '';
    final text = artist.isNotEmpty ? '$title by $artist · MoodWave' : '$title · MoodWave';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Copied to clipboard');
  }

  Future<void> _systemShare() async {
    final title = widget.track?['title']?.toString() ??
        widget.track?['trackName']?.toString() ??
        'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ??
        '';
    final text =
        artist.isNotEmpty ? 'Listen to $title by $artist on MoodWave' : 'Listen to $title on MoodWave';
    await Share.share(text, subject: 'MoodWave track');
  }

  Future<void> _sendToMatch(int matchId, String name) async {
    final title = widget.track?['title']?.toString() ??
        widget.track?['trackName']?.toString() ?? 'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ?? '';
    final msg = artist.isNotEmpty
        ? '🎵 Check out: $title by $artist'
        : '🎵 Check out: $title';
    try {
      await ApiService().sendTextMessage(matchId, msg);
      if (!mounted) return;
      _snack('Sent to $name!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _snack('Could not send. Try again.');
    }
  }

  void _showMatchPicker() {
    if (_loadingMatches) { _snack('Loading matches…'); return; }
    if (_matches.isEmpty) { _snack('No matches yet. Match with someone first!'); return; }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(100)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Send to…', style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            ..._matches.map((m) {
              final match = m as Map<String, dynamic>;
              final matchId = match['match_id'] as int? ?? match['id'] as int? ?? 0;
              final partner = match['partner'] as Map? ?? {};
              final name = (partner['display_name'] ?? partner['first_name'] ?? partner['username'] ?? 'User').toString();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _sendToMatch(matchId, name);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(gradient: AppColors.gradMixed, shape: BoxShape.circle),
                      child: Center(child: Text(initial,
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(name, style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text))),
                    const Icon(Icons.send_rounded, color: AppColors.purpleLight, size: 18),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.track?['title']?.toString() ??
        widget.track?['trackName']?.toString() ?? 'Unknown';
    final artist = widget.track?['artist']?.toString() ??
        widget.track?['artistName']?.toString() ?? '';
    final coverUrl = widget.track?['cover_url']?.toString() ??
        widget.track?['artworkUrl100']?.toString();

    final matchNames = _matches.take(3).map((m) {
      final partner = (m as Map)['partner'] as Map? ?? {};
      return (partner['display_name'] ?? partner['first_name'] ?? 'User').toString();
    }).join(', ');
    final matchSub = _loadingMatches
        ? 'Loading…'
        : _matches.isEmpty
            ? 'No matches yet'
            : matchNames + (_matches.length > 3 ? ' and more' : '');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Share Track', style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          ),
          // Preview card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border2),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(width: 68, height: 68,
                  decoration: BoxDecoration(gradient: AppColors.gradMixed,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)]),
                  child: coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(coverUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('🎵', style: TextStyle(fontSize: 32)))))
                      : const Center(child: Text('🎵', style: TextStyle(fontSize: 32)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.01 * 18)),
                  if (artist.isNotEmpty) Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                      fontSize: 14, color: const Color(0xB3C8B4FF))),
                  const SizedBox(height: 10),
                  Container(height: 3, decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                    child: FractionallySizedBox(widthFactor: 0.38, alignment: Alignment.centerLeft,
                      child: Container(decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                        borderRadius: BorderRadius.circular(100))))),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.graphic_eq_rounded, size: 10, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('MoodWave', style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white54)),
                  ]),
                ])),
              ]),
            ),
          ),
          // Apps
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text('SHARE TO', style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ShareApp('↗', 'System', const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                  onTap: _systemShare),
              _ShareApp('💌', 'In Chat', null, onTap: _showMatchPicker),
              _ShareApp('📋', 'Copy', const LinearGradient(colors: [Color(0xFF334155), Color(0xFF64748b)]),
                  onTap: _copyLink),
            ]),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: _copyLink,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.copy_rounded, size: 16, color: AppColors.text),
                    const SizedBox(width: 8),
                    Text('Copy Link', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ])))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => _snack('Story sharing coming soon'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.35), blurRadius: 16)]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Share to Story', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])))),
            ]),
          ),
          // Send to match
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: GestureDetector(
              onTap: _showMatchPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.purple.withOpacity(0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.purpleLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Send to Match', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                    Text(matchSub, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                ]),
              ),
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

  Widget menuItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, size: 22, color: color ?? AppColors.text3),
      title: Text(label, style: GoogleFonts.outfit(fontSize: 15, color: color ?? AppColors.text)),
      onTap: onTap,
      dense: true,
    );
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          // Track preview
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(10)),
                child: coverUrl != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: Image.network(coverUrl.toString(), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Text('🎵', style: TextStyle(fontSize: 22)))))
                    : const Center(child: Text('🎵', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(artist.toString(),
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
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
            final trackId = track['spotify_id'] ?? track['deezer_id'] ?? track['track_id'] ?? '';
            if (trackId.toString().isNotEmpty) {
              ApiService().skipTrack(trackId.toString()).catchError((_) {});
            }
          }),
          if (playlistId != null && onRemoveFromPlaylist != null)
            menuItem(Icons.remove_circle_outline_rounded, 'Remove from playlist', () {
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
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ArtistScreen(artistId: directId, artistName: artist.toString()),
                ));
              }
              return;
            }
            if (artist.toString().isEmpty) return;
            try {
              final result = await ApiService().searchArtist(artist.toString());
              final a = result['artist'] as Map<String, dynamic>?;
              if (a == null || !context.mounted) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ArtistScreen(artistId: a['id'].toString(), artistName: a['name']?.toString() ?? artist.toString()),
              ));
            } catch (_) {
              if (context.mounted) snack('Artist not found');
            }
          }),
          menuItem(Icons.album_rounded, 'Go to album', () {
            Navigator.pop(ctx);
            final albumId = track['album_id'];
            if (albumId != null) {
              final id = albumId is int ? albumId : int.tryParse(albumId.toString());
              if (id != null && context.mounted) {
                Navigator.push(context, MaterialPageRoute(
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

class _ShareApp extends StatelessWidget {
  final String emoji, name;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  const _ShareApp(this.emoji, this.name, this.gradient, {this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? AppColors.surface2 : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))),
        const SizedBox(height: 7),
        Text(name, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2)),
      ]),
    );
  }
}
