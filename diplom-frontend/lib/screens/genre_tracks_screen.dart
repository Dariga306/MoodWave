import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';
import '../utils/show_snackbar.dart';
import 'modals.dart';

// Top artists per genre for parallel search — 20 artists × 20 tracks = ~150+ real tracks
const _genreArtists = <String, List<String>>{
  'pop': [
    'Taylor Swift',
    'Dua Lipa',
    'The Weeknd',
    'Ariana Grande',
    'Harry Styles',
    'Olivia Rodrigo',
    'Justin Bieber',
    'Selena Gomez',
    'Bruno Mars',
    'Lady Gaga',
    'Katy Perry',
    'Billie Eilish',
    'Shawn Mendes',
    'Ed Sheeran',
    'Post Malone',
    'Camila Cabello',
    'Miley Cyrus',
    'Sam Smith',
    'Adele',
    'Bebe Rexha'
  ],
  'rock': [
    'Queen',
    'Linkin Park',
    'Arctic Monkeys',
    'Imagine Dragons',
    'Foo Fighters',
    'Red Hot Chili Peppers',
    'Green Day',
    'Twenty One Pilots',
    'Nirvana',
    'Pearl Jam',
    'Radiohead',
    'Coldplay',
    'U2',
    'The Beatles',
    'AC/DC',
    'Led Zeppelin',
    'Metallica',
    'Muse',
    'The Strokes',
    'Oasis'
  ],
  'hip-hop': [
    'Drake',
    'Kendrick Lamar',
    'Travis Scott',
    'J. Cole',
    'Kanye West',
    'Cardi B',
    'Post Malone',
    'Eminem',
    'Jay-Z',
    'Lil Wayne',
    'Nicki Minaj',
    '21 Savage',
    'Future',
    'Tyler the Creator',
    'Childish Gambino',
    'A\$AP Rocky',
    'Big Sean',
    'Lil Baby',
    'Wiz Khalifa',
    'Mac Miller'
  ],
  'electronic': [
    'Daft Punk',
    'Calvin Harris',
    'Martin Garrix',
    'Deadmau5',
    'Skrillex',
    'Avicii',
    'Marshmello',
    'Kygo',
    'The Chainsmokers',
    'Diplo',
    'Tiësto',
    'Zedd',
    'Flume',
    'Disclosure',
    'Duke Dumont',
    'Porter Robinson',
    'Madeon',
    'Rezz',
    'Illenium',
    'Tchami'
  ],
  'jazz': [
    'Miles Davis',
    'John Coltrane',
    'Norah Jones',
    'Diana Krall',
    'Chet Baker',
    'Bill Evans',
    'Dave Brubeck',
    'Herbie Hancock',
    'Louis Armstrong',
    'Thelonious Monk',
    'Charlie Parker',
    'Ella Fitzgerald',
    'Duke Ellington',
    'Wes Montgomery',
    'Oscar Peterson',
    'Pat Metheny',
    'Wayne Shorter',
    'Dizzy Gillespie',
    'Charles Mingus',
    'Sonny Rollins'
  ],
  'k-pop': [
    'BTS',
    'BLACKPINK',
    'EXO',
    'TWICE',
    'Stray Kids',
    'NewJeans',
    'aespa',
    'IU',
    'Red Velvet',
    'MONSTA X',
    'GOT7',
    'SHINee',
    'NCT 127',
    'Enhypen',
    'TXT',
    'Seventeen',
    'MAMAMOO',
    'BIGBANG',
    'Itzy',
    'NMIXX'
  ],
  'classical': [
    'Frédéric Chopin',
    'Ludwig van Beethoven',
    'Wolfgang Amadeus Mozart',
    'Johann Sebastian Bach',
    'Claude Debussy',
    'Pyotr Ilyich Tchaikovsky',
    'Erik Satie',
    'Ludovico Einaudi',
    'Franz Schubert',
    'Johannes Brahms',
    'Sergei Rachmaninoff',
    'Franz Liszt',
    'Antonín Dvořák',
    'Edvard Grieg',
    'Maurice Ravel',
    'George Gershwin',
    'Antonio Vivaldi',
    'Gustav Mahler',
    'Camille Saint-Saëns',
    'Max Richter'
  ],
  'r&b': [
    'SZA',
    'Frank Ocean',
    'H.E.R.',
    'Daniel Caesar',
    'Summer Walker',
    'Bryson Tiller',
    'Jhene Aiko',
    'Khalid',
    'The Weeknd',
    'Beyoncé',
    'Rihanna',
    'Usher',
    'Miguel',
    'Chris Brown',
    'Alicia Keys',
    'Kehlani',
    'Lucky Daye',
    'Brent Faiyaz',
    'PJ Morton',
    '6LACK'
  ],
  'latin': [
    'Bad Bunny',
    'J Balvin',
    'Rosalía',
    'Maluma',
    'Karol G',
    'Ozuna',
    'Daddy Yankee',
    'Shakira',
    'Enrique Iglesias',
    'Marc Anthony',
    'Luis Fonsi',
    'Becky G',
    'Nicky Jam',
    'Farruko',
    'Anuel AA',
    'Lunay',
    'Sech',
    'Myke Towers',
    'Rauw Alejandro',
    'Camilo'
  ],
  'country': [
    'Luke Combs',
    'Morgan Wallen',
    'Zach Bryan',
    'Taylor Swift',
    'Chris Stapleton',
    'Kacey Musgraves',
    'Tyler Childers',
    'Carrie Underwood',
    'Blake Shelton',
    'Miranda Lambert',
    'Keith Urban',
    'Brad Paisley',
    'Garth Brooks',
    'Tim McGraw',
    'Florida Georgia Line',
    'Thomas Rhett',
    'Dierks Bentley',
    'Sam Hunt',
    'Maren Morris',
    'Eric Church'
  ],
  'metal': [
    'Metallica',
    'Slipknot',
    'Iron Maiden',
    'Avenged Sevenfold',
    'System Of A Down',
    'Bring Me The Horizon',
    'Megadeth',
    'Pantera',
    'Korn',
    'Ghost',
    'Judas Priest',
    'Lamb of God',
    'Gojira',
    'Rammstein',
    'Sabaton',
    'Slayer',
    'Anthrax',
    'Mastodon',
    'Trivium',
    'Disturbed'
  ],
  'blues': [
    'B.B. King',
    'Muddy Waters',
    'John Lee Hooker',
    'Stevie Ray Vaughan',
    'Etta James',
    'Buddy Guy',
    'Robert Johnson',
    'Howlin Wolf',
    'Eric Clapton',
    'Gary Clark Jr.',
    'Susan Tedeschi',
    'Joe Bonamassa',
    'Albert King',
    'Freddie King',
    'Keb Mo',
    'Otis Rush',
    'Taj Mahal',
    'Bonnie Raitt',
    'Rory Gallagher',
    'Christone Kingfish Ingram'
  ],
  'lo-fi': [
    'Jinsang',
    'Nujabes',
    'Idealism',
    'Joji',
    'potsu',
    'Kudasai',
    'eevee',
    'Tomppabeats',
    'Lofi Fruits Music',
    'Aso',
    'Saib',
    'Brock Berrigan',
    'Sleepy Fish',
    'Kupla',
    'Leavv',
    'Psalm Trees',
    'Birocratic',
    'Oatmello',
    'Blazo',
    'The Deli'
  ],
  'reggaeton': [
    'Bad Bunny',
    'J Balvin',
    'Daddy Yankee',
    'Karol G',
    'Ozuna',
    'Rauw Alejandro',
    'Anuel AA',
    'Nicky Jam',
    'Farruko',
    'Wisin y Yandel',
    'Don Omar',
    'Myke Towers',
    'Sech',
    'Lunay',
    'Feid',
    'Zion and Lennox',
    'Arcangel',
    'De La Ghetto',
    'Mora',
    'Chencho Corleone'
  ],
  'folk': [
    'Bon Iver',
    'Fleet Foxes',
    'Iron and Wine',
    'Sufjan Stevens',
    'Nick Drake',
    'Gregory Alan Isakov',
    'Big Thief',
    'Jose Gonzalez',
    'Mumford & Sons',
    'The Lumineers',
    'Caamp',
    'Hozier',
    'Lord Huron',
    'Bright Eyes',
    'Neutral Milk Hotel',
    'Simon & Garfunkel',
    'Joni Mitchell',
    'James Taylor',
    'Cat Stevens',
    'Paul Simon'
  ],
  'funk': [
    'James Brown',
    'Stevie Wonder',
    'Earth Wind and Fire',
    'Parliament',
    'Chic',
    'Bruno Mars',
    'Silk Sonic',
    'Prince',
    'George Clinton',
    'Bootsy Collins',
    'Sly & the Family Stone',
    'Kool & the Gang',
    'Gap Band',
    'Rick James',
    'Tower of Power',
    'Ohio Players',
    'Commodores',
    'Cameo',
    'Maze',
    'Con Funk Shun'
  ],
  'soul': [
    'Aretha Franklin',
    'Marvin Gaye',
    'Al Green',
    'Otis Redding',
    'Bill Withers',
    'Sam Cooke',
    'Erykah Badu',
    'Lauryn Hill',
    'Stevie Wonder',
    'Nina Simone',
    'Ray Charles',
    'Gladys Knight',
    'Whitney Houston',
    'Luther Vandross',
    'Smokey Robinson',
    'Phyllis Hyman',
    'Anita Baker',
    'Mary J. Blige',
    'D\'Angelo',
    'Maxwell'
  ],
  'indie': [
    'Arctic Monkeys',
    'Tame Impala',
    'Mac DeMarco',
    'Vampire Weekend',
    'Arcade Fire',
    'Beach House',
    'Bon Iver',
    'Phoebe Bridgers',
    'Modest Mouse',
    'The Shins',
    'The National',
    'Wilco',
    'Yo La Tengo',
    'Pavement',
    'Built to Spill',
    'Real Estate',
    'Kurt Vile',
    'Snail Mail',
    'Mitski',
    'Soccer Mommy'
  ],
  'punk': [
    'The Clash',
    'Ramones',
    'Sex Pistols',
    'Bad Religion',
    'NOFX',
    'Descendents',
    'The Misfits',
    'Dead Kennedys',
    'Black Flag',
    'Circle Jerks',
    'Buzzcocks',
    'Wire',
    'Gang of Four',
    'Television',
    'Stiff Little Fingers',
    'The Damned',
    'X',
    'Fear',
    'Husker Du',
    'Fugazi'
  ],
  'reggae': [
    'Bob Marley',
    'Damian Marley',
    'Burning Spear',
    'Peter Tosh',
    'Toots and the Maytals',
    'Sizzla',
    'Chronixx',
    'Steel Pulse',
    'Jimmy Cliff',
    'Lee Scratch Perry',
    'Barrington Levy',
    'Buju Banton',
    'Capleton',
    'Luciano',
    'Gregory Isaacs',
    'Freddie McGregor',
    'Dennis Brown',
    'Beenie Man',
    'Bounty Killer',
    'Soja'
  ],
};

const Map<String, String> _genreArtUrls = {
  'pop': 'assets/images/genres/01_pop.jpg',
  'rock': 'assets/images/genres/02_rock.jpg',
  'hip-hop': 'assets/images/genres/03_hiphop.jpg',
  'electronic': 'assets/images/genres/04_electronic.jpg',
  'jazz': 'assets/images/genres/05_jazz.jpg',
  'k-pop': 'assets/images/genres/06_kpop.jpg',
  'r&b': 'assets/images/genres/07_rnb.jpg',
  'latin': 'assets/images/genres/08_latin.jpg',
  'indie': 'assets/images/genres/09_indie.jpg',
  'afrobeat': 'assets/images/genres/10_afrobeat.jpg',
  'classical': 'assets/images/genres/11_classical.jpg',
  'country': 'assets/images/genres/12_country.jpg',
  'metal': 'assets/images/genres/13_metal.jpg',
  'blues': 'assets/images/genres/14_blues.jpg',
  'lo-fi': 'assets/images/genres/15_lofi.jpg',
  'reggaeton': 'assets/images/genres/16_reggaeton.jpg',
  'folk':
      'https://images.unsplash.com/photo-1448375240586-882707db888b?w=1400&q=80',
  'funk':
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1400&q=80',
  'soul':
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1400&q=80',
  'punk':
      'https://images.unsplash.com/photo-1503095396549-807759245b35?w=1400&q=80',
  'reggae':
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1400&q=80',
};

Alignment _genreImageAlignment(String genre) {
  switch (genre.trim().toLowerCase()) {
    case 'pop':
    case 'rock':
    case 'hip-hop':
    case 'jazz':
    case 'k-pop':
    case 'r&b':
    case 'metal':
    case 'blues':
    case 'afrobeat':
    case 'country':
      return Alignment.topCenter;
    default:
      return Alignment.center;
  }
}

class GenreTracksScreen extends StatefulWidget {
  final String genre;
  final String emoji;
  final LinearGradient gradient;

  const GenreTracksScreen({
    super.key,
    required this.genre,
    required this.emoji,
    required this.gradient,
  });

  @override
  State<GenreTracksScreen> createState() => _GenreTracksScreenState();
}

class _GenreTracksScreenState extends State<GenreTracksScreen> {
  List<dynamic> _tracks = [];
  bool _loading = true;
  bool _shuffleMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final genre = widget.genre.trim().toLowerCase();
      final artists = _genreArtists[genre] ?? [];

      List<dynamic> tracks = [];

      if (artists.isNotEmpty) {
        // Parallel search across top artists → ~150 real tracks
        final results = await Future.wait(
          artists.map(
            (a) => ApiService()
                .searchTracksWithFallback(a, limit: 20)
                .catchError((_) => <Map<String, dynamic>>[]),
          ),
        );
        final seen = <String>{};
        final artistCount = <String, int>{};
        for (final batch in results) {
          for (final t in batch) {
            final id = (t['track_id'] ??
                    t['spotify_id'] ??
                    t['deezer_id'] ??
                    t['id'] ??
                    '')
                .toString();
            if (id.isEmpty || !seen.add(id)) continue;
            final artist = (t['artist'] ?? '').toString().trim().toLowerCase();
            if (artist.isNotEmpty) {
              if ((artistCount[artist] ?? 0) >= 3) continue;
              artistCount[artist] = (artistCount[artist] ?? 0) + 1;
            }
            tracks.add(t);
            if (tracks.length >= 160) break;
          }
          if (tracks.length >= 160) break;
        }
        tracks.shuffle(Random());
      } else {
        // Fallback for unknown genre
        tracks = await ApiService().getCharts(genre: genre, limit: 100);
        if (tracks.isEmpty) {
          tracks =
              await ApiService().searchTracksWithFallback(genre, limit: 50);
        }
      }

      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;

    final first = Map<String, dynamic>.from(_tracks[0] as Map)
      ..['queue'] = _tracks;

    MiniPlayerOverlayController.forceVisible();
    await context.read<PlayerProvider>().openTrack(first);
    MiniPlayerOverlayController.forceVisible();
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleMode = !_shuffleMode;
      if (_shuffleMode) _tracks.shuffle();
    });
  }

  String _trackId(Map<String, dynamic> track) {
    return (track['spotify_track_id'] ??
            track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            track['id'] ??
            '')
        .toString();
  }

  void _showGenreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading:
                const Icon(Icons.play_arrow_rounded, color: Colors.white70),
            title: Text('Play all',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _playAll();
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded, color: Colors.white70),
            title:
                Text('Shuffle', style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _toggleShuffle();
              _playAll();
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Color get _accentColor => widget.gradient.colors.first;

  String get _genreSubtitle {
    const subtitles = <String, String>{
      'Pop': 'Catchy & bright',
      'Rock': 'Raw & loud',
      'Hip-Hop': 'Beats & bars',
      'Electronic': 'Pulse & energy',
      'Jazz': 'Smooth & soulful',
      'K-Pop': 'Bright & bold',
      'R&B': 'Smooth soul',
      'Latin': 'Rhythm & fire',
      'Indie': 'Raw & real',
      'Afrobeat': 'Groove & rhythm',
      'Classical': 'Timeless beauty',
      'Country': 'Roots & soul',
      'Metal': 'Heavy & loud',
      'Blues': 'Deep & soulful',
      'Lo-Fi': 'Chill & mellow',
      'Reggaeton': 'Dance & fire',
      'Folk': 'Acoustic & pure',
      'Funk': 'Groove & bass',
      'Soul': 'Deep feeling',
      'Punk': 'Fast & loud',
      'Reggae': 'Chill & roots',
    };
    return subtitles[widget.genre] ?? '';
  }

  String get _totalDuration {
    if (_loading || _tracks.isEmpty) return '';
    int totalMs = 0;
    for (final t in _tracks) {
      final ms = (t as Map?)?['duration_ms'];
      totalMs += ms is int ? ms : int.tryParse('$ms') ?? 0;
    }
    if (totalMs <= 0) return '';
    final h = totalMs ~/ 3600000;
    final m = (totalMs % 3600000) ~/ 60000;
    if (h > 0) return '${h}h ${m}m';
    return '${m} min';
  }

  void _showTrackOptions(BuildContext context, Map track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.favorite_border, color: Colors.white70),
            title: Text('Add to favorites',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final id = _trackId(Map<String, dynamic>.from(track));
              if (id.isEmpty) return;
              try {
                await ApiService().likeTrack(
                  id,
                  title: track['title']?.toString(),
                  artist: track['artist']?.toString(),
                  genre: widget.genre,
                );
                if (context.mounted) {
                  showSuccessSnackBar(context, 'Added to favorites');
                }
              } catch (_) {
                if (context.mounted) {
                  showErrorSnackBar(context, 'Could not add to favorites');
                }
              }
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.playlist_add_rounded, color: Colors.white70),
            title: Text('Add to playlist',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylist(
                context,
                track: Map<String, dynamic>.from(track),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: Colors.white70),
            title:
                Text('Share', style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showShareTrack(
                context,
                track: Map<String, dynamic>.from(track),
              );
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  String _fmt(dynamic ms) {
    final value = ms is int ? ms : int.tryParse('$ms') ?? 0;
    if (value <= 0) return '';
    return '${value ~/ 60000}:${((value % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final heroArt = _genreArtUrls[widget.genre.trim().toLowerCase()] ??
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1400&q=80';

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  heroArt.startsWith('assets/')
                      ? Image.asset(
                          heroArt,
                          fit: BoxFit.cover,
                          alignment: _genreImageAlignment(widget.genre),
                          errorBuilder: (_, __, ___) => Container(
                            decoration:
                                BoxDecoration(gradient: widget.gradient),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: heroArt,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            decoration:
                                BoxDecoration(gradient: widget.gradient),
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.55),
                          AppColors.bg.withOpacity(0.97),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.genre,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 38,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          if (!_loading &&
                              (_genreSubtitle.isNotEmpty ||
                                  _totalDuration.isNotEmpty)) ...[
                            const SizedBox(height: 3),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                if (_genreSubtitle.isNotEmpty)
                                  Text(
                                    _genreSubtitle,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.72),
                                    ),
                                  ),
                                if (_genreSubtitle.isNotEmpty &&
                                    _totalDuration.isNotEmpty)
                                  Text('·',
                                      style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.4))),
                                if (_totalDuration.isNotEmpty)
                                  Text(
                                    _totalDuration,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.72),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ACTION BAR
          if (!_loading && _tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    // Shuffle button
                    GestureDetector(
                      onTap: _toggleShuffle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _shuffleMode
                              ? _accentColor.withOpacity(0.18)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _shuffleMode
                                ? _accentColor.withOpacity(0.7)
                                : AppColors.border,
                          ),
                        ),
                        child: Icon(
                          Icons.shuffle_rounded,
                          size: 20,
                          color: _shuffleMode ? _accentColor : AppColors.text3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Play All (expanded)
                    Expanded(
                      child: GestureDetector(
                        onTap: _playAll,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.gradient.colors.first,
                                widget.gradient.colors.last,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.35),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 6),
                              Text('Play All',
                                  style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // More options button
                    GestureDetector(
                      onTap: () => _showGenreOptions(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: AppColors.text3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // TRACK LIST
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final track = _tracks[i] as Map<String, dynamic>? ?? {};
                  final trackMap = Map<String, dynamic>.from(track)
                    ..['queue'] = _tracks;

                  final title = trackMap['title']?.toString() ?? '';
                  final artist = trackMap['artist']?.toString() ?? '';
                  final cover = trackMap['cover_url']?.toString() ?? '';
                  final duration = _fmt(trackMap['duration_ms']);

                  return GestureDetector(
                    onTap: () async {
                      MiniPlayerOverlayController.forceVisible();
                      await context.read<PlayerProvider>().openTrack(trackMap);
                      MiniPlayerOverlayController.forceVisible();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      child: Row(children: [
                        // Track number
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.text3,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cover
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cover.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cover,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      width: 50,
                                      height: 50,
                                      color: AppColors.surface3),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 50,
                                    height: 50,
                                    color: AppColors.surface3,
                                    child: const Icon(Icons.music_note,
                                        color: AppColors.text3, size: 22),
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: AppColors.surface3,
                                  child: const Icon(Icons.music_note,
                                      color: AppColors.text3, size: 22),
                                ),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  )),
                              const SizedBox(height: 2),
                              Text(artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.text3,
                                  )),
                            ],
                          ),
                        ),
                        if (duration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(duration,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.text3)),
                        ],
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showTrackOptions(context, trackMap),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.more_vert_rounded,
                                color: AppColors.text3, size: 18),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
