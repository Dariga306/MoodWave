class LyricsMatchContext {
  final List<String> titleVariants;
  final List<String> artistVariants;
  final String albumName;
  final int durationSeconds;

  const LyricsMatchContext({
    required this.titleVariants,
    required this.artistVariants,
    required this.albumName,
    required this.durationSeconds,
  });

  int score(Map<String, dynamic> item) {
    final itemTitle =
        (item['trackName'] ?? item['name'] ?? item['track_name'] ?? '')
            .toString();
    final itemArtist =
        (item['artistName'] ?? item['artist'] ?? item['artist_name'] ?? '')
            .toString();
    final synced =
        (item['syncedLyrics'] as String?)?.isNotEmpty == true ? 1000 : 0;
    final plain = (item['plainLyrics'] as String?)?.isNotEmpty == true ? 250 : 0;
    final itemTitleTokens = lookupTokens(itemTitle);
    final itemArtistTokens = lookupTokens(itemArtist);
    final titleScores = titleVariants.map((title) {
      final titleTokens = lookupTokens(title);
      final matches = titleTokens.intersection(itemTitleTokens).length;
      return titleTokens.isNotEmpty
          ? matches * 110 + (matches == titleTokens.length ? 260 : 0)
          : 0;
    });
    final artistScores = artistVariants.map((artist) {
      final artistTokens = lookupTokens(artist);
      final matches = artistTokens.intersection(itemArtistTokens).length;
      return artistTokens.isNotEmpty
          ? matches * 130 + (matches == artistTokens.length ? 320 : 0)
          : 0;
    });
    final titleBonus =
        titleScores.isEmpty ? 0 : titleScores.reduce((a, b) => a > b ? a : b);
    final artistBonus = artistScores.isEmpty
        ? 0
        : artistScores.reduce((a, b) => a > b ? a : b);
    final exactTitleBonus = strongTitleMatch(itemTitle) ? 600 : -1200;
    final exactArtistBonus = strongArtistMatch(itemArtist) ? 500 : -900;
    final itemDuration = (item['duration'] as num?)?.toInt() ?? durationSeconds;
    final durationPenalty = durationSeconds > 0
        ? (durationSeconds - itemDuration).abs() * 2
        : 0;
    final albumBonus = albumName.isNotEmpty &&
            (item['albumName']?.toString().toLowerCase() ==
                albumName.toLowerCase())
        ? 80
        : 0;
    return synced +
        plain +
        titleBonus +
        artistBonus +
        exactTitleBonus +
        exactArtistBonus +
        albumBonus -
        durationPenalty;
  }

  bool acceptsCandidate(
    Map<String, dynamic> item, {
    int maxDurationDiffSeconds = 10,
  }) {
    final candidateTitle =
        (item['trackName'] ?? item['name'] ?? item['track_name'] ?? '')
            .toString();
    final candidateArtist =
        (item['artistName'] ?? item['artist'] ?? item['artist_name'] ?? '')
            .toString();
    final candidateDuration = (item['duration'] as num?)?.toInt() ?? 0;
    if (!strongTitleMatch(candidateTitle) || !strongArtistMatch(candidateArtist)) {
      return false;
    }
    if (durationSeconds > 0 &&
        candidateDuration > 0 &&
        (durationSeconds - candidateDuration).abs() > maxDurationDiffSeconds) {
      return false;
    }
    return true;
  }

  bool strongTitleMatch(String candidateTitle) {
    final candidate = normalizeLookupText(candidateTitle);
    if (candidate.isEmpty) return false;
    for (final title in titleVariants) {
      final wanted = normalizeLookupText(title);
      if (wanted.isEmpty) continue;
      if (candidate == wanted ||
          candidate.contains(wanted) ||
          wanted.contains(candidate)) {
        return true;
      }
      final wantedTokens = lookupTokens(wanted);
      final candidateTokens = lookupTokens(candidate);
      if (wantedTokens.isEmpty || candidateTokens.isEmpty) continue;
      final overlap = wantedTokens.intersection(candidateTokens).length;
      final ratio = overlap / wantedTokens.length;
      if (ratio >= 0.75) return true;
    }
    return false;
  }

  bool strongArtistMatch(String candidateArtist) {
    final candidate = normalizeLookupText(candidateArtist);
    if (candidate.isEmpty) return false;
    for (final artist in artistVariants) {
      final wanted = normalizeLookupText(artist);
      if (wanted.isEmpty) continue;
      if (candidate == wanted ||
          candidate.contains(wanted) ||
          wanted.contains(candidate)) {
        return true;
      }
      final wantedTokens = lookupTokens(wanted);
      final candidateTokens = lookupTokens(candidate);
      if (wantedTokens.isEmpty || candidateTokens.isEmpty) continue;
      final overlap = wantedTokens.intersection(candidateTokens).length;
      final ratio = overlap / wantedTokens.length;
      if (ratio >= 0.6) return true;
    }
    return false;
  }
}

String normalizeLookupText(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'\((official|audio|lyrics?|video|live).*?\)'), ' ')
      .replaceAll(RegExp(r'\[(official|audio|lyrics?|video|live).*?\]'), ' ')
      .replaceAll(RegExp(r'\((feat|ft|with).*?\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\[(feat|ft|with).*?\]', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> lookupTokens(String value) {
  return normalizeLookupText(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();
}

String stripTrackVersion(String value) {
  return value
      .replaceAll(RegExp(r'\((feat|ft|with).*?\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\[(feat|ft|with).*?\]', caseSensitive: false), ' ')
      .replaceAll(
          RegExp(r'\((live|remaster(ed)?|sped up|slowed|version).*?\)',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(r'\[(live|remaster(ed)?|sped up|slowed|version).*?\]',
              caseSensitive: false),
          ' ')
      .replaceAll(
          RegExp(r'\s+-\s+(live|remaster(ed)?|sped up|slowed).*$',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> buildTitleVariants(String title) {
  final variants = <String>{};
  final raw = title.trim();
  if (raw.isNotEmpty) {
    variants.add(raw);
    final stripped = stripTrackVersion(raw);
    if (stripped.isNotEmpty) {
      variants.add(stripped);
    }
  }
  return variants.where((value) => value.isNotEmpty).toList();
}

List<String> buildArtistVariants(
  String artist, {
  String? primaryArtist,
  List<String> extraArtists = const [],
}) {
  final variants = <String>{};
  final full = artist.trim();
  if (full.isNotEmpty) {
    variants.add(full);
  }
  final primary = (primaryArtist ?? '').trim();
  if (primary.isNotEmpty) {
    variants.add(primary);
  }
  for (final item in extraArtists) {
    final name = item.trim();
    if (name.isNotEmpty) {
      variants.add(name);
    }
  }
  return variants.toList();
}
