import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'artist_screen.dart';
import 'player_screen.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  Map<String, dynamic> _room = {};
  bool _loading = true;
  bool _joining = false;
  bool _joinRequested = false;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _room = Map<String, dynamic>.from(widget.room);
    _loadRoom();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoom() async {
    final roomId = _room['room_id'] as int?;
    if (roomId == null) { setState(() => _loading = false); return; }
    try {
      final details = await ApiService().getRoomDetails(roomId);
      if (mounted) setState(() { _room = details; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendJoinRequest() async {
    final roomId = _room['room_id'] as int?;
    if (roomId == null) return;
    setState(() => _joining = true);
    try {
      await ApiService().sendJoinRequest(roomId);
      if (!mounted) return;
      setState(() { _joining = false; _joinRequested = true; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Join request sent! Waiting for host approval.',
              style: GoogleFonts.outfit(fontSize: 13)),
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      final msg = e.toString().contains('Already in room')
          ? 'You already have a pending or active request.'
          : 'Could not send join request. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit(fontSize: 13)),
          backgroundColor: const Color(0xFFef4444),
        ),
      );
    }
  }

  String _fmtMs(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '0:00';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (_room['name'] ?? 'Live Room').toString();
    final host = (_room['host'] as Map?)?.cast<String, dynamic>() ?? {};
    final hostName = (host['first_name'] ?? host['username'] ?? 'Host').toString();
    final hostAvatar = host['avatar_url']?.toString();
    final participantCount = _room['participant_count'] ?? 0;
    final track = (_room['current_track'] as Map?)?.cast<String, dynamic>();
    final trackTitle = track?['track_title']?.toString() ?? '';
    final trackArtist = track?['track_artist']?.toString() ?? '';
    final trackCover = track?['track_cover_url']?.toString();
    final positionMs = (track?['position_ms'] as num?)?.toInt() ?? 0;
    final isPlaying = track?['is_playing'] == true;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                    color: AppColors.glass,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border)),
                                child: const Icon(Icons.arrow_back_rounded,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _blinkCtrl,
                                        builder: (_, __) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
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
                                                  width: 7, height: 7,
                                                  decoration: const BoxDecoration(
                                                      color: Color(0xFFef4444),
                                                      shape: BoxShape.circle)),
                                            ),
                                            const SizedBox(width: 6),
                                            Text('LIVE PARTY',
                                                style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFFf87171))),
                                          ]),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.text,
                                              letterSpacing: -0.4)),
                                      Text('Hosted by $hostName',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12, color: AppColors.text2)),
                                    ]),
                              ),
                            ),
                            GestureDetector(
                              onTap: _loadRoom,
                              child: Container(
                                width: 40, height: 40,
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
                  ),

                  // ── Cover / visualiser ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                          gradient: AppColors.gradMixed,
                          borderRadius: BorderRadius.circular(24)),
                      child: Stack(children: [
                        if (trackCover != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CachedNetworkImage(
                              imageUrl: trackCover,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.black.withOpacity(0.35),
                              colorBlendMode: BlendMode.darken,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24)),
                          ),
                        if (isPlaying)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: SizedBox(
                              height: 40,
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
                                        maxHeight: 30)),
                              ),
                            ),
                          ),
                        if (!isPlaying && trackTitle.isEmpty)
                          Center(
                            child: Text('🎙',
                                style: const TextStyle(fontSize: 64)),
                          ),
                      ]),
                    ),
                  ),

                  // ── Now playing ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            borderRadius: BorderRadius.circular(13)),
                        child: trackCover != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: CachedNetworkImage(
                                    imageUrl: trackCover,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 24)))))
                            : const Center(
                                child: Text('🎵',
                                    style: TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  trackTitle.isNotEmpty
                                      ? trackTitle
                                      : 'No track playing',
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              if (trackArtist.isNotEmpty)
                                Text(trackArtist,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text2)),
                              if (positionMs > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(100)),
                                ),
                                const SizedBox(height: 4),
                                Text(_fmtMs(positionMs),
                                    style: GoogleFonts.outfit(
                                        fontSize: 11, color: AppColors.text3)),
                              ],
                            ]),
                      ),
                      if (isPlaying)
                        const Icon(Icons.graphic_eq_rounded,
                            color: AppColors.purpleLight, size: 22),
                    ]),
                  ),

                  // ── Participants ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'LISTENING TOGETHER · $participantCount ${participantCount == 1 ? 'PERSON' : 'PEOPLE'}',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text2,
                                    letterSpacing: 0.04)),
                            const SizedBox(height: 12),
                            Row(children: [
                              // Host avatar
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.bg, width: 2)),
                                child: hostAvatar != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                            imageUrl: hostAvatar,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Center(
                                                child: Text(
                                                    hostName[0].toUpperCase(),
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white)))))
                                    : Center(
                                        child: Text(hostName[0].toUpperCase(),
                                            style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white))),
                              ),
                              if (participantCount > 1) ...[
                                const SizedBox(width: 6),
                                Text(
                                    '+${participantCount - 1} listener${participantCount - 1 == 1 ? '' : 's'}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text2)),
                              ],
                            ]),
                            const SizedBox(height: 8),
                            Text('All listening in sync 🎵',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text)),
                          ]),
                    ),
                  ),

                  // ── Join button ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: GestureDetector(
                      onTap: (_joining || _joinRequested) ? null : _sendJoinRequest,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: (_joinRequested || _joining)
                              ? null
                              : AppColors.gradPurple,
                          color: (_joinRequested || _joining)
                              ? AppColors.surface
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: (_joinRequested || _joining)
                              ? Border.all(color: AppColors.border)
                              : null,
                          boxShadow: (_joinRequested || _joining)
                              ? null
                              : [
                                  BoxShadow(
                                      color: AppColors.purpleDark.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4))
                                ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_joining)
                                const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.purpleLight))
                              else
                                Icon(
                                    _joinRequested
                                        ? Icons.hourglass_empty_rounded
                                        : Icons.headphones_rounded,
                                    size: 18,
                                    color: _joinRequested
                                        ? AppColors.text2
                                        : Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                  _joinRequested
                                      ? 'Request sent — waiting for host'
                                      : _joining
                                          ? 'Sending request…'
                                          : 'Request to Join',
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _joinRequested
                                          ? AppColors.text2
                                          : Colors.white)),
                            ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════
// DISCOVER / GLOBAL
// ══════════════════════════════════════════
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
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
    _loadTab(0);
  }

  Future<void> _loadTab(int tab) async {
    setState(() { _loading = true; _tab = tab; });
    try {
      final genre = _tabGenres[tab];
      final data = await ApiService().getCharts(genre: genre, limit: 20);
      if (!mounted) return;
      setState(() { _tracks = data; _loading = false; });
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
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Discover', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.glass,
                        borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.text2)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: _tab == i ? AppColors.gradPurple : null,
                        color: _tab == i ? null : AppColors.glass,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: _tab == i ? AppColors.purple : AppColors.border),
                      ),
                      child: Text(_tabs[i], style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _tab == i ? Colors.white : AppColors.text2)),
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
                    border: Border.all(color: AppColors.purple.withOpacity(0.2)),
                  ),
                  child: Stack(children: [
                    Positioned(top: -30, right: -30,
                      child: Container(width: 140, height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppColors.purple.withOpacity(0.15), Colors.transparent])))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🌍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('Global Top 50', style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.02 * 22)),
                      Text('Updated every 24 hours', style: GoogleFonts.outfit(
                          fontSize: 13, color: const Color(0x99C8B4FF))),
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
              const SectionHeader(title: 'Trending by Country', action: 'All →'),
              const SizedBox(height: 8),
              _CountryRow('🇺🇸', 'United States', "APT. — Rose ft. Bruno Mars", '1', isGold: true),
              _CountryRow('🇰🇷', 'South Korea', 'How Sweet — NewJeans', '2', isSilver: true),
              _CountryRow('🇰🇿', 'Kazakhstan', 'Sweater Weather — The Neighbourhood', '3', isBronze: true),
              _CountryRow('🇬🇧', 'United Kingdom', "Good Luck Babe! — Chappell Roan", '4'),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Viral This Week', action: 'More →'),
              const SizedBox(height: 12),
              _TrendBar("APT. · Rose ft. Bruno Mars", "412M plays", 0.95,
                  const LinearGradient(colors: [Color(0xFF7c3aed), AppColors.pink])),
              const SizedBox(height: 10),
              _TrendBar("Die With A Smile · Lady Gaga", "389M", 0.82,
                  const LinearGradient(colors: [Color(0xFF1e3a8a), AppColors.blue])),
              const SizedBox(height: 10),
              _TrendBar("Espresso · Sabrina Carpenter", "340M", 0.74,
                  const LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)])),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Top Tracks Now'),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(
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
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      child: Row(children: [
                        SizedBox(width: 22,
                          child: Text('${i + 1}', textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 13,
                                  fontWeight: FontWeight.w600, color: AppColors.text3))),
                        const SizedBox(width: 12),
                        Container(width: 46, height: 46,
                          decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              borderRadius: BorderRadius.circular(11)),
                          child: coverUrl != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(11),
                                  child: Image.network(coverUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(child: Text('🎵', style: TextStyle(fontSize: 20)))))
                              : const Center(child: Text('🎵', style: TextStyle(fontSize: 20)))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                          if (artist.isNotEmpty)
                            Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
                        ])),
                        if (dur.isNotEmpty)
                          Text(dur, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700,
        color: const Color(0xE6C8B4FF))),
    Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0x80C8B4FF))),
  ]);
}

class _CountryRow extends StatelessWidget {
  final String flag, country, track, pos;
  final bool isGold, isSilver, isBronze;
  const _CountryRow(this.flag, this.country, this.track, this.pos,
      {this.isGold = false, this.isSilver = false, this.isBronze = false});
  @override
  Widget build(BuildContext context) {
    Color posColor = isGold ? const Color(0xFFf59e0b)
        : isSilver ? const Color(0xFF94a3b8)
        : isBronze ? const Color(0xFFc2774a) : AppColors.text3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
          child: Center(child: Text(flag, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(country, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text(track, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2),
              overflow: TextOverflow.ellipsis),
        ])),
        Text(pos, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: posColor)),
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
        Expanded(child: Text(label, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis)),
        Text(plays, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 4, decoration: BoxDecoration(
            color: AppColors.surface3, borderRadius: BorderRadius.circular(100))),
        FractionallySizedBox(widthFactor: pct, child: Container(height: 4,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(100)))),
      ]),
    ]),
  );
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
        _tracks = data;
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
                              width: 40, height: 40,
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
                                      opacity:
                                          0.3 + 0.7 * _blinkCtrl.value,
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
                                            color:
                                                const Color(0xFF22c55e))),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      const LinearGradient(colors: [
                                    AppColors.blueLight,
                                    AppColors.cyan
                                  ]).createShader(b),
                                  child: Text('$listeners',
                                      style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)),
                                ),
                                Text(
                                    'people streaming right now in your city',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.text2)),
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
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final track =
                        Map<String, dynamic>.from(_tracks[i] as Map)
                          ..['queue'] = _tracks;
                    final title =
                        track['title']?.toString() ?? 'Unknown';
                    final artist = track['artist']?.toString() ?? '';
                    final coverUrl = track['cover_url']?.toString();
                    final dur = _fmt(track['duration_ms']);
                    final rankColor = i < 3
                        ? rankColors[i]
                        : AppColors.text3;

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
                            width: 46, height: 46,
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
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Radio', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  Text('Create Station', style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
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
                        gradient: LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)])),
                      child: Stack(children: [
                        Container(color: Colors.black.withOpacity(0.1)),
                        const Center(child: Text('📻', style: TextStyle(fontSize: 64))),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: SizedBox(height: 40,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) => const AnimatedMusicBars(
                                color1: AppColors.purpleLight, color2: AppColors.pink,
                                barCount: 1, barWidth: 4, maxHeight: 28)))),
                        ),
                      ]),
                    ),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 7, height: 7,
                              decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('ON AIR', style: GoogleFonts.outfit(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.pink, letterSpacing: 0.12)),
                          ]),
                          const SizedBox(height: 4),
                          Text('MoodWave Indie Radio', style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.01 * 18)),
                          Text('Sweater Weather — The Neighbourhood',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                          Text('🎧 1,284 listeners now',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                        ])),
                        Row(children: [
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.pink.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppColors.pink, size: 18)),
                          const SizedBox(width: 8),
                          Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 14)],
                            ),
                            child: const Icon(Icons.pause_rounded, color: Colors.white, size: 22)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SectionHeader(title: 'Featured Stations', action: 'All →'),
              const SizedBox(height: 12),
              _RadioCard('🎸', 'Indie Night Radio', 'Indie · Alt Rock', '847',
                  const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed)])),
              _RadioCard('❄️', 'Winter Chill Radio', 'Ambient · Lo-fi · Snow vibes', '2,134',
                  const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)])),
              _RadioCard('✨', 'K-Pop Hits Radio', 'K-Pop · Korean Pop · BTS, NewJeans', '5,412',
                  const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)])),
              _RadioCard('🎤', 'Hip-Hop Central', 'Hip-Hop · Trap · R&B', '3,891',
                  const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)])),
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
  const _RadioCard(this.emoji, this.name, this.genre, this.listeners, this.gradient);
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
            Positioned(bottom: 12, left: 16, right: 60, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(genre, style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.white.withOpacity(0.6))),
              ])),
            Positioned(top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(children: [
                  Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: Color(0xFF22c55e), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(listeners, style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.8))),
                ]),
              )),
            Positioned(bottom: 12, right: 12,
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20))),
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
                        ...tracks.map((t) =>
                            _HistoryTrackRow(track: t as Map<String, dynamic>)),
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
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showTrackMenu(
              context,
              track,
              onPlayNow: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: track))),
              onGoToArtist: artist.isNotEmpty
                  ? () => _openArtist(context)
                  : null,
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
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getActiveRooms();
      if (!mounted) return;
      setState(() { _rooms = data; _loading = false; });
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
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Listening Rooms', style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Text('Join a live session', style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.text3)),
                ])),
                GestureDetector(
                  onTap: _load,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.text2),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight))
                  : _rooms.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🎧', style: TextStyle(fontSize: 52)),
                          const SizedBox(height: 14),
                          Text('No active rooms', style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 6),
                          Text('Check back later or create one from the Home tab',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
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
                              final room = Map<String, dynamic>.from(_rooms[i] as Map);
                              final name = (room['name'] ?? 'Live Room').toString();
                              final host = (room['host'] as Map?)?.cast<String, dynamic>() ?? {};
                              final hostName = (host['first_name'] ?? host['username'] ?? 'Host').toString();
                              final count = room['participant_count'] ?? 0;
                              final track = (room['current_track'] as Map?)?.cast<String, dynamic>();
                              final trackTitle = track?['track_title']?.toString() ?? '';
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ListeningPartyScreen(room: room))),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFef4444).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFef4444).withOpacity(0.25)),
                                      ),
                                      child: const Center(child: Text('🎉', style: TextStyle(fontSize: 22))),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: GoogleFonts.outfit(
                                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('Host: $hostName · $count listening',
                                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                                      if (trackTitle.isNotEmpty)
                                        Text('Now: $trackTitle',
                                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.purpleLight),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ])),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppColors.text3, size: 20),
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
