import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';
import '../utils/media_url.dart';
import 'modals.dart';
import 'user_profile_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _conditionLabel(String? condition) {
  const labels = {
    'clear': 'Sunny',
    'clouds': 'Cloudy',
    'partly_cloudy': 'Partly Cloudy',
    'rain': 'Rainy',
    'drizzle': 'Rainy',
    'snow': 'Snow',
    'thunderstorm': 'Storm',
    'storm': 'Storm',
    'mist': 'Misty',
    'fog': 'Foggy',
    'haze': 'Hazy',
    'smoke': 'Smoky',
  };
  if (condition == null || condition.isEmpty) return 'Clear Sky';
  return labels[condition.toLowerCase()] ??
      condition[0].toUpperCase() + condition.substring(1);
}

// Returns the Twemoji CDN URL for an emoji string.
String _twemojiUrl(String emoji) {
  if (emoji.isEmpty) return '';
  final points = emoji.runes
      .where((cp) => cp != 0xFE0F) // strip variation selectors
      .map((cp) => cp.toRadixString(16).toLowerCase())
      .toList();
  if (points.isEmpty) return '';
  return 'https://cdn.jsdelivr.net/npm/twemoji@14.0.2/assets/72x72/${points.join('-')}.png';
}

String _listenersLabel(int count, String city) {
  if (count <= 0) return 'No one listening now';
  if (count == 1) return '1 person listening now';
  return '$count people listening now';
}

String _playlistListenersLabel(int count, String city) {
  if (count <= 0) return 'No listeners yet';
  if (count == 1) return '1 person in $city';
  return '$count people in $city';
}

String _compactCount(int count) {
  if (count >= 1000000) {
    final value = count / 1000000;
    return '${value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    final value = count / 1000;
    return '${value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}K';
  }
  return '$count';
}

String _trackKey(Map<String, dynamic> track) {
  return (track['track_id'] ??
          track['spotify_id'] ??
          track['deezer_id'] ??
          track['id'] ??
          '')
      .toString();
}

String _trackArtistKey(Map<String, dynamic> track) {
  final raw = (track['artist'] ??
          track['artist_name'] ??
          track['artistName'] ??
          track['creator'] ??
          '')
      .toString()
      .toLowerCase();
  final primary = raw.split(RegExp(r'\s+(feat|ft|featuring)\s+')).first;
  return primary
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
      .trim();
}

List<Map<String, dynamic>> _balancedWeatherTracks(
  List<List<Map<String, dynamic>>> batches,
  int targetCount, {
  int maxPerArtist = 4,
}) {
  final seenTracks = <String>{};
  final perArtist = <String, int>{};
  final queues =
      batches.map((batch) => List<Map<String, dynamic>>.from(batch)).toList();
  final merged = <Map<String, dynamic>>[];
  var hasMore = true;

  while (hasMore && merged.length < targetCount) {
    hasMore = false;
    for (final queue in queues) {
      while (queue.isNotEmpty) {
        hasMore = true;
        final track = queue.removeAt(0);
        final id = _trackKey(track);
        if (id.isEmpty || !seenTracks.add(id)) continue;
        final artist = _trackArtistKey(track);
        final artistCount = perArtist[artist] ?? 0;
        if (artist.isNotEmpty && artistCount >= maxPerArtist) continue;
        if (artist.isNotEmpty) perArtist[artist] = artistCount + 1;
        merged.add(track);
        break;
      }
      if (merged.length >= targetCount) break;
    }
  }

  return merged;
}

List<Map<String, dynamic>> _extractInlineWeatherTracks(
  Map<String, dynamic> playlist,
) {
  final rawTracks = playlist['tracks'] ?? playlist['items'] ?? playlist['songs'];
  if (rawTracks is! List) return [];
  return rawTracks
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _weatherPlaylistQueries(Map<String, dynamic> playlist) {
  final queries = <String>[];
  final artistQueries = playlist['artist_queries'] ??
      playlist['artistQueries'] ??
      playlist['artists'] ??
      playlist['seed_artists'];
  if (artistQueries is List) {
    queries.addAll(artistQueries.map((item) => item.toString().trim()));
  }
  queries.addAll(_weatherSeedQueries(playlist));

  for (final key in ['search_query', 'searchQuery', 'seed_query', 'query']) {
    final value = playlist[key]?.toString().trim();
    if (value != null && value.isNotEmpty) queries.add(value);
  }

  if (queries.isEmpty) {
    for (final key in ['title', 'name', 'mood', 'description']) {
      final value = playlist[key]?.toString().trim();
      if (value != null && value.isNotEmpty) queries.add(value);
    }
  }

  final seen = <String>{};
  return queries
      .where((query) => query.isNotEmpty && seen.add(query.toLowerCase()))
      .toList();
}

List<String> _weatherSeedQueries(Map<String, dynamic> playlist) {
  final id = (playlist['id'] ?? '').toString().toLowerCase();
  final title = (playlist['title'] ?? playlist['name'] ?? '')
      .toString()
      .toLowerCase();
  final weatherKey = (playlist['weather_key'] ?? '').toString().toLowerCase();
  final mood = (playlist['mood'] ?? '').toString().toLowerCase();

  const byId = <String, List<String>>{
    'golden-hour': [
      'Harry Styles',
      'Rex Orange County',
      'Conan Gray',
      'Omar Apollo',
      'Still Woozy',
      'Dominic Fike',
      'Tai Verdes',
      'Wallows',
      'beabadoobee',
      'The 1975',
      'Glass Animals',
      'Phoenix',
    ],
  };

  const byTitle = <String, List<String>>{
    'morning energy': [
      'Dua Lipa',
      'Lizzo',
      'Katy Perry',
      'Nicki Minaj',
      'Bebe Rexha',
      'Meghan Trainor',
      'Cardi B',
      'Kesha',
      'Iggy Azalea',
      'Doja Cat',
      'Sabrina Carpenter',
      'Ariana Grande',
    ],
    'windows down': [
      'Harry Styles',
      'Rex Orange County',
      'Conan Gray',
      'Omar Apollo',
      'Still Woozy',
      'Dominic Fike',
      'Tai Verdes',
      'Wallows',
      'beabadoobee',
      'The 1975',
      'Glass Animals',
      'Phoenix',
    ],
  };

  const byWeather = <String, List<String>>{
    'clear': [
      'Dua Lipa',
      'Harry Styles',
      'Taylor Swift',
      'Sabrina Carpenter',
      'Olivia Rodrigo',
      'Bruno Mars',
      'Pharrell Williams',
      'The 1975',
      'Glass Animals',
      'Jack Johnson',
      'Rex Orange County',
      'Dominic Fike',
    ],
    'rain': [
      'Lana Del Rey',
      'The Weeknd',
      'SZA',
      'Bon Iver',
      'Phoebe Bridgers',
      'Billie Eilish',
      'Frank Ocean',
      'Norah Jones',
      'Nujabes',
      'Clairo',
      'Mitski',
      'Daniel Caesar',
    ],
    'clouds': [
      'Tame Impala',
      'Beach House',
      'Frank Ocean',
      'Mac DeMarco',
      'SZA',
      'James Blake',
      'Vampire Weekend',
      'Men I Trust',
      'Erykah Badu',
      'Still Woozy',
      'Bon Iver',
      'Explosions in the Sky',
    ],
    'snow': [
      'Fleet Foxes',
      'Sufjan Stevens',
      'Radiohead',
      'Max Richter',
      'Ludovico Einaudi',
      'Nils Frahm',
      'Bon Iver',
      'Tycho',
      'Jose Gonzalez',
      'Iron and Wine',
      'John Coltrane',
      'Olafur Arnalds',
    ],
    'storm': [
      'Imagine Dragons',
      'Muse',
      'Linkin Park',
      'Metallica',
      'Nine Inch Nails',
      'Twenty One Pilots',
      'Paramore',
      'Green Day',
      'Skrillex',
      'The Midnight',
      'Foo Fighters',
      'Hans Zimmer',
    ],
    'mist': [
      'Mazzy Star',
      'Portishead',
      'Brian Eno',
      'Cigarettes After Sex',
      'Slowdive',
      'Nick Drake',
      'Washed Out',
      'Nils Frahm',
      'Cocteau Twins',
      'Massive Attack',
      'Chillhop Music',
      'Harold Budd',
    ],
  };

  const byMood = <String, List<String>>{
    'sunny': [
      'Harry Styles',
      'Dua Lipa',
      'Taylor Swift',
      'The 1975',
      'Sabrina Carpenter',
      'Olivia Rodrigo',
      'Bruno Mars',
      'Rex Orange County',
      'Dominic Fike',
      'Doja Cat',
      'Ariana Grande',
      'Lizzo',
    ],
    'energetic': [
      'Bruno Mars',
      'Doja Cat',
      'Pharrell Williams',
      'Lizzo',
      'Dua Lipa',
      'Cardi B',
      'Nicki Minaj',
      'Katy Perry',
      'Pitbull',
      'Flo Rida',
      'Ava Max',
      'Bebe Rexha',
    ],
    'chill': [
      'Frank Ocean',
      'Mac DeMarco',
      'Still Woozy',
      'SZA',
      'Khalid',
      'Daniel Caesar',
      'H.E.R.',
      'Tom Misch',
      'Men I Trust',
      'Clairo',
      'Rex Orange County',
      'Omar Apollo',
    ],
    'rainy': [
      'Lana Del Rey',
      'Bon Iver',
      'Phoebe Bridgers',
      'Clairo',
      'Mitski',
      'Billie Eilish',
      'The National',
      'Sufjan Stevens',
      'Lord Huron',
      'Mazzy Star',
      'Radiohead',
      'Norah Jones',
    ],
    'melancholy': [
      'Billie Eilish',
      'The Weeknd',
      'Mitski',
      'Adele',
      'Lana Del Rey',
      'Frank Ocean',
      'Sam Smith',
      'Bon Iver',
      'SZA',
      'Lord Huron',
      'Phoebe Bridgers',
      'Daniel Caesar',
    ],
    'dreamy': [
      'Beach House',
      'Mazzy Star',
      'Slowdive',
      'Washed Out',
      'Cocteau Twins',
      'Tame Impala',
      'Men I Trust',
      'Cigarettes After Sex',
      'Portishead',
      'Wild Nothing',
      'Grouper',
      'Still Woozy',
    ],
    'stormy': [
      'Muse',
      'Linkin Park',
      'Imagine Dragons',
      'Skrillex',
      'Metallica',
      'Twenty One Pilots',
      'Paramore',
      'Foo Fighters',
      'Nine Inch Nails',
      'Green Day',
      'The Midnight',
      'Hans Zimmer',
    ],
    'cozy': [
      'Fleet Foxes',
      'Sufjan Stevens',
      'Norah Jones',
      'Max Richter',
      'Bon Iver',
      'Jose Gonzalez',
      'Iron and Wine',
      'Gregory Alan Isakov',
      'John Coltrane',
      'Nils Frahm',
      'Ludovico Einaudi',
      'Phoebe Bridgers',
    ],
    'calm': [
      'Nils Frahm',
      'Ludovico Einaudi',
      'Brian Eno',
      'Tycho',
      'Max Richter',
      'Olafur Arnalds',
      'Bonobo',
      'Jon Hopkins',
      'Fleet Foxes',
      'Sufjan Stevens',
      'Norah Jones',
      'Washed Out',
    ],
  };

  return [
    ...?byId[id],
    ...?byTitle[title],
    ...?byWeather[weatherKey],
    ...?byMood[mood],
  ];
}

List<String> _weatherRescueQueries(Map<String, dynamic> playlist) {
  final weatherKey = (playlist['weather_key'] ?? '').toString().toLowerCase();
  final mood = (playlist['mood'] ?? '').toString().toLowerCase();

  const bright = [
    'Dua Lipa',
    'Lizzo',
    'Katy Perry',
    'Nicki Minaj',
    'Bebe Rexha',
    'Meghan Trainor',
    'Cardi B',
    'Kesha',
    'Iggy Azalea',
    'Doja Cat',
    'Sabrina Carpenter',
    'Ariana Grande',
    'Harry Styles',
    'Taylor Swift',
    'Olivia Rodrigo',
    'Bruno Mars',
    'Pharrell Williams',
    'The 1975',
    'Glass Animals',
    'Jack Johnson',
    'Rex Orange County',
    'Dominic Fike',
    'Omar Apollo',
    'Conan Gray',
    'Still Woozy',
    'Tai Verdes',
    'Wallows',
    'beabadoobee',
    'Phoenix',
    'Charlie Puth',
    'Jason Derulo',
    'Maroon 5',
    'Shawn Mendes',
    'Camila Cabello',
    'Ava Max',
    'Carly Rae Jepsen',
    'Zara Larsson',
    'Sigrid',
    'Flo Rida',
    'Pitbull',
    'Ne-Yo',
    'Robin Thicke',
    'Selena Gomez',
    'Justin Bieber',
    'Normani',
    'Gracie Abrams',
    'girl in red',
    'Clairo',
    'Soccer Mommy',
    'Foster the People',
    'MGMT',
    'Two Door Cinema Club',
    'Passion Pit',
    'Young the Giant',
    'Grouplove',
    'Ra Ra Riot',
    'Wet Leg',
    'PinkPantheress',
    'Khalid',
    'H.E.R.',
    'Janelle Monae',
    'Childish Gambino',
    'Anderson Paak',
    'Silk Sonic',
  ];

  const rainy = [
    'Lana Del Rey',
    'The Weeknd',
    'SZA',
    'Bon Iver',
    'Phoebe Bridgers',
    'Billie Eilish',
    'Frank Ocean',
    'Norah Jones',
    'Nujabes',
    'Clairo',
    'Mitski',
    'Daniel Caesar',
    'Lorde',
    'beabadoobee',
    'Snail Mail',
    'Angel Olsen',
    'Japanese Breakfast',
    'Big Thief',
    'Drake',
    'PARTYNEXTDOOR',
    '6LACK',
    'Summer Walker',
    'Jhene Aiko',
    'Kehlani',
    'Fleet Foxes',
    'The National',
    'Sufjan Stevens',
    'Pinegrove',
    'Iron and Wine',
    'Gregory Alan Isakov',
    'Novo Amor',
    'Adrianne Lenker',
    'Julien Baker',
    'Lucy Dacus',
    'Adele',
    'Sam Smith',
    'Amy Winehouse',
    'Duffy',
    'Corinne Bailey Rae',
    'Joss Stone',
    'London Grammar',
    'Diana Krall',
    'Feist',
    'Madeleine Peyroux',
    'Katie Melua',
    'J Dilla',
    'Madlib',
    'Knxwledge',
    'Mac Miller',
    'Oddisee',
    'Linkin Park',
    'Imagine Dragons',
    'Paramore',
    'Fall Out Boy',
    'My Chemical Romance',
  ];

  const cloudy = [
    'Tame Impala',
    'Beach House',
    'Frank Ocean',
    'Mac DeMarco',
    'SZA',
    'James Blake',
    'Vampire Weekend',
    'Men I Trust',
    'Erykah Badu',
    'Still Woozy',
    'Bon Iver',
    'Explosions in the Sky',
    'MGMT',
    'Unknown Mortal Orchestra',
    'Mild High Club',
    'Homeshake',
    'Connan Mockasin',
    'Alex G',
    'D Angelo',
    'Maxwell',
    'Lauryn Hill',
    'Sade',
    'Angie Stone',
    'Jill Scott',
    'India Arie',
    'Musiq Soulchild',
    'Daniel Caesar',
    'H.E.R.',
    'Summer Walker',
    'Kehlani',
    'Lucky Daye',
    'Masego',
    'Real Estate',
    'Beach Fossils',
    'Wild Nothing',
    'Tops',
    'Cocteau Twins',
    'Mazzy Star',
    'Slowdive',
    'Warpaint',
    'Broadcast',
    'Father John Misty',
    'Beirut',
    'Rostam',
    'Grizzly Bear',
    'Whitney',
    'Rex Orange County',
    'Omar Apollo',
    'Dominic Fike',
    'Conan Gray',
    'Tai Verdes',
    'd4vd',
    'Bilal',
    'Sigur Ros',
    'Mogwai',
    'Caspian',
    'Toe',
  ];

  const cold = [
    'Fleet Foxes',
    'Sufjan Stevens',
    'Radiohead',
    'Max Richter',
    'Ludovico Einaudi',
    'Nils Frahm',
    'Bon Iver',
    'Tycho',
    'Jose Gonzalez',
    'Iron and Wine',
    'John Coltrane',
    'Olafur Arnalds',
    'Gregory Alan Isakov',
    'Wilco',
    'The Tallest Man on Earth',
    'Novo Amor',
    'American Football',
    'Thom Yorke',
    'Portishead',
    'Massive Attack',
    'Burial',
    'The xx',
    'Mount Kimbie',
    'Four Tet',
    'Nicolas Jaar',
    'Miles Davis',
    'Bill Evans',
    'Thelonious Monk',
    'Herbie Hancock',
    'Charles Mingus',
    'Dave Brubeck',
    'Chet Baker',
    'Arcade Fire',
    'Tame Impala',
    'Mac DeMarco',
    'Kurt Vile',
    'War on Drugs',
    'Alvvays',
    'Hauschka',
    'Yann Tiersen',
    'Dustin O Halloran',
    'Bonobo',
    'Jon Hopkins',
    'Washed Out',
    'Toro y Moi',
    'Damien Rice',
    'Ben Howard',
    'Nick Drake',
    'Elliott Smith',
    'Angus and Julia Stone',
    'Daughter',
  ];

  const storm = [
    'Imagine Dragons',
    'Muse',
    'Linkin Park',
    'Metallica',
    'Nine Inch Nails',
    'Twenty One Pilots',
    'Paramore',
    'Green Day',
    'Skrillex',
    'The Midnight',
    'Foo Fighters',
    'Hans Zimmer',
    'Bastille',
    'X Ambassadors',
    'OneRepublic',
    'Halsey',
    'Coldplay',
    'The Script',
    'Walk the Moon',
    'Panic at the Disco',
    'My Chemical Romance',
    'Fall Out Boy',
    'All Time Low',
    'Sleeping with Sirens',
    'Pierce the Veil',
    'A Day to Remember',
    'Queens of the Stone Age',
    'Royal Blood',
    'Nothing But Thieves',
    'Biffy Clyro',
    'Wolf Alice',
    'Deftones',
    'Marilyn Manson',
    'HEALTH',
    'Crystal Castles',
    'Zola Jesus',
    'Boy Harsher',
    'Slipknot',
    'System of a Down',
    'Disturbed',
    'Tool',
    'Korn',
    'Rage Against the Machine',
    'Audioslave',
    'Sum 41',
    'Blink-182',
    'The Offspring',
    'Good Charlotte',
    'Simple Plan',
    'FM-84',
    'Timecop1983',
    'Carpenter Brut',
    'Gunship',
    'Deadmau5',
    'Knife Party',
    'Excision',
  ];

  const mist = [
    'Mazzy Star',
    'Portishead',
    'Brian Eno',
    'Cigarettes After Sex',
    'Slowdive',
    'Nick Drake',
    'Washed Out',
    'Nils Frahm',
    'Cocteau Twins',
    'Massive Attack',
    'Chillhop Music',
    'Harold Budd',
    'Grouper',
    'Julee Cruise',
    'Low',
    'Cranes',
    'Beach House',
    'Warpaint',
    'Idealism',
    'Philanthrope',
    'Sagun',
    'Lofi Girl',
    'Jinsang',
    'Kupla',
    'Jazzinuf',
    'Sleepy Fish',
    'Purrple Cat',
    'Tricky',
    'Lamb',
    'Morcheeba',
    'Sneaker Pimps',
    'Hooverphonic',
    'Archive',
    'Moloko',
    'Zero 7',
    'Tangerine Dream',
    'Stars of the Lid',
    'Tim Hecker',
    'William Basinski',
    'The Caretaker',
    'Ride',
    'Chapterhouse',
    'Lush',
    'Wild Nothing',
    'Toro y Moi',
    'Memory Tapes',
    'Small Black',
    'J Cole',
    'Kendrick Lamar',
    'Isaiah Rashad',
    'Vince Staples',
    'Earl Sweatshirt',
    'Max Richter',
    'Olafur Arnalds',
  ];

  if (weatherKey == 'rain' || mood == 'rainy' || mood == 'melancholy') {
    return rainy;
  }
  if (weatherKey == 'clouds' || mood == 'cloudy' || mood == 'dreamy') {
    return cloudy;
  }
  if (weatherKey == 'snow' || mood == 'cozy' || mood == 'calm') {
    return cold;
  }
  if (weatherKey == 'storm' || mood == 'stormy' || mood == 'intense') {
    return storm;
  }
  if (weatherKey == 'mist' || mood == 'foggy') {
    return mist;
  }
  return bright;
}

Future<List<Map<String, dynamic>>> _loadWeatherPlaylistTracks(
  Map<String, dynamic> playlist,
) async {
  final inlineTracks = _extractInlineWeatherTracks(playlist);
  final targetCount =
      max(220, (playlist['track_count'] as num?)?.toInt() ?? 220)
          .clamp(220, 260)
          .toInt();
  final queries = [
    ..._weatherPlaylistQueries(playlist),
    ..._weatherRescueQueries(playlist),
  ];
  final merged = <Map<String, dynamic>>[];
  final seen = <String>{};
  final perArtist = <String, int>{};
  const maxPerArtist = 4;

  void addTrack(Map<String, dynamic> track) {
    final id = _trackKey(track).isNotEmpty
        ? _trackKey(track)
        : '${track['title'] ?? track['trackName'] ?? ''}|${track['artist'] ?? track['artistName'] ?? ''}'
            .toLowerCase();
    if (id.trim().isEmpty || !seen.add(id)) return;
    final artist = _trackArtistKey(track);
    final artistCount = perArtist[artist] ?? 0;
    if (artist.isNotEmpty && artistCount >= maxPerArtist) return;
    if (artist.isNotEmpty) perArtist[artist] = artistCount + 1;
    merged.add(Map<String, dynamic>.from(track));
  }

  Future<void> loadQueries(List<String> sourceQueries) async {
    final seenQueries = <String>{};
    final normalized = sourceQueries
        .where((query) => query.trim().isNotEmpty)
        .where((query) => seenQueries.add(query.trim().toLowerCase()))
        .toList();
    for (var i = 0; i < normalized.length; i += 8) {
      final chunk = normalized.skip(i).take(8).toList();
      final results = await Future.wait(
        chunk.map(
          (query) => ApiService()
              .searchTracksWithFallback(query, limit: 50)
              .catchError((_) => <Map<String, dynamic>>[]),
        ),
      );
      // Round-robin interleaving: take one valid track per query per pass
      final queues =
          results.map((r) => List<Map<String, dynamic>>.from(r)).toList();
      var madeProgress = true;
      while (madeProgress && merged.length < targetCount) {
        madeProgress = false;
        for (final queue in queues) {
          final lenBefore = merged.length;
          while (queue.isNotEmpty) {
            addTrack(queue.removeAt(0));
            if (merged.length > lenBefore) {
              madeProgress = true;
              break;
            }
            if (merged.length >= targetCount) return;
          }
          if (merged.length >= targetCount) return;
        }
      }
      if (merged.length >= targetCount) return;
    }
  }

  for (final track in inlineTracks) {
    addTrack(track);
    if (merged.length >= targetCount) return merged;
  }

  await loadQueries(queries);

  if (merged.length >= targetCount) return merged;

  final charts = await ApiService().getCharts(limit: 50);
  for (final raw in charts.whereType<Map>()) {
    addTrack(Map<String, dynamic>.from(raw));
    if (merged.length >= targetCount) return merged;
  }

  return merged;
}

// ─── Per-condition gradient colours ───────────────────────────────────────────

List<Color> _headerGradient(String condition) {
  switch (condition) {
    case 'clear':
      return const [Color(0xFF0D2238), Color(0xFF12314B), Color(0xFF070D18)];
    case 'partly_cloudy':
      return const [Color(0xFF101D2E), Color(0xFF26364A), Color(0xFF080D18)];
    case 'clouds':
      return const [Color(0xFF111827), Color(0xFF273244), Color(0xFF080D16)];
    case 'rain':
    case 'drizzle':
      return const [Color(0xFF07111F), Color(0xFF12243A), Color(0xFF060A12)];
    case 'snow':
      return const [Color(0xFF131c2e), Color(0xFF1b2840), Color(0xFF0f1625)];
    case 'storm':
    case 'thunderstorm':
      return const [Color(0xFF08090f), Color(0xFF13141e), Color(0xFF060608)];
    case 'mist':
    case 'fog':
    case 'haze':
      return const [Color(0xFF101820), Color(0xFF1a2530), Color(0xFF0c1318)];
    default:
      return const [Color(0xFF06101e), Color(0xFF0a1528), Color(0xFF060e1a)];
  }
}

Color _accentColor(String condition) {
  switch (condition) {
    case 'clear':
      return const Color(0xFFF5C451);
    case 'partly_cloudy':
      return const Color(0xFFf8c85a);
    case 'clouds':
      return const Color(0xFFAEC8E8);
    case 'rain':
    case 'drizzle':
      return const Color(0xFF60a5fa);
    case 'snow':
      return const Color(0xFFe0f2fe);
    case 'storm':
    case 'thunderstorm':
      return const Color(0xFFa78bfa);
    case 'mist':
    case 'fog':
    case 'haze':
      return const Color(0xFF94a3b8);
    default:
      return const Color(0xFF93c5fd);
  }
}

class _WeatherConditionIcon extends StatelessWidget {
  final String condition;
  final String description;
  final double size;
  final Color accent;

  const _WeatherConditionIcon({
    required this.condition,
    required this.description,
    required this.size,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final key = '${condition.toLowerCase()} ${description.toLowerCase()}';
    final isSnow = key.contains('snow') || key.contains('blizzard');
    final isStorm = key.contains('storm') || key.contains('thunder');
    final isRain = key.contains('rain') || key.contains('drizzle');
    final isPartly = key.contains('partly');
    final isCloud = key.contains('cloud') || key.contains('overcast');
    final iconSize = size * 0.62;

    if (isSnow) {
      return _WeatherIconShell(
        size: size,
        accent: accent,
        child: Icon(Icons.ac_unit_rounded, size: iconSize, color: Colors.white),
      );
    }
    if (isStorm) {
      return _WeatherIconShell(
        size: size,
        accent: accent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.cloud_rounded,
                size: iconSize * 1.05, color: const Color(0xFFc4b5fd)),
            Transform.translate(
              offset: Offset(iconSize * 0.10, iconSize * 0.22),
              child: Icon(Icons.bolt_rounded,
                  size: iconSize * 0.66, color: const Color(0xFFfacc15)),
            ),
          ],
        ),
      );
    }
    if (isRain) {
      return _WeatherIconShell(
        size: size,
        accent: accent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -iconSize * 0.10),
              child: Icon(Icons.cloud_rounded,
                  size: iconSize * 0.94, color: const Color(0xFFbfdbfe)),
            ),
            Transform.translate(
              offset: Offset(0, iconSize * 0.28),
              child: Icon(Icons.water_drop_rounded,
                  size: iconSize * 0.48, color: const Color(0xFF60a5fa)),
            ),
          ],
        ),
      );
    }
    if (isPartly) {
      return _WeatherIconShell(
        size: size,
        accent: accent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(-iconSize * 0.16, -iconSize * 0.10),
              child: Icon(Icons.wb_sunny_rounded,
                  size: iconSize * 0.74, color: const Color(0xFFfbbf24)),
            ),
            Transform.translate(
              offset: Offset(iconSize * 0.12, iconSize * 0.08),
              child: Icon(Icons.cloud_rounded,
                  size: iconSize * 0.82, color: const Color(0xFFcbd5e1)),
            ),
          ],
        ),
      );
    }
    if (isCloud) {
      return _WeatherIconShell(
        size: size,
        accent: accent,
        child: Icon(Icons.cloud_rounded,
            size: iconSize, color: const Color(0xFFcbd5e1)),
      );
    }
    return _WeatherIconShell(
      size: size,
      accent: accent,
      child: Icon(Icons.wb_sunny_rounded,
          size: iconSize, color: const Color(0xFFfbbf24)),
    );
  }
}

class _WeatherIconShell extends StatelessWidget {
  final double size;
  final Color accent;
  final Widget child;

  const _WeatherIconShell({
    required this.size,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withOpacity(0.26),
            accent.withOpacity(0.10),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(child: child),
    );
  }
}

// ─── WeatherScreen ─────────────────────────────────────────────────────────────

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  Map<String, dynamic>? _payload;
  bool _loading = true;
  String? _playingPlaylistId;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    final city = user?['city']?.toString() ?? 'Astana';
    setState(() => _loading = true);
    try {
      final data = await ApiService().getWeatherPlaylist(city);
      if (!mounted) return;
      setState(() {
        _payload = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist) async {
    final playlistId = (playlist['id'] ?? '').toString();
    if (playlistId.isEmpty || _playingPlaylistId != null) return;
    setState(() => _playingPlaylistId = playlistId);
    try {
      final queue = await _loadWeatherPlaylistTracks(playlist);
      queue.shuffle(Random());
      if (!mounted) return;
      if (queue.isEmpty) return;
      final city = (_payload?['city'] ?? 'City').toString();
      try {
        final listening = await ApiService().markWeatherListening(
          city,
          playlistId: playlistId,
        );
        _applyListeningCounts(listening);
      } catch (_) {}
      if (!mounted) return;
      final first = Map<String, dynamic>.from(queue.first)
        ..['queue'] = queue
        ..['source'] = '$city weather · ${playlist['title'] ?? 'Vibes'}';
      MiniPlayerOverlayController.forceVisible();
      await context.read<PlayerProvider>().openTrack(first);
      MiniPlayerOverlayController.forceVisible();
    } finally {
      if (mounted) setState(() => _playingPlaylistId = null);
    }
  }

  void _openPlaylistDetail(Map<String, dynamic> playlist) {
    final condition = (_payload?['condition'] ?? '').toString().toLowerCase();
    final city = (_payload?['city'] ?? 'City').toString();
    final topListeners = ((playlist['top_listeners'] as List?) ??
            (_payload?['top_listeners'] as List?) ??
            const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherPlaylistDetailScreen(
          playlist: playlist,
          condition: condition,
          city: city,
          weatherIcon: (_payload?['icon'] ?? '').toString(),
          topListeners: topListeners,
        ),
      ),
    );
  }

  void _applyListeningCounts(Map<String, dynamic> payload) {
    final cityCount = (payload['listeners_count'] as num?)?.toInt();
    final playlistId = (payload['playlist_id'] ?? '').toString();
    final playlistCount =
        (payload['playlist_listeners_count'] as num?)?.toInt();
    if (cityCount == null && playlistCount == null) return;
    setState(() {
      final current = Map<String, dynamic>.from(_payload ?? const {});
      if (cityCount != null) current['listeners_count'] = cityCount;
      final playlists = ((current['playlists'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) {
        final map = Map<String, dynamic>.from(item);
        if (playlistCount != null &&
            (map['id'] ?? '').toString() == playlistId) {
          map['listeners_count'] = playlistCount;
        }
        return map;
      }).toList();
      current['playlists'] = playlists;
      _payload = current;
    });
  }

  Color _hexToColor(String value) {
    final hex = value.replaceAll('#', '');
    if (hex.length != 6) return const Color(0xFF4a6fa5);
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final condition = (_payload?['condition'] ?? '').toString().toLowerCase();
    final condLabel =
        (_payload?['condition_label']?.toString().isNotEmpty == true
                ? _payload!['condition_label']
                : _conditionLabel(condition))
            .toString();
    final description = (_payload?['description'] ?? '').toString();
    final rawTemp = _payload?['temp'];
    final temp = rawTemp is num ? rawTemp.toDouble() : null;

    final city = (_payload?['city'] ?? 'City').toString();
    final listeners = (_payload?['listeners_count'] as num?)?.toInt() ?? 0;

    final topListeners = ((_payload?['top_listeners'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final playlists = ((_payload?['playlists'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final headerColors = _headerGradient(condition);
    final accent = _accentColor(condition);

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: headerColors,
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.purpleLight,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
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
                        ),
                        const SizedBox(height: 20),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purpleLight,
                            ),
                          )
                        else ...[
                          _WeatherConditionIcon(
                            condition: condition,
                            description: description,
                            size: 108,
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          // Temperature
                          Text(
                            temp != null ? '${temp.toStringAsFixed(0)}°' : '—°',
                            style: GoogleFonts.outfit(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -3,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Condition label
                          Text(
                            condLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // City
                          Text(
                            city,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: accent.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Listener pill
                          GestureDetector(
                            onTap: topListeners.isEmpty
                                ? null
                                : () => _showListenersSheet(
                                    topListeners, listeners, city),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (listeners > 0)
                                    AnimatedBuilder(
                                      animation: _blinkController,
                                      builder: (_, __) => Opacity(
                                        opacity: 0.35 +
                                            0.65 * _blinkController.value,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22c55e),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF22c55e)
                                                    .withOpacity(0.55),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.graphic_eq_rounded,
                                        size: 13, color: Colors.white38),
                                  const SizedBox(width: 7),
                                  Text(
                                    _listenersLabel(listeners, city),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: accent.withOpacity(0.9),
                                    ),
                                  ),
                                  if (topListeners.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right_rounded,
                                        size: 14, color: Colors.white38),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Section header ──────────────────────────────────
              if (!_loading && playlists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      'Playlists for this weather',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlist = playlists[index];
                      return _PlaylistCard(
                        playlist: playlist,
                        city: city,
                        isFeatured:
                            playlist['is_featured'] == true && index == 0,
                        playing: _playingPlaylistId ==
                            (playlist['id'] ?? '').toString(),
                        onPlay: () => _playPlaylist(playlist),
                        onViewDetail: () => _openPlaylistDetail(playlist),
                        hexToColor: _hexToColor,
                      );
                    },
                    childCount: playlists.length,
                  ),
                ),
              ],

              // ─── Empty state ─────────────────────────────────────
              if (!_loading && playlists.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                    child: Column(
                      children: [
                        _WeatherConditionIcon(
                          condition: condition,
                          description: description,
                          size: 80,
                          accent: accent,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$condLabel in $city',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Playlists are loading — pull to refresh.',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.text3),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  void _showListenersSheet(
      List<Map<String, dynamic>> listeners, int total, String city) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text(
              _listenersLabel(total, city),
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'People currently listening to $city weather playlists',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
            ),
            const SizedBox(height: 16),
            ...listeners.map((u) {
              final name =
                  (u['display_name'] ?? u['username'] ?? 'User').toString();
              final username = (u['username'] ?? '').toString();
              final avatarUrl =
                  buildMediaUrl((u['avatar_url'] ?? '').toString());
              final userId = (u['id'] as num?)?.toInt();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: userId == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: userId,
                              initialUser: Map<String, dynamic>.from(u),
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient:
                            avatarUrl.isEmpty ? AppColors.gradMixed : null,
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                          : Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            if (username.isNotEmpty)
                              Text('@$username',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.text3),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Playlist card widget (Browse Genres style, used in 2-col grid) ───────────

class _PlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final String city;
  final bool isFeatured;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onViewDetail;
  final Color Function(String) hexToColor;

  const _PlaylistCard({
    required this.playlist,
    required this.city,
    required this.isFeatured,
    required this.playing,
    required this.onPlay,
    required this.onViewDetail,
    required this.hexToColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentStart =
        hexToColor((playlist['accent_start'] ?? '#4a6fa5').toString());
    final accentEnd =
        hexToColor((playlist['accent_end'] ?? '#2d4e7e').toString());
    final listenerCount = (playlist['listeners_count'] as num?)?.toInt() ?? 0;
    final title = (playlist['title'] ?? 'Playlist').toString();
    final description = (playlist['description'] ?? '').toString();
    final emoji = (playlist['emoji'] ?? '🎵').toString();
    final twemojiUrl = _twemojiUrl(emoji);

    return GestureDetector(
      onTap: onViewDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accentStart, accentEnd.withOpacity(0.82)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Stack(
            children: [
              // Faded large emoji background right
              if (twemojiUrl.isNotEmpty)
                Positioned(
                  right: 52,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.12,
                    child: CachedNetworkImage(
                      imageUrl: twemojiUrl,
                      width: 88,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Emoji icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: twemojiUrl.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CachedNetworkImage(
                                  imageUrl: twemojiUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 24))),
                                  errorWidget: (_, __, ___) => Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 24))),
                                ),
                              )
                            : Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 24))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.62),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (listenerCount > 0) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.graphic_eq_rounded,
                                  size: 11, color: Color(0xFFbbf7d0)),
                              const SizedBox(width: 3),
                              Text(
                                '$listenerCount in $city',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFbbf7d0),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Play button
                    GestureDetector(
                      onTap: playing
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onPlay();
                            },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(playing ? 0.1 : 0.22),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Center(
                          child: playing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded,
                                  size: 22, color: Colors.white),
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
    );
  }
}

// ─── Weather Playlist Detail Screen ──────────────────────────────────────────

class WeatherPlaylistDetailScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final String condition;
  final String city;
  final String weatherIcon;
  final List<Map<String, dynamic>> topListeners;

  const WeatherPlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.condition,
    required this.city,
    required this.weatherIcon,
    this.topListeners = const [],
  });

  @override
  State<WeatherPlaylistDetailScreen> createState() =>
      _WeatherPlaylistDetailScreenState();
}

class _WeatherPlaylistDetailScreenState
    extends State<WeatherPlaylistDetailScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      final merged = await _loadWeatherPlaylistTracks(widget.playlist);

      if (!mounted) return;
      setState(() {
        _tracks = merged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _playAll({bool shuffle = false}) async {
    if (_tracks.isEmpty) return;
    var queue = List<Map<String, dynamic>>.from(_tracks);
    if (shuffle) {
      final rng = Random();
      for (int i = queue.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = queue[i];
        queue[i] = queue[j];
        queue[j] = tmp;
      }
    }
    final first = Map<String, dynamic>.from(queue.first)
      ..['queue'] = queue
      ..['source'] =
          '${widget.city} weather · ${widget.playlist['title'] ?? 'Vibes'}';
    try {
      await ApiService().markWeatherListening(
        widget.city,
        playlistId: (widget.playlist['id'] ?? '').toString(),
      );
    } catch (_) {}
    if (!mounted) return;
    MiniPlayerOverlayController.forceVisible();
    await context.read<PlayerProvider>().openTrack(first);
    MiniPlayerOverlayController.forceVisible();
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  Color _hexToColor(String value) {
    final hex = value.replaceAll('#', '');
    if (hex.length != 6) return const Color(0xFF4a6fa5);
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.playlist['title'] ?? 'Playlist').toString();
    final description = (widget.playlist['description'] ?? '').toString();
    final emoji = (widget.playlist['emoji'] ?? '🎵').toString();
    final twemojiUrl = _twemojiUrl(emoji);
    final trackCount = _tracks.length;
    final listenerCount =
        (widget.playlist['listeners_count'] as num?)?.toInt() ?? 0;
    final accentStart =
        _hexToColor((widget.playlist['accent_start'] ?? '#4a6fa5').toString());
    final accentEnd =
        _hexToColor((widget.playlist['accent_end'] ?? '#2d4e7e').toString());

    final headerColors = _headerGradient(widget.condition);
    final accent = _accentColor(widget.condition);

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [headerColors[0], headerColors[1], AppColors.bg],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
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
                      const SizedBox(height: 24),
                      // Playlist header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Playlist icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [accentStart, accentEnd],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: accentStart.withOpacity(0.4),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: twemojiUrl.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: CachedNetworkImage(
                                        imageUrl: twemojiUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, __) => Center(
                                            child: Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 52))),
                                        errorWidget: (_, __, ___) => Center(
                                            child: Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 52))),
                                      ),
                                    )
                                  : Center(
                                      child: Text(emoji,
                                          style:
                                              const TextStyle(fontSize: 52))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Weather badge
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                          color: accent.withOpacity(0.25)),
                                    ),
                                    child: Text(
                                      _conditionLabel(widget.condition),
                                      style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: accent),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (!_loading) '$trackCount songs',
                                    if (listenerCount > 0)
                                      _playlistListenersLabel(
                                          listenerCount, widget.city),
                                  ].join(' · '),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.text2,
                            height: 1.45,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // ── Also listening (compact pill) ──────────────
                      if (widget.topListeners.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showListenersBottomSheet(context),
                          child: Row(
                            children: [
                              // Overlapping mini avatars
                              SizedBox(
                                width: 16.0 +
                                    widget.topListeners.take(4).length * 18.0,
                                height: 26,
                                child: Stack(
                                  children: List.generate(
                                    widget.topListeners.take(4).length,
                                    (i) {
                                      final u = widget.topListeners[i];
                                      final name = (u['display_name'] ??
                                              u['username'] ??
                                              '')
                                          .toString();
                                      final avatarUrl = buildMediaUrl(
                                          (u['avatar_url'] ?? '').toString());
                                      final initial = name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?';
                                      return Positioned(
                                        left: i * 18.0,
                                        child: ClipOval(
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: avatarUrl.isEmpty
                                                  ? AppColors.gradMixed
                                                  : null,
                                              color: avatarUrl.isNotEmpty
                                                  ? AppColors.glass
                                                  : null,
                                              border: Border.all(
                                                  color: AppColors.bg,
                                                  width: 2),
                                            ),
                                            child: avatarUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        Center(
                                                      child: Text(initial,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .white)),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(initial,
                                                        style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Colors.white)),
                                                  ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  listenerCount > 0
                                      ? '${_compactCount(listenerCount)} also listening'
                                      : '${widget.topListeners.length} also listening',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 14, color: AppColors.text3),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
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
                                    ? accent.withOpacity(0.2)
                                    : AppColors.glass,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: provider.shuffleOn
                                      ? accent
                                      : AppColors.border,
                                  width: provider.shuffleOn ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(Icons.shuffle_rounded,
                                  size: 22,
                                  color: provider.shuffleOn
                                      ? accent
                                      : AppColors.text3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _tracks.isEmpty
                                ? null
                                : () => _playAll(shuffle: false),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _tracks.isEmpty
                                    ? null
                                    : LinearGradient(
                                        colors: [accentStart, accentEnd]),
                                color: _tracks.isEmpty ? AppColors.glass : null,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _tracks.isEmpty
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: accentStart.withOpacity(0.35),
                                          blurRadius: 20,
                                        )
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: _tracks.isEmpty
                                          ? AppColors.text3
                                          : Colors.white,
                                      size: 20),
                                  const SizedBox(width: 6),
                                  Text('Play All',
                                      style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _tracks.isEmpty
                                              ? AppColors.text3
                                              : Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Track list ───────────────────────────────────────
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  ),
                ),
              )
            else if (_tracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Center(
                    child: Text('No tracks found',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text3)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final track = Map<String, dynamic>.from(_tracks[i])
                      ..['queue'] = _tracks
                      ..['queue_context'] = title;
                    final trackTitle = track['title']?.toString() ?? 'Unknown';
                    final artist = track['artist']?.toString() ?? '';
                    final coverUrl = track['cover_url']?.toString();
                    final duration = _fmt(track['duration_ms']);

                    return GestureDetector(
                      onTap: () async {
                        MiniPlayerOverlayController.forceVisible();
                        await context.read<PlayerProvider>().openTrack(track);
                        MiniPlayerOverlayController.forceVisible();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Color(0x0AFFFFFF))),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 30,
                            child: Text('${i + 1}',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text3)),
                          ),
                          const SizedBox(width: 12),
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
                                      placeholder: (_, __) => const SizedBox(),
                                      errorWidget: (_, __, ___) => const Center(
                                          child: Icon(Icons.music_note_rounded,
                                              size: 20, color: Colors.white54)),
                                    ))
                                : const Center(
                                    child: Icon(Icons.music_note_rounded,
                                        size: 20, color: Colors.white54)),
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
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(duration,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                            ),
                          GestureDetector(
                            onTap: () => showTrackMenu(
                              context,
                              track: track,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.text3),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showListenersBottomSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Text(
              'Listening in ${widget.city}',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text),
            ),
            const SizedBox(height: 14),
            ...widget.topListeners.map((u) {
              final name =
                  (u['display_name'] ?? u['username'] ?? 'User').toString();
              final username = (u['username'] ?? '').toString();
              final avatarUrl =
                  buildMediaUrl((u['avatar_url'] ?? '').toString());
              final userId = (u['id'] as num?)?.toInt();
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return GestureDetector(
                onTap: userId == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: userId,
                              initialUser: Map<String, dynamic>.from(u),
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient:
                            avatarUrl.isEmpty ? AppColors.gradMixed : null,
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))))
                          : Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            if (username.isNotEmpty)
                              Text('@$username',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.text3),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
