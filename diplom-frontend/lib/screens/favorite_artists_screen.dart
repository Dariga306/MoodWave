import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'city_select_screen.dart';

const Map<String, List<String>> _genreArtistSeeds = {
  'pop': ['Taylor Swift', 'Dua Lipa', 'Ariana Grande', 'Sabrina Carpenter'],
  'rock': ['Arctic Monkeys', 'Nirvana', 'Queen', 'Linkin Park'],
  'indie rock': ['The Neighbourhood', 'The 1975', 'Tame Impala', 'Wallows'],
  'alt pop': ['Billie Eilish', 'Lorde', 'Halsey', 'Melanie Martinez'],
  'electronic': ['Daft Punk', 'Fred again..', 'Flume', 'Calvin Harris'],
  'hip-hop': ['Travis Scott', 'Kendrick Lamar', 'Drake', 'Future'],
  'r&b': ['SZA', 'The Weeknd', 'Frank Ocean', 'Brent Faiyaz'],
  'jazz': ['Miles Davis', 'Chet Baker', 'Bill Evans', 'Nina Simone'],
  'classical': ['Ludovico Einaudi', 'Hans Zimmer', 'Chopin', 'Mozart'],
  'ambient': ['Brian Eno', 'Moby', 'Nils Frahm', 'Tycho'],
  'lo-fi': ['Jinsang', 'idealism', 'Nujabes', 'potsu'],
  'k-pop': ['NewJeans', 'BLACKPINK', 'BTS', 'Stray Kids', 'aespa'],
  'latin': ['Bad Bunny', 'Rosalia', 'Karol G', 'Rauw Alejandro'],
  'reggae': ['Bob Marley', 'Sean Paul', 'Shaggy', 'Protoje'],
  'metal': ['Slipknot', 'Metallica', 'Deftones', 'Bring Me The Horizon'],
  'punk': ['blink-182', 'Green Day', 'Paramore', 'Sum 41'],
  'punk rock': ['blink-182', 'Green Day', 'The Offspring', 'Good Charlotte'],
  'post-punk': ['Molchat Doma', 'Joy Division', 'The Cure', 'Кино'],
  'alternative': ['Radiohead', 'Deftones', 'Muse', 'Placebo'],
  'folk': ['Phoebe Bridgers', 'Bon Iver', 'Fleet Foxes', 'Noah Kahan'],
  'country': ['Taylor Swift', 'Morgan Wallen', 'Kacey Musgraves', 'Luke Combs'],
  'soul': ['Amy Winehouse', 'Adele', 'Sam Cooke', 'Leon Bridges'],
  'house': ['FISHER', 'Peggy Gou', 'Disclosure', 'MK'],
  'techno': ['Charlotte de Witte', 'Anyma', 'Amelie Lens', 'Boris Brejcha'],
  'drum & bass': ['Chase & Status', 'Sub Focus', 'Pendulum', 'Dimension'],
  'synthwave': ['The Midnight', 'Kavinsky', 'FM-84', 'Perturbator'],
};

const Map<String, int> _fallbackArtistIds = {
  'Adele': 75798,
  'Amelie Lens': 327845761,
  'Amy Winehouse': 9052,
  'Anyma': 1014142,
  'Arctic Monkeys': 1182,
  'Ariana Grande': 1562681,
  'BLACKPINK': 10803980,
  'BTS': 6982223,
  'Bad Bunny': 10583405,
  'Bill Evans': 2060,
  'Billie Eilish': 9635624,
  'Bob Marley': 719,
  'Bon Iver': 78668,
  'Boris Brejcha': 133863,
  'Brent Faiyaz': 7397124,
  'Brian Eno': 2042,
  'Bring Me The Horizon': 12874,
  'Calvin Harris': 12178,
  'Charlotte de Witte': 5384533,
  'Chase & Status': 15617,
  'Chet Baker': 5853,
  'Chopin': 8473,
  'Daft Punk': 27,
  'Deftones': 535,
  'Dimension': 83867382,
  'Disclosure': 409796,
  'Drake': 246791,
  'Dua Lipa': 8706544,
  'FISHER': 56125,
  'FM-84': 7814812,
  'Fleet Foxes': 74444,
  'Flume': 1164295,
  'Frank Ocean': 1350335,
  'Fred again..': 76053262,
  'Future': 165930,
  'Good Charlotte': 703,
  'Green Day': 52,
  'Halsey': 5292512,
  'Hans Zimmer': 1935,
  'Jinsang': 11424216,
  'Joy Division': 1249,
  'Kacey Musgraves': 399990,
  'Kanye West': 230,
  'Karol G': 5297021,
  'Kavinsky': 13358,
  'Kendrick Lamar': 525046,
  'Lana Del Rey': 1424821,
  'Leon Bridges': 7420680,
  'Linkin Park': 92,
  'Lorde': 4448485,
  'Ludovico Einaudi': 4331,
  'Luke Combs': 9626504,
  'MK': 148517,
  'Melanie Martinez': 5518450,
  'Metallica': 119,
  'Miles Davis': 1910,
  'Moby': 493,
  'Molchat Doma': 73228892,
  'Morgan Wallen': 7188840,
  'Mozart': 5695,
  'Muse': 705,
  'NewJeans': 178008437,
  'Nils Frahm': 332318,
  'Nina Simone': 744,
  'Nirvana': 415,
  'Noah Kahan': 11819131,
  'Nujabes': 1978,
  'Paramore': 10977,
  'Peggy Gou': 9549148,
  'Pendulum': 281,
  'Perturbator': 4740810,
  'Phoebe Bridgers': 1058631,
  'Placebo': 8,
  'Protoje': 263794251,
  'Queen': 412,
  'Radiohead': 399,
  'Rauw Alejandro': 11289472,
  'Rosalia': 554792,
  'SZA': 5531258,
  'Sabrina Carpenter': 1176900,
  'Sam Cooke': 900,
  'Sean Paul': 88,
  'Shaggy': 461,
  'Slipknot': 117,
  'Stray Kids': 13923487,
  'Sub Focus': 11214,
  'Sum 41': 459,
  'Tame Impala': 134790,
  'Taylor Swift': 12246,
  'The 1975': 3583591,
  'The Cure': 381,
  'The Midnight': 6807853,
  'The Neighbourhood': 296861,
  'The Offspring': 882,
  'The Weeknd': 4050205,
  'Travis Scott': 4495513,
  'Tycho': 63750,
  'Wallows': 12289196,
  'aespa': 113547672,
  'idealism': 11900657,
  'potsu': 9815068,
  'Кино': 4505880,
};

class FavoriteArtistsScreen extends StatefulWidget {
  final List<String> selectedGenres;

  const FavoriteArtistsScreen({
    super.key,
    required this.selectedGenres,
  });

  @override
  State<FavoriteArtistsScreen> createState() => _FavoriteArtistsScreenState();
}

class _FavoriteArtistsScreenState extends State<FavoriteArtistsScreen> {
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selected = [];
  List<Map<String, dynamic>> _recommended = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loadingRecommended = true;
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _artistImage(Map<String, dynamic> artist) {
    return (artist['picture_medium'] ??
            artist['picture_big'] ??
            artist['picture_xl'] ??
            artist['picture'] ??
            artist['image_url'] ??
            '')
        .toString();
  }

  String _artistName(Map<String, dynamic> artist) {
    return (artist['name'] ?? artist['artist'] ?? 'Artist').toString();
  }

  String _artistId(Map<String, dynamic> artist) {
    return (artist['id'] ?? artist['artist_id'] ?? '').toString();
  }

  String _fallbackArtistId(String name) {
    final knownId = _fallbackArtistIds[name];
    if (knownId != null) return knownId.toString();
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final hash = slug.codeUnits.fold<int>(100000, (sum, unit) => sum + unit);
    return hash.toString();
  }

  Future<void> _loadRecommended() async {
    final seeds = <String>[];
    for (final genre in widget.selectedGenres) {
      final key = genre.toLowerCase().trim();
      seeds.addAll(_genreArtistSeeds[key] ?? const []);
    }
    if (seeds.isEmpty) {
      seeds.addAll(
          const ['The Weeknd', 'Lana Del Rey', 'Billie Eilish', 'Drake']);
    }

    final uniqueSeeds = <String>[];
    for (final seed in seeds) {
      if (!uniqueSeeds.contains(seed)) {
        uniqueSeeds.add(seed);
      }
    }

    try {
      final responses = <List<Map<String, dynamic>>>[];
      for (final name in uniqueSeeds.take(12)) {
        responses.add(await ApiService().searchArtistsList(name, limit: 3));
      }
      final artists = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final result in responses) {
        for (final artist in result) {
          final id = _artistId(artist);
          if (id.isEmpty || !seen.add(id)) continue;
          artists.add(artist);
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _recommended = artists.isNotEmpty ? artists : _seedFallbackCards();
        _loadingRecommended = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommended = _seedFallbackCards();
        _loadingRecommended = false;
      });
    }
  }

  Future<void> _searchArtists(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await ApiService().searchArtistsList(q.trim(), limit: 18);
      if (!mounted) return;
      setState(() {
        _searchResults =
            result.isNotEmpty ? result : _localSearchFallback(q.trim());
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = _localSearchFallback(q.trim());
        _searching = false;
      });
    }
  }

  List<Map<String, dynamic>> _seedFallbackCards() {
    final cards = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final genre in widget.selectedGenres) {
      final names = _genreArtistSeeds[genre.toLowerCase().trim()] ?? const [];
      for (final name in names) {
        if (!seen.add(name.toLowerCase())) continue;
        cards.add({
          'id': _fallbackArtistId(name),
          'name': name,
        });
      }
    }
    if (cards.isEmpty) {
      for (final name in const [
        'The Weeknd',
        'Lana Del Rey',
        'Drake',
        'Billie Eilish'
      ]) {
        cards.add({
          'id': _fallbackArtistId(name),
          'name': name,
        });
      }
    }
    return cards.take(10).toList();
  }

  List<Map<String, dynamic>> _localSearchFallback(String query) {
    final lower = query.toLowerCase();
    final names = <String>{
      ..._genreArtistSeeds.values.expand((items) => items),
      'Kanye West',
      'The Weeknd',
      'Lana Del Rey',
      'Billie Eilish',
      'Taylor Swift',
      'NewJeans',
      'BLACKPINK',
      'BTS',
      'Arctic Monkeys',
      'Radiohead',
      'Drake',
      'SZA',
    };
    return names
        .where((name) => name.toLowerCase().contains(lower))
        .take(10)
        .map(
          (name) => {
            'id': _fallbackArtistId(name),
            'name': name,
          },
        )
        .toList();
  }

  void _toggleArtist(Map<String, dynamic> artist) {
    final id = _artistId(artist);
    if (id.isEmpty) return;
    final index = _selected.indexWhere((item) => _artistId(item) == id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
      return;
    }
    if (_selected.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose up to 5 artists',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF3d0000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selected.add(Map<String, dynamic>.from(artist)));
  }

  Future<void> _continue() async {
    if (_selected.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose 5 artists you like',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF3d0000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService().saveFavoriteArtists(_selected);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CitySelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data =
        _searchCtrl.text.trim().length >= 2 ? _searchResults : _recommended;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF150825), Color(0xFF08080f)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(done: true),
                        const SizedBox(width: 6),
                        _dot(done: true),
                        const SizedBox(width: 6),
                        _dot(done: true),
                        const SizedBox(width: 6),
                        _dot(active: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Choose 5 artists you like',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We use them for your profile, matches and recommendations',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selected.length}/5 selected',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _selected.length >= 5
                            ? AppColors.purpleLight
                            : AppColors.text3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _searchArtists,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search artists...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.text3,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.text3,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selected.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final artist = _selected[i];
                            return _SelectedArtistPill(
                              artist: artist,
                              imageUrl: _artistImage(artist),
                              name: _artistName(artist),
                              onRemove: () => _toggleArtist(artist),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _searchCtrl.text.trim().length >= 2
                                ? 'Search Results'
                                : 'Recommended from your genres',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loadingRecommended && _recommended.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.purpleLight,
                                ),
                              )
                            : _searching
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.purpleLight,
                                    ),
                                  )
                                : data.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No artists found',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            color: AppColors.text3,
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1.5,
                                        ),
                                        itemCount: data.length,
                                        itemBuilder: (_, i) {
                                          final artist = data[i];
                                          final selected = _selected.any(
                                            (item) =>
                                                _artistId(item) ==
                                                _artistId(artist),
                                          );
                                          return _ArtistChoiceCard(
                                            artist: artist,
                                            selected: selected,
                                            imageUrl: _artistImage(artist),
                                            name: _artistName(artist),
                                            onTap: () => _toggleArtist(artist),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: GestureDetector(
                  onTap: _saving ? null : _continue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: _selected.length >= 5
                          ? AppColors.primaryBtn
                          : const LinearGradient(
                              colors: [Color(0xFF2a2a3d), Color(0xFF2a2a3d)],
                            ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selected.length >= 5
                          ? [
                              BoxShadow(
                                color: AppColors.purpleDark.withOpacity(0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : [],
                    ),
                    child: _saving
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Continue →',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _selected.length >= 5
                                  ? Colors.white
                                  : AppColors.text3,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot({bool done = false, bool active = false}) {
    final w = done
        ? 20.0
        : active
            ? 14.0
            : 7.0;
    final c = done
        ? AppColors.purple
        : active
            ? AppColors.purpleLight
            : AppColors.surface3;
    return Container(
      width: w,
      height: 7,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

class _ArtistChoiceCard extends StatelessWidget {
  final Map<String, dynamic> artist;
  final bool selected;
  final String imageUrl;
  final String name;
  final VoidCallback onTap;

  const _ArtistChoiceCard({
    required this.artist,
    required this.selected,
    required this.imageUrl,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.gradMixed : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.purpleDark.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white12,
              backgroundImage: imageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(imageUrl)
                  : null,
              child: imageUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedArtistPill extends StatelessWidget {
  final Map<String, dynamic> artist;
  final String imageUrl;
  final String name;
  final VoidCallback onRemove;

  const _SelectedArtistPill({
    required this.artist,
    required this.imageUrl,
    required this.name,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white12,
                backgroundImage: imageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                top: -2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF11111A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
