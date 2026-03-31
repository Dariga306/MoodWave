import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
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

  List<dynamic> _trending = [];
  List<dynamic> _tracks = [];
  List<dynamic> _artists = [];
  bool _searching = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      final data = await ApiService().getTrending();
      if (!mounted) return;
      setState(() => _trending = data);
    } catch (_) {}
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _hasQuery = false; _tracks = []; _artists = []; });
      return;
    }
    setState(() { _hasQuery = true; _searching = true; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    try {
      final results = await Future.wait([
        ApiService().searchTracks(q, limit: 10).catchError((_) => <dynamic>[]),
        ApiService().globalSearch(q).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final tracks = (results[0] as List?) ?? [];
      final global = results[1] as Map<String, dynamic>? ?? {};
      final artists = (global['artists'] as List?) ?? [];
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
                      Text('Search',
                          style: GoogleFonts.outfit(
                              fontSize: 26, fontWeight: FontWeight.w800,
                              color: AppColors.text, letterSpacing: -0.02 * 26)),
                      const SizedBox(height: 16),
                      // Real search bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(Icons.search_rounded, size: 20, color: AppColors.text3),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                onChanged: _onChanged,
                                style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: 'Artists, songs, playlists...',
                                  hintStyle: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            if (_hasQuery)
                              GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  setState(() { _hasQuery = false; _tracks = []; _artists = []; });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.text3),
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
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)))
              else if (_hasQuery) ...[
                // Track results
                if (_tracks.isNotEmpty) ...[
                  const SectionHeader(title: 'Songs'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _tracks.take(6).map((t) => _TrackResult(track: t as Map<String, dynamic>)).toList(),
                    ),
                  ),
                ],
                // Artist results
                if (_artists.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Artists'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _artists.take(4).map((a) => _ArtistResult(artist: a as Map<String, dynamic>)).toList(),
                    ),
                  ),
                ],
                if (_tracks.isEmpty && _artists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(children: [
                        const Text('🔍', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('No results found',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                        Text('Try a different search',
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                      ]),
                    ),
                  ),
              ] else ...[
                // Trending
                if (_trending.isNotEmpty) ...[
                  SectionHeader(title: 'Trending Now', action: 'See all', onAction: () {}),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _trending.take(5).map((item) {
                        final name = item is String ? item : (item['query'] ?? item.toString());
                        return _TrendItem(
                          icon: '🔥',
                          gradient: AppColors.gradMixed,
                          name: name,
                          type: 'Trending',
                          onTap: () {
                            _ctrl.text = name;
                            _onChanged(name);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  const SectionHeader(title: 'Trending Now', action: 'See all'),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      _TrendItem(icon: '🔥', gradient: AppColors.gradMixed,
                          name: 'Sweater Weather', type: 'Song · The Neighbourhood'),
                      _TrendItem(icon: '🎤', gradient: AppColors.gradBlue,
                          name: 'The 1975', type: 'Artist · 12.4M followers'),
                      _TrendItem(icon: '💿', gradient: AppColors.gradTeal,
                          name: 'Chill Evening Mix', type: 'Playlist · 2.1K listeners'),
                      _TrendItem(icon: '🎵', gradient: AppColors.gradOrange,
                          name: 'Snow Vibes', type: 'Playlist · Weather mix'),
                    ]),
                  ),
                ],

                // Browse Genres
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
                      _GenreCard(emoji: '🎤', name: 'Pop',
                          gradient: const LinearGradient(colors: [Color(0xFF7c3aed), Color(0xFFa855f7)]),
                          onTap: () { _ctrl.text = 'Pop'; _onChanged('Pop'); }),
                      _GenreCard(emoji: '🎸', name: 'Rock',
                          gradient: const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)]),
                          onTap: () { _ctrl.text = 'Rock'; _onChanged('Rock'); }),
                      _GenreCard(emoji: '✨', name: 'K-Pop',
                          gradient: const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)]),
                          onTap: () { _ctrl.text = 'K-Pop'; _onChanged('K-Pop'); }),
                      _GenreCard(emoji: '🎤', name: 'Hip-Hop',
                          gradient: const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]),
                          onTap: () { _ctrl.text = 'Hip-Hop'; _onChanged('Hip-Hop'); }),
                      _GenreCard(emoji: '🎹', name: 'Electronic',
                          gradient: const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)]),
                          onTap: () { _ctrl.text = 'Electronic'; _onChanged('Electronic'); }),
                      _GenreCard(emoji: '🌙', name: 'Ambient',
                          gradient: const LinearGradient(colors: [Color(0xFF3b0764), Color(0xFF7c3aed)]),
                          onTap: () { _ctrl.text = 'Ambient'; _onChanged('Ambient'); }),
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

  @override
  Widget build(BuildContext context) {
    final title = track['title'] ?? track['trackName'] ?? 'Unknown';
    final artist = track['artist'] ?? track['artistName'] ?? '';
    final coverUrl = track['cover_url'] ?? track['artworkUrl100'];
    final durationMs = track['duration_ms'] ?? track['trackTimeMillis'] ?? 0;
    final duration = durationMs > 0
        ? '${(durationMs ~/ 60000)}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(track: track))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(10)),
            child: coverUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Text('🎵'))))
                : const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ])),
          if (duration.isNotEmpty)
            Text(duration, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(width: 8),
          Text('›', style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3)),
        ]),
      ),
    );
  }
}

class _ArtistResult extends StatelessWidget {
  final Map<String, dynamic> artist;
  const _ArtistResult({required this.artist});

  @override
  Widget build(BuildContext context) {
    final name = artist['name'] ?? artist['artistName'] ?? 'Unknown';
    final imageUrl = artist['image_url'] ?? artist['artworkUrl100'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.gradPurple,
            shape: BoxShape.circle),
          child: imageUrl != null
              ? ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Text('🎤'))))
              : const Center(child: Text('🎤', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text('Artist', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        Text('›', style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3)),
      ]),
    );
  }
}

class _TrendItem extends StatelessWidget {
  final String icon;
  final LinearGradient gradient;
  final String name;
  final String type;
  final VoidCallback? onTap;
  const _TrendItem({required this.icon, required this.gradient, required this.name, required this.type, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              Text(type, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ],
          )),
          Text('›', style: GoogleFonts.outfit(fontSize: 18, color: AppColors.text3)),
        ]),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final String emoji;
  final String name;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _GenreCard({required this.emoji, required this.name, required this.gradient, required this.onTap});
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
            Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
