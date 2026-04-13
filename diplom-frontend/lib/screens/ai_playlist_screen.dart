import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'player_screen.dart';

class AIPlaylistScreen extends StatefulWidget {
  const AIPlaylistScreen({super.key});
  @override
  State<AIPlaylistScreen> createState() => _AIPlaylistScreenState();
}

class _AIPlaylistScreenState extends State<AIPlaylistScreen> {
  final _ctrl = TextEditingController();
  List<dynamic> _tracks = [];
  bool _loading = false;
  bool _saving = false;
  bool _generated = false;

  static const _chips = [
    ('🌨 Snowy evening', 'Songs for a cold winter evening, calm and atmospheric'),
    ('🏃 Morning run', 'Energetic songs for a morning run, upbeat and motivating'),
    ('☕ Sunday coffee', 'Chill morning coffee vibes, relaxed and cozy'),
    ('🌙 Late night drive', 'Late night city drive, moody and cinematic'),
    ('😢 Healing playlist', 'Emotional healing songs, melancholic but beautiful'),
  ];

  String _moodFromPrompt(String prompt) {
    final p = prompt.toLowerCase();
    if (p.contains('snow') || p.contains('winter') || p.contains('cold') ||
        p.contains('calm') || p.contains('sleep') || p.contains('ambient') ||
        p.contains('atmospheric') || p.contains('evening')) return 'calm';
    if (p.contains('run') || p.contains('gym') || p.contains('workout') ||
        p.contains('energy') || p.contains('pump') || p.contains('motivat')) return 'workout';
    if (p.contains('morning') || p.contains('coffee') || p.contains('sunday') ||
        p.contains('chill') || p.contains('cozy') || p.contains('relax')) return 'morning';
    if (p.contains('late night') || p.contains('night drive') ||
        p.contains('midnight') || p.contains('cinematic')) return 'late_night';
    if (p.contains('sad') || p.contains('heal') || p.contains('emotional') ||
        p.contains('cry') || p.contains('melanchol')) return 'sad';
    if (p.contains('party') || p.contains('dance') || p.contains('club')) return 'party';
    if (p.contains('drive') || p.contains('road trip') || p.contains('driving')) return 'driving';
    if (p.contains('romantic') || p.contains('love') || p.contains('date')) return 'romantic';
    if (p.contains('study') || p.contains('focus') || p.contains('concentrate') ||
        p.contains('work')) return 'study';
    if (p.contains('happy') || p.contains('upbeat') || p.contains('positive')) return 'happy';
    return '';
  }

  String _moodLabel(String mood) {
    const labels = {
      'calm': '🌙 Calm',
      'workout': '🏃 Energetic',
      'morning': '☕ Chill',
      'late_night': '🌙 Late Night',
      'sad': '😢 Melancholic',
      'party': '🎉 Party',
      'driving': '🚗 Driving',
      'romantic': '❤️ Romantic',
      'study': '📚 Focus',
      'happy': '😊 Happy',
    };
    return labels[mood] ?? '🎵 Mixed';
  }

  Future<void> _generate() async {
    final prompt = _ctrl.text.trim();
    if (prompt.isEmpty) return;
    setState(() => _loading = true);
    try {
      final mood = _moodFromPrompt(prompt);
      final data = await ApiService().getRecommendations(
        mood: mood.isEmpty ? null : mood,
      );
      if (!mounted) return;
      setState(() {
        _tracks = data;
        _loading = false;
        _generated = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _savePlaylist() async {
    if (_tracks.isEmpty) return;
    final nameCtrl = TextEditingController(
      text: _ctrl.text.trim().isNotEmpty ? _ctrl.text.trim() : 'AI Playlist',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save Playlist',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: nameCtrl,
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
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final playlist = await ApiService().createPlaylist(nameCtrl.text.trim());
      final playlistId = playlist['id'] as int;
      for (final t in _tracks) {
        try {
          final track = Map<String, dynamic>.from(t as Map);
          await ApiService().addTrackToPlaylist(playlistId, {
            'spotify_track_id': track['spotify_id'] ??
                track['deezer_id'] ??
                track['id']?.toString() ??
                '',
            'title': track['title'] ?? 'Unknown',
            'artist': track['artist'] ?? '',
            'cover_url': track['cover_url'],
            'preview_url': track['preview_url'],
            'duration_ms': track['duration_ms'],
          });
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Playlist saved!', style: GoogleFonts.outfit()),
        backgroundColor: AppColors.purple,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save playlist', style: GoogleFonts.outfit()),
        backgroundColor: Colors.red,
      ));
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  void _playAll() {
    final queue = _tracks
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    if (queue.isEmpty) return;
    final first = Map<String, dynamic>.from(queue.first)..['queue'] = queue;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlayerScreen(track: first)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _ctrl.text.trim();
    final mood = _moodFromPrompt(prompt);
    final moodLabel = _moodLabel(mood);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'AI Playlist',
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              letterSpacing: -0.02 * 26),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.purpleDark.withOpacity(0.15),
                              AppColors.pink.withOpacity(0.1),
                            ]),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.3)),
                          ),
                          child: Text('✦ AI Powered',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purpleLight,
                                  letterSpacing: 0.04)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Describe a vibe, place, or feeling',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text2)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Suggestion chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  children: _chips
                      .map((c) => GestureDetector(
                            onTap: () {
                              setState(() => _ctrl.text = c.$2);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.glass,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(c.$1,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.text2)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Prompt area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF14062D).withOpacity(0.8),
                      const Color(0xFF08081C).withOpacity(0.8),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.purple.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✦ YOUR PROMPT',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purpleLight,
                              letterSpacing: 0.1)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: TextField(
                          controller: _ctrl,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: AppColors.text,
                              height: 1.55),
                          maxLines: 4,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                'Songs for a cold winter night drive, something melancholic but beautiful...',
                            hintStyle: GoogleFonts.outfit(
                                fontSize: 15,
                                color: AppColors.text3,
                                height: 1.55),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: [
                          _AiParam(label: 'LENGTH', value: '🎵 20 songs'),
                          _AiParam(label: 'MOOD', value: moodLabel),
                          _AiParam(label: 'ERA', value: '2010 – 2024'),
                          _AiParam(label: 'LANGUAGE', value: '🌍 Any'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _loading ? null : _generate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: prompt.isEmpty ? null : AppColors.primaryBtn,
                            color: prompt.isEmpty ? AppColors.glass : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: prompt.isEmpty
                                ? []
                                : [
                                    BoxShadow(
                                        color: AppColors.purpleDark
                                            .withOpacity(0.4),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10))
                                  ],
                          ),
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome_rounded,
                                        color: prompt.isEmpty
                                            ? AppColors.text3
                                            : Colors.white,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text('Generate Playlist',
                                        style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: prompt.isEmpty
                                                ? AppColors.text3
                                                : Colors.white)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_generated && _tracks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('✦ GENERATED FOR YOU',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text3,
                          letterSpacing: 0.06)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.purpleDark.withOpacity(0.15),
                              AppColors.pink.withOpacity(0.1),
                            ]),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20)),
                            border: const Border(
                                bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(children: [
                            // First track cover or fallback
                            _trackCover(_tracks.first as Map),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('AI: ${prompt.length > 28 ? '${prompt.substring(0, 28)}…' : prompt}',
                                        style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.text)),
                                    Text(
                                        'AI · ${_tracks.length} songs',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text2)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 6, children: [
                                      _Tag(moodLabel.replaceAll(RegExp(r'[^\w ]'), '').trim(), AppColors.purple),
                                    ]),
                                  ]),
                            ),
                          ]),
                        ),
                        // First 3 tracks preview
                        ..._tracks.take(3).map((t) {
                          final track = t as Map;
                          return _AiTrackMini(
                            track: track,
                            onTap: () {
                              final queue = _tracks
                                  .whereType<Map>()
                                  .map((x) => Map<String, dynamic>.from(x))
                                  .toList();
                              final idx = _tracks.indexOf(t);
                              final first = Map<String, dynamic>.from(
                                  queue[idx])..['queue'] = queue;
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PlayerScreen(track: first)));
                            },
                          );
                        }),
                        if (_tracks.length > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            child: Text(
                                '+ ${_tracks.length - 3} more tracks',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3)),
                          ),
                        // Buttons
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(
                                      color: Color(0x0AFFFFFF)))),
                          child: Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _saving ? null : _savePlaylist,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      gradient: AppColors.gradPurple,
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: _saving
                                      ? const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white),
                                          ),
                                        )
                                      : Text('Save Playlist',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: _loading ? null : _generate,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: AppColors.glass,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.border)),
                                  child: Text('Regenerate',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _playAll,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradMixed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackCover(Map track) {
    final url = track['cover_url']?.toString();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
          gradient: AppColors.gradMixed,
          borderRadius: BorderRadius.circular(14)),
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) =>
                    const Center(child: Text('🎵', style: TextStyle(fontSize: 26))),
              ))
          : const Center(child: Text('🎵', style: TextStyle(fontSize: 26))),
    );
  }
}

class _AiTrackMini extends StatelessWidget {
  final Map track;
  final VoidCallback onTap;
  const _AiTrackMini({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final url = track['cover_url']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(10)),
            child: url != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) =>
                          const Center(child: Text('🎵', style: TextStyle(fontSize: 18))),
                    ))
                : const Center(child: Text('🎵', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                      overflow: TextOverflow.ellipsis),
                  if (artist.isNotEmpty)
                    Text(artist,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.text2)),
                ]),
          ),
          const Icon(Icons.play_circle_outline_rounded,
              size: 20, color: AppColors.text3),
        ]),
      ),
    );
  }
}

class _AiParam extends StatelessWidget {
  final String label, value;
  const _AiParam({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
                letterSpacing: 0.08)),
        const SizedBox(height: 5),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.purpleLight)),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.9))),
    );
  }
}
