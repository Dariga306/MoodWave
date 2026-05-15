import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';

const List<String> _tasteGenres = [
  'Pop',
  'Rock',
  'Indie Rock',
  'Alt Pop',
  'Electronic',
  'Hip-Hop',
  'R&B',
  'Jazz',
  'Classical',
  'Ambient',
  'Lo-fi',
  'K-Pop',
  'Latin',
  'Reggae',
  'Metal',
  'Punk',
  'Post-Punk',
  'Alternative',
  'Folk',
  'Country',
  'Soul',
  'House',
  'Techno',
  'Drum & Bass',
  'Synthwave',
];

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

class TastePreferencesScreen extends StatefulWidget {
  final List<String> initialGenres;
  final List<Map<String, dynamic>> initialArtists;

  const TastePreferencesScreen({
    super.key,
    required this.initialGenres,
    required this.initialArtists,
  });

  @override
  State<TastePreferencesScreen> createState() => _TastePreferencesScreenState();
}

class _TastePreferencesScreenState extends State<TastePreferencesScreen> {
  static const int _collapsedRecommendationCount = 10;
  static const int _expandedRecommendationCount = 20;
  final _searchCtrl = TextEditingController();
  late final Set<String> _selectedGenres;
  late final List<Map<String, dynamic>> _selectedArtists;
  List<Map<String, dynamic>> _recommendedArtists = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loadingRecommended = true;
  bool _searching = false;
  bool _saving = false;
  bool _showAllRecommended = false;

  @override
  void initState() {
    super.initState();
    _selectedGenres = widget.initialGenres
        .map(_canonicalGenre)
        .where((genre) => genre.isNotEmpty)
        .take(3)
        .toSet();
    _selectedArtists = widget.initialArtists
        .map((artist) => Map<String, dynamic>.from(artist))
        .toList();
    // Show fallback cards immediately so the list is never empty
    _recommendedArtists = _seedFallbackCards();
    _loadingRecommended = false;
    _loadRecommendedArtistsFromApi();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _artistId(Map<String, dynamic> artist) {
    return (artist['id'] ?? artist['artist_id'] ?? '').toString();
  }

  String _artistName(Map<String, dynamic> artist) {
    return (artist['name'] ?? artist['artist'] ?? 'Artist').toString();
  }

  String _artistImage(Map<String, dynamic> artist) {
    return (artist['picture_medium'] ??
            artist['picture_big'] ??
            artist['picture_xl'] ??
            artist['picture_small'] ??
            artist['picture'] ??
            artist['image_url'] ??
            '')
        .toString();
  }

  String _normalizeQuery(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .trim();
  }

  String _artistNameKey(String value) {
    var normalized = _normalizeQuery(value);
    for (final splitter in [' feat ', ' ft ', ' featuring ', ' x ']) {
      if (normalized.contains(splitter)) {
        normalized = normalized.split(splitter).first.trim();
      }
    }
    if (normalized.contains('&')) {
      normalized = normalized.split('&').first.trim();
    }
    if (normalized.contains(',')) {
      normalized = normalized.split(',').first.trim();
    }
    return normalized;
  }

  bool _artistLooksEquivalent(
      Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftName = _artistNameKey(_artistName(left));
    final rightName = _artistNameKey(_artistName(right));
    if (leftName.isEmpty || rightName.isEmpty) return false;
    if (leftName == rightName) return true;
    return leftName.startsWith('$rightName ') ||
        rightName.startsWith('$leftName ');
  }

  List<Map<String, dynamic>> _dedupeArtists(
      List<Map<String, dynamic>> artists) {
    final deduped = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (final artist in artists) {
      final id = _artistId(artist);
      if (id.isNotEmpty && !seenIds.add(id)) continue;
      if (deduped.any((existing) => _artistLooksEquivalent(existing, artist))) {
        continue;
      }
      deduped.add(Map<String, dynamic>.from(artist));
    }
    return deduped;
  }

  bool _needsArtistImage(Map<String, dynamic> artist) =>
      _artistImage(artist).trim().isEmpty && _artistId(artist).isNotEmpty;

  String _canonicalGenre(String value) {
    final normalized = _normalizeQuery(value);
    for (final genre in _tasteGenres) {
      if (_normalizeQuery(genre) == normalized) {
        return genre;
      }
    }
    return '';
  }

  int _artistScore(String query, Map<String, dynamic> artist) {
    final q = _normalizeQuery(query);
    final name = _normalizeQuery(_artistName(artist));
    if (q.isEmpty || name.isEmpty) return 0;
    var score = 0;
    if (name == q) score += 120;
    if (name.startsWith(q)) score += 70;
    if (name.contains(q)) score += 40;
    final queryWords =
        q.split(' ').where((part) => part.trim().isNotEmpty).toList();
    final nameWords =
        name.split(' ').where((part) => part.trim().isNotEmpty).toList();
    for (final word in queryWords) {
      if (nameWords.contains(word)) {
        score += 18;
      } else if (name.contains(word)) {
        score += 8;
      }
    }
    score -= (name.length - q.length).abs().clamp(0, 24);
    return score;
  }

  String _fallbackArtistId(String name) {
    final knownId = _fallbackArtistIds[name];
    if (knownId != null) return knownId.toString();
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final hash = slug.codeUnits.fold<int>(100000, (sum, unit) => sum + unit);
    return hash.toString();
  }

  void _warmArtistImages(List<Map<String, dynamic>> artists) {
    if (!mounted) return;
    final topArtists = artists.take(12);
    for (final artist in topArtists) {
      final imageUrl = _artistImage(artist);
      if (imageUrl.isEmpty) continue;
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
  }

  Future<void> _loadRecommendedArtistsFromApi() async {
    final seeds = <String>[];
    final groupedSeeds = _selectedGenres
        .map((genre) =>
            _genreArtistSeeds[genre.toLowerCase()] ?? const <String>[])
        .where((items) => items.isNotEmpty)
        .toList();
    if (groupedSeeds.isNotEmpty) {
      final longest = groupedSeeds.fold<int>(
        0,
        (best, items) => items.length > best ? items.length : best,
      );
      for (var i = 0; i < longest; i++) {
        for (final items in groupedSeeds) {
          if (i < items.length) {
            seeds.add(items[i]);
          }
        }
      }
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
      final artists = <Map<String, dynamic>>[];
      for (final seed in uniqueSeeds.take(8)) {
        final response = await ApiService()
            .searchArtistsList(seed, limit: 8)
            .catchError((_) => <Map<String, dynamic>>[]);
        final sorted = response
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort((a, b) => _artistScore(seed, b).compareTo(
                _artistScore(seed, a),
              ));
        final primary = sorted.take(4).toList();
        artists.addAll(primary);
        final primaryId = primary.isNotEmpty ? _artistId(primary.first) : '';
        if (primaryId.isNotEmpty) {
          try {
            final profile = await ApiService().getArtistProfile(primaryId);
            final related = ((profile['related_artists'] as List?) ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            artists.addAll(related.take(8));
          } catch (_) {}
        }
        if (artists.length >= _expandedRecommendationCount * 2) {
          break;
        }
      }
      var deduped = _dedupeArtists(artists);
      if (deduped.length < _expandedRecommendationCount) {
        final extras = _localSearchFallback('');
        deduped = _dedupeArtists([
          ...deduped,
          ...extras,
        ]);
      }
      final missingImages = deduped.where(_needsArtistImage).take(12).toList();
      if (missingImages.isNotEmpty) {
        final hydrated = await ApiService().hydrateArtists(missingImages);
        final hydratedById = {
          for (final artist in hydrated) _artistId(artist): artist,
        };
        deduped = deduped
            .map((artist) => hydratedById[_artistId(artist)] ?? artist)
            .map((artist) => Map<String, dynamic>.from(artist))
            .toList();
      }
      deduped = _dedupeArtists(deduped);
      if (!mounted) return;
      if (deduped.isNotEmpty) {
        setState(() => _recommendedArtists =
            deduped.take(_expandedRecommendationCount).toList());
        _warmArtistImages(_recommendedArtists);
      } else {
        final fallback = _seedFallbackCards();
        setState(() => _recommendedArtists = fallback);
        _warmArtistImages(fallback);
      }
    } catch (_) {
      // fallback already shown
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
    // Show local results immediately while API loads
      setState(() {
        _searchResults = _localSearchFallback(q.trim());
        _searching = true;
      });
    try {
      final query = q.trim();
      final results = await ApiService().searchArtistsList(query, limit: 30);
      final combined = <Map<String, dynamic>>[
        ...results.map((item) => Map<String, dynamic>.from(item)),
        ..._localSearchFallback(query),
      ];
      var deduped = _dedupeArtists(combined);
      deduped.sort(
        (a, b) {
          final byScore =
              _artistScore(query, b).compareTo(_artistScore(query, a));
          if (byScore != 0) return byScore;
          return _artistName(a).length.compareTo(_artistName(b).length);
        },
      );
      var filtered = deduped
          .where((artist) => _artistScore(query, artist) > 0)
          .take(20)
          .toList();
      if (!mounted) return;
      setState(() {
        _searchResults =
            filtered.isNotEmpty ? filtered : _localSearchFallback(query);
        _searching = false;
      });
      _warmArtistImages(_searchResults);
      final missingImages = filtered.where(_needsArtistImage).take(10).toList();
      if (missingImages.isNotEmpty) {
        final hydrated = await ApiService().hydrateArtists(missingImages);
        final hydratedById = {
          for (final artist in hydrated) _artistId(artist): artist,
        };
        final hydratedResults = filtered
            .map((artist) => hydratedById[_artistId(artist)] ?? artist)
            .map((artist) => Map<String, dynamic>.from(artist))
            .toList();
        final dedupedHydrated = _dedupeArtists(hydratedResults);
        if (!mounted) return;
        setState(() {
          _searchResults =
              dedupedHydrated.isNotEmpty ? dedupedHydrated : _searchResults;
        });
        _warmArtistImages(_searchResults);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = _localSearchFallback(q.trim());
        _searching = false;
      });
      _warmArtistImages(_searchResults);
    }
  }

  List<Map<String, dynamic>> _seedFallbackCards() {
    final cards = <Map<String, dynamic>>[];
    final seen = <String>{};
    final groupedSeeds = _selectedGenres
        .map((genre) =>
            _genreArtistSeeds[genre.toLowerCase()] ?? const <String>[])
        .where((items) => items.isNotEmpty)
        .toList();
    if (groupedSeeds.isNotEmpty) {
      final longest = groupedSeeds.fold<int>(
        0,
        (best, items) => items.length > best ? items.length : best,
      );
      for (var i = 0; i < longest; i++) {
        for (final names in groupedSeeds) {
          if (i >= names.length) continue;
          final name = names[i];
          if (!seen.add(name.toLowerCase())) continue;
          cards.add({
            'id': _fallbackArtistId(name),
            'name': name,
          });
        }
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
    return _dedupeArtists(cards).take(_expandedRecommendationCount).toList();
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
    final results = names
        .where((name) => name.toLowerCase().contains(lower))
        .map(
          (name) => {
            'id': _fallbackArtistId(name),
            'name': name,
          },
        )
        .toList();
    results.sort(
      (a, b) => _artistScore(query, b).compareTo(_artistScore(query, a)),
    );
    return _dedupeArtists(results).take(_expandedRecommendationCount).toList();
  }

  Future<void> _hydrateSelectedArtist(String id) async {
    try {
      final profile = await ApiService().getArtistProfile(id);
      if (!mounted) return;
      final index = _selectedArtists.indexWhere((item) => _artistId(item) == id);
      if (index < 0) return;
      final hydrated = Map<String, dynamic>.from(profile);
      setState(() => _selectedArtists[index] = hydrated);
    } catch (_) {}
  }

  void _toggleArtist(Map<String, dynamic> artist) {
    final id = _artistId(artist);
    if (id.isEmpty) return;
    final index = _selectedArtists.indexWhere((item) => _artistId(item) == id);
    if (index >= 0) {
      setState(() => _selectedArtists.removeAt(index));
      return;
    }
    if (_selectedArtists.length >= 5) {
      showErrorSnackBar(context, 'Choose up to 5 artists');
      return;
    }
    final selectedArtist = Map<String, dynamic>.from(artist);
    setState(() => _selectedArtists.add(selectedArtist));
    if (_needsArtistImage(selectedArtist)) {
      unawaited(_hydrateSelectedArtist(id));
    }
  }

  void _toggleGenre(String genre) {
    final selected = _selectedGenres.contains(genre);
    if (!selected && _selectedGenres.length >= 3) {
      showErrorSnackBar(context, 'Choose up to 3 genres');
      return;
    }

    setState(() {
      if (selected) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
      _showAllRecommended = false;
      _searchCtrl.clear();
      _searchResults = [];
      _recommendedArtists = _seedFallbackCards();
      _loadingRecommended = false;
    });
    _warmArtistImages(_recommendedArtists);
    _loadRecommendedArtistsFromApi();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final genres =
          _selectedGenres.take(3).toList().asMap().entries.map((entry) {
        return {
          'genre': entry.value,
          'weight': 1.0 - (entry.key * 0.02),
        };
      }).toList();
      await Future.wait([
        ApiService().saveGenres(genres),
        ApiService().saveFavoriteArtists(_selectedArtists),
      ]);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.reload();
      if (!mounted) return;
      auth.bumpProfileRevision();
      showSuccessSnackBar(context, 'Music taste updated');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not update music taste');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearchingArtists = _searchCtrl.text.trim().length >= 2;
    final artistList =
        isSearchingArtists ? _searchResults : _recommendedArtists;
    final visibleArtistList = !isSearchingArtists &&
            !_showAllRecommended &&
            artistList.length > _collapsedRecommendationCount
        ? artistList.take(_collapsedRecommendationCount).toList()
        : artistList;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          'Music Taste',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
            children: [
              Text(
                'Favorite genres',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick the styles you genuinely come back to',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tasteGenres.map((genre) {
                  final selected = _selectedGenres.contains(genre);
                  return GestureDetector(
                    onTap: () => _toggleGenre(genre),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.primaryBtn : null,
                        color: selected ? null : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              selected ? Colors.transparent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        genre,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.text2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Artists you like',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose up to 5 artists for your profile and matches',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_selectedArtists.length}/5',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _selectedArtists.isNotEmpty
                          ? AppColors.purpleLight
                          : AppColors.text3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _searchArtists,
                  style:
                      GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Search artists...',
                    hintStyle: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.text3),
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
              if (_selectedArtists.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedArtists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final artist = _selectedArtists[i];
                      return _SelectedArtistPreview(
                        artist: artist,
                        name: _artistName(artist),
                        imageUrl: _artistImage(artist),
                        onRemove: () => _toggleArtist(artist),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSearchingArtists
                              ? 'Search results'
                              : _selectedGenres.isNotEmpty
                                  ? 'Recommended from your genres'
                                  : 'Popular artists',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (!isSearchingArtists && _selectedGenres.isEmpty)
                          Text(
                            'Select genres above to get personalised picks',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.text3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isSearchingArtists &&
                      artistList.length > _collapsedRecommendationCount)
                    GestureDetector(
                      onTap: () => setState(
                          () => _showAllRecommended = !_showAllRecommended),
                      child: Text(
                        _showAllRecommended ? 'Show less' : 'Show all',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purpleLight,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingRecommended && _recommendedArtists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  ),
                )
              else if (artistList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No artists found yet',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.text3,
                    ),
                  ),
                )
              else ...[
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.purpleLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading artist images...',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...visibleArtistList.map((artist) {
                  final selected = _selectedArtists.any(
                    (item) => _artistId(item) == _artistId(artist),
                  );
                  return _ArtistListTile(
                    name: _artistName(artist),
                    imageUrl: _artistImage(artist),
                    selected: selected,
                    onTap: () => _toggleArtist(artist),
                  );
                }),
              ],
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryBtn,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDark.withOpacity(0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
}

class _SelectedArtistPreview extends StatelessWidget {
  final Map<String, dynamic> artist;
  final String name;
  final String imageUrl;
  final VoidCallback onRemove;

  const _SelectedArtistPreview({
    required this.artist,
    required this.name,
    required this.imageUrl,
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
              _ArtistAvatar(
                name: name,
                imageUrl: imageUrl,
                radius: 22,
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

class _ArtistListTile extends StatelessWidget {
  final String name;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ArtistListTile({
    required this.name,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface3 : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.purpleLight : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            _ArtistAvatar(
              name: name,
              imageUrl: imageUrl,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? AppColors.purpleLight : AppColors.text3,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double radius;

  const _ArtistAvatar({
    required this.name,
    required this.imageUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradMixed,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: GoogleFonts.outfit(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    if (imageUrl.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
