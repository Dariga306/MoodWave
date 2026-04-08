import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../artist_screen.dart';
import '../player_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<dynamic> _recent = [];
  List<dynamic> _tracks = [];
  List<dynamic> _artists = [];
  bool _searching = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final data = await ApiService().getRecentlyPlayed(limit: 10);
      if (!mounted) return;
      setState(() => _recent = data);
    } catch (_) {}
  }

  Future<void> _removeRecent(int index) async {
    setState(() => _recent.removeAt(index));
  }

  void _clearRecent() => setState(() => _recent = []);

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _hasQuery = false;
        _tracks = [];
        _artists = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _hasQuery = true;
      _searching = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(q.trim()),
    );
  }

  bool _hasCyrillic(String s) => s.runes.any((r) => r >= 0x0400 && r <= 0x04FF);

  String _transliterate(String input) {
    const map = {
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'yo',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'kh',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sch',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
    };
    return input.toLowerCase().split('').map((c) => map[c] ?? c).join('');
  }

  Future<void> _search(String q) async {
    final isCyrillic = _hasCyrillic(q);
    final transliterated = isCyrillic ? _transliterate(q) : q;

    try {
      final results = await Future.wait([
        ApiService()
            .searchTracks(transliterated, limit: 10)
            .catchError((_) => <dynamic>[]),
        ApiService()
            .searchArtist(transliterated)
            .catchError((_) => <String, dynamic>{'artist': null}),
        if (isCyrillic)
          ApiService()
              .searchTracks(q, limit: 10)
              .catchError((_) => <dynamic>[]),
        if (isCyrillic)
          ApiService()
              .searchArtist(q)
              .catchError((_) => <String, dynamic>{'artist': null}),
      ]);
      if (!mounted) return;

      List<dynamic> tracks = (results[0] as List?) ?? [];
      if (isCyrillic) {
        final altTracks = (results[2] as List?) ?? [];
        final seen = <String>{};
        final merged = <dynamic>[];
        for (final item in [...tracks, ...altTracks]) {
          final track = item as Map;
          final id = track['spotify_id']?.toString() ??
              track['id']?.toString() ??
              track['title']?.toString() ??
              '';
          if (seen.add(id)) {
            merged.add(item);
          }
        }
        tracks = merged.take(10).toList();
      }

      final artistCandidates = <Map<String, dynamic>>[];
      final primaryArtist = (results[1] as Map<String, dynamic>)['artist']
          as Map<String, dynamic>?;
      if (primaryArtist != null) {
        artistCandidates.add(primaryArtist);
      }
      if (isCyrillic) {
        final secondaryArtist = (results[3] as Map<String, dynamic>)['artist']
            as Map<String, dynamic>?;
        if (secondaryArtist != null) {
          artistCandidates.add(secondaryArtist);
        }
      }

      final seenArtists = <String>{};
      final artists = artistCandidates.where((artist) {
        final id = artist['id']?.toString() ?? artist['name']?.toString() ?? '';
        return id.isNotEmpty && seenArtists.add(id);
      }).toList();

      setState(() {
        _tracks = tracks;
        _artists = artists;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _openArtist(Map<String, dynamic> artist) {
    final artistId = artist['id']?.toString();
    final artistName = artist['name']?.toString() ?? 'Unknown';
    if (artistId == null || artistId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId: artistId,
          artistName: artistName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        onTap: () => _focus.unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.02 * 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_hasCyrillic(_ctrl.text) && _ctrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Searching as: ${_transliterate(_ctrl.text)}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.text3,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.text3,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                onChanged: _onChanged,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  color: AppColors.text,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Artists, songs, playlists...',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 15,
                                    color: AppColors.text3,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_hasQuery)
                              GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  setState(() {
                                    _hasQuery = false;
                                    _tracks = [];
                                    _artists = [];
                                    _searching = false;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  ),
                )
              else if (_hasQuery) ...[
                if (_artists.isNotEmpty) ...[
                  const SectionHeader(title: 'Artists'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _artists.length,
                      itemBuilder: (_, index) => _ArtistCard(
                        artist: _artists[index] as Map<String, dynamic>,
                        onTap: () => _openArtist(
                          _artists[index] as Map<String, dynamic>,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_tracks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Tracks'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _tracks
                          .map(
                            (track) => _TrackResult(
                              track: track as Map<String, dynamic>,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                if (_tracks.isEmpty && _artists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No results found',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            'Try a different search',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                if (_recent.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recently Played',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        GestureDetector(
                          onTap: _clearRecent,
                          child: Text('Clear all',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: AppColors.text3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _recent.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value as Map;
                        final title = item['title']?.toString() ?? '';
                        final artist = item['artist']?.toString() ?? '';
                        final coverUrl = item['cover_url']?.toString();
                        final track = Map<String, dynamic>.from(item);
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(track: track)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color(0x0AFFFFFF)))),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    borderRadius: BorderRadius.circular(10)),
                                child: coverUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              const SizedBox(),
                                          errorWidget: (_, __, ___) =>
                                              const Center(
                                                  child: Text('🎵')),
                                        ),
                                      )
                                    : const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text)),
                                    Text(artist,
                                        style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: AppColors.text3)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeRecent(i),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.close_rounded,
                                      size: 16, color: AppColors.text3),
                                ),
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const SectionHeader(title: 'Browse Genres'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _GenreCard(
                        emoji: '🎤',
                        name: 'Pop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7c3aed), Color(0xFFa855f7)],
                        ),
                        onTap: () {
                          _ctrl.text = 'Pop';
                          _onChanged('Pop');
                        },
                      ),
                      _GenreCard(
                        emoji: '🎸',
                        name: 'Rock',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
                        ),
                        onTap: () {
                          _ctrl.text = 'Rock';
                          _onChanged('Rock');
                        },
                      ),
                      _GenreCard(
                        emoji: '✨',
                        name: 'K-Pop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9d174d), Color(0xFFec4899)],
                        ),
                        onTap: () {
                          _ctrl.text = 'K-Pop';
                          _onChanged('K-Pop');
                        },
                      ),
                      _GenreCard(
                        emoji: '🎤',
                        name: 'Hip-Hop',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1c1917), Color(0xFF57534e)],
                        ),
                        onTap: () {
                          _ctrl.text = 'Hip-Hop';
                          _onChanged('Hip-Hop');
                        },
                      ),
                      _GenreCard(
                        emoji: '🎹',
                        name: 'Electronic',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF164e63), Color(0xFF06b6d4)],
                        ),
                        onTap: () {
                          _ctrl.text = 'Electronic';
                          _onChanged('Electronic');
                        },
                      ),
                      _GenreCard(
                        emoji: '🌙',
                        name: 'Ambient',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3b0764), Color(0xFF7c3aed)],
                        ),
                        onTap: () {
                          _ctrl.text = 'Ambient';
                          _onChanged('Ambient');
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackResult extends StatelessWidget {
  final Map<String, dynamic> track;
  const _TrackResult({required this.track});

  String _formatDuration(dynamic durationMs) {
    final value =
        durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  Future<void> _openArtist(BuildContext context) async {
    final artistName = track['artist'] ?? track['artistName'] ?? '';
    final directId = track['artist_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            artistId: directId,
            artistName: artistName,
          ),
        ),
      );
      return;
    }

    try {
      final result = await ApiService().searchArtist(artistName.toString());
      final artist = result['artist'] as Map<String, dynamic>?;
      if (!context.mounted || artist == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            artistId: artist['id'].toString(),
            artistName: artist['name']?.toString() ?? artistName.toString(),
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];
    final duration = _formatDuration(
      track['duration_ms'] ?? track['trackTimeMillis'] ?? 0,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                          child: Text('🎵'),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('🎵', style: TextStyle(fontSize: 20)),
                    ),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openArtist(context),
                    child: Text(
                      artist,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (duration.isNotEmpty)
              Text(
                duration,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
              ),
            const SizedBox(width: 8),
            Text(
              '›',
              style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Map<String, dynamic> artist;
  final VoidCallback onTap;
  const _ArtistCard({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = artist['name']?.toString() ?? 'Unknown';
    final imageUrl =
        artist['picture_xl'] ?? artist['picture_medium'] ?? artist['image_url'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border2),
              ),
              child: imageUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(
                          child: Text('🎤'),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('🎤', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              'Artist',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendItem extends StatelessWidget {
  final String icon;
  final LinearGradient gradient;
  final String name;
  final String type;
  final VoidCallback? onTap;

  const _TrendItem({
    required this.icon,
    required this.gradient,
    required this.name,
    required this.type,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
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
                  Text(
                    type,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final String emoji;
  final String name;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GenreCard({
    required this.emoji,
    required this.name,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
