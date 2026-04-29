import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'artist_screen.dart';
import 'player_screen.dart';
import '../widgets/common_widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<_WeeklyStatsSection> _sections = const [];
  List<Map<String, dynamic>> _genreMixes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ApiService();

    try {
      final results = await Future.wait<dynamic>([
        api.getWeeklyStatsRecaps(weeks: 6),
        api.getGenreMixes(limit: 6, tracksPerMix: 12),
      ]);

      if (!mounted) return;

      setState(() {
        final loadedSections = (results[0] as List? ?? const [])
            .whereType<Map>()
            .map((item) =>
                _WeeklyStatsSection.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        _sections = loadedSections
            .where((section) => !section.isEmpty || section.isCurrentWeek)
            .toList();
        _genreMixes = (results[1] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load listening stats.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF181818),
              Color(0xFF101011),
              Color(0xFF0B0B0C),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.green,
                    strokeWidth: 2.2,
                  ),
                )
              : _error != null
                  ? _StatsErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.green,
                      backgroundColor: const Color(0xFF181818),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StatsHeader(
                                    onBack: () => Navigator.of(context).pop(),
                                  ),
                                  const SizedBox(height: 28),
                                  if (sections.isNotEmpty) ...[
                                    _WeekSection(
                                      section: sections.first,
                                      title: 'This week',
                                      showDateUnderTitle: true,
                                      onShare: () =>
                                          _shareWeekSummary(sections.first),
                                      onOpenTopArtists: () =>
                                          _openTopArtists(sections.first),
                                      onOpenTopTracks: () =>
                                          _openTopTracks(sections.first),
                                    ),
                                    if (sections.length > 1)
                                      const SizedBox(height: 30),
                                  ],
                                  ...sections
                                      .skip(1)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final section = entry.value;
                                    final title = index == 0
                                        ? 'Last week'
                                        : section.rangeLabel;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                          bottom: index == sections.length - 2
                                              ? 0
                                              : 28),
                                      child: _WeekSection(
                                        section: section,
                                        title: title,
                                        showDateUnderTitle: index == 0,
                                        onShare: () =>
                                            _shareWeekSummary(section),
                                        onOpenTopArtists: () =>
                                            _openTopArtists(section),
                                        onOpenTopTracks: () =>
                                            _openTopTracks(section),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 120),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  void _openTopArtists(_WeeklyStatsSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TopArtistsScreen(
          section: section,
          mixes: _genreMixes,
        ),
      ),
    );
  }

  void _openTopTracks(_WeeklyStatsSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TopTracksScreen(section: section),
      ),
    );
  }

  Future<void> _shareWeekSummary(_WeeklyStatsSection section) async {
    final topArtist = section.topArtists.isNotEmpty
        ? section.topArtists.first.name
        : '—';
    final topTrack = section.topTracks.isNotEmpty
        ? '${section.topTracks.first.title} — ${section.topTracks.first.artist}'
        : '—';
    final text =
        '🎵 ${section.rangeLabel}\n'
        '${section.insightTitle}\n\n'
        'Plays: ${section.totalPlays}  |  Artists: ${section.uniqueArtists}  |  Tracks: ${section.uniqueTracks}\n'
        'Top artist: $topArtist\n'
        'Top track: $topTrack\n\n'
        'via MoodWave';
    await Share.share(text, subject: 'My MoodWave Week');
  }

}

class _StatsHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _StatsHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        Text(
          'Listening Stats',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  final _WeeklyStatsSection section;
  final String title;
  final bool showDateUnderTitle;
  final VoidCallback onShare;
  final VoidCallback onOpenTopArtists;
  final VoidCallback onOpenTopTracks;

  const _WeekSection({
    required this.section,
    required this.title,
    required this.showDateUnderTitle,
    required this.onShare,
    required this.onOpenTopArtists,
    required this.onOpenTopTracks,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.68),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (showDateUnderTitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      section.rangeLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _RoundActionButton(
              icon: Icons.ios_share_outlined,
              onTap: onShare,
              small: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (section.isEmpty)
          _EmptyWeekCard(section: section)
        else ...[
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Top artist',
                  title:
                      section.topArtists.firstOrNull?.name ?? 'No artist yet',
                  subtitle: section.topArtists.isNotEmpty
                      ? '${section.topArtists.first.plays} plays'
                      : 'Play more tracks to unlock this',
                  imageUrl: section.topArtists.firstOrNull?.imageUrl,
                  circularArtwork: true,
                  onTap: section.topArtists.isEmpty ? null : onOpenTopArtists,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: 'Top track',
                  title: section.topTracks.firstOrNull?.title ?? 'No track yet',
                  subtitle: section.topTracks.isNotEmpty
                      ? section.topTracks.first.artist
                      : 'Play more tracks to unlock this',
                  imageUrl: section.topTracks.firstOrNull?.imageUrl,
                  circularArtwork: false,
                  onTap: section.topTracks.isEmpty ? null : onOpenTopTracks,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InsightHeroCard(section: section),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool circularArtwork;
  final VoidCallback? onTap;

  const _SummaryTile({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.circularArtwork,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 198,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.42),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.22,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _ArtworkThumb(
                    imageUrl: imageUrl,
                    size: 72,
                    circular: circularArtwork,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightHeroCard extends StatelessWidget {
  final _WeeklyStatsSection section;

  const _InsightHeroCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _HeroArtwork(images: section.heroImages),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.insightTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.insightSubtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  final List<String> images;

  const _HeroArtwork({required this.images});

  @override
  Widget build(BuildContext context) {
    final unique = images.where((url) => url.trim().isNotEmpty).toList();
    if (unique.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2A2C),
              Color(0xFF151516),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.28),
            size: 72,
          ),
        ),
      );
    }

    final clamped = unique.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 300,
        child: _buildLayout(clamped),
      ),
    );
  }

  Widget _buildLayout(List<String> images) {
    if (images.length == 1) {
      return _CoverImage(imageUrl: images[0]);
    }

    if (images.length == 2) {
      return Row(
        children: [
          Expanded(child: _CoverImage(imageUrl: images[0])),
          const SizedBox(width: 2),
          Expanded(child: _CoverImage(imageUrl: images[1])),
        ],
      );
    }

    if (images.length == 3) {
      return Row(
        children: [
          Expanded(flex: 5, child: _CoverImage(imageUrl: images[0])),
          const SizedBox(width: 2),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: _CoverImage(imageUrl: images[1])),
                const SizedBox(height: 2),
                Expanded(child: _CoverImage(imageUrl: images[2])),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 4,
      itemBuilder: (_, index) => _CoverImage(imageUrl: images[index]),
    );
  }
}

class _MixCard extends StatelessWidget {
  final Map<String, dynamic> mix;

  const _MixCard({required this.mix});

  @override
  Widget build(BuildContext context) {
    final title = mix['title']?.toString() ?? 'Mix';
    final subtitle = mix['subtitle']?.toString() ?? '';
    final coverUrl = mix['cover_url']?.toString();
    final firstTrack = ((mix['tracks'] as List?) ?? const [])
        .whereType<Map>()
        .map((track) => Map<String, dynamic>.from(track))
        .firstOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: firstTrack == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PlayerScreen(track: firstTrack)),
                );
              },
        child: Ink(
          width: 146,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 122,
                  height: 122,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _mixFallback(),
                        )
                      : _mixFallback(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mixFallback() {
    return Container(
      color: const Color(0xFF2A2A2C),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}

class _EmptyWeekCard extends StatelessWidget {
  final _WeeklyStatsSection section;

  const _EmptyWeekCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            'Not enough listening data yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Play a few more tracks and come back to see your weekly recap.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.38,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopArtistsScreen extends StatelessWidget {
  final _WeeklyStatsSection section;
  final List<Map<String, dynamic>> mixes;

  const _TopArtistsScreen({
    required this.section,
    required this.mixes,
  });

  @override
  Widget build(BuildContext context) {
    final count = section.uniqueArtists;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHeader(
                      title: 'Top Artists',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      section.rangeLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This week you listened to $count ${count == 1 ? 'artist' : 'artists'}',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 22),
                    ...section.topArtists.asMap().entries.map((entry) {
                      return _ArtistRankRow(
                        rank: entry.key + 1,
                        artist: entry.value,
                      );
                    }),
                    if (mixes.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 1),
                      const SizedBox(height: 22),
                      Text(
                        'Similar to your favorite artists',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 214,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: mixes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, index) =>
                              _MixCard(mix: mixes[index]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTracksScreen extends StatelessWidget {
  final _WeeklyStatsSection section;

  const _TopTracksScreen({required this.section});

  @override
  Widget build(BuildContext context) {
    final count = section.uniqueTracks;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHeader(
                      title: 'Top Tracks',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      section.rangeLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This week you played $count ${count == 1 ? 'track' : 'tracks'}',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 22),
                    ...section.topTracks.asMap().entries.map((entry) {
                      return _TrackRankRow(
                        rank: entry.key + 1,
                        track: entry.value,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _DetailHeader({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }
}

class _ArtistRankRow extends StatelessWidget {
  final int rank;
  final _ArtistRank artist;

  const _ArtistRankRow({
    required this.rank,
    required this.artist,
  });

  Future<void> _openArtist(BuildContext context) async {
    final name = artist.name.trim();
    if (name.isEmpty || name == 'Unknown artist') return;

    try {
      var candidates = await ApiService().searchArtistsList(name, limit: 8);
      if (!context.mounted) return;

      if (candidates.isEmpty) {
        final firstWord = name
            .split(RegExp(r'\s+'))
            .firstWhere((w) => w.length > 2, orElse: () => '');
        if (firstWord.isNotEmpty) {
          candidates =
              await ApiService().searchArtistsList(firstWord, limit: 8);
          if (!context.mounted) return;
        }
      }

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find artist.')),
        );
        return;
      }

      candidates.sort((a, b) {
        final aName = (a['name']?.toString() ?? '').toLowerCase();
        final bName = (b['name']?.toString() ?? '').toLowerCase();
        final target = name.toLowerCase();
        final aScore =
            (aName == target ? 2 : 0) + (aName.startsWith(target) ? 1 : 0);
        final bScore =
            (bName == target ? 2 : 0) + (bName.startsWith(target) ? 1 : 0);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return aName.compareTo(bName);
      });
      final artistData = candidates.first;
      final artistId = artistData['id']?.toString();
      if (!context.mounted || artistId == null || artistId.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArtistScreen(
            artistId: artistId,
            artistName: artistData['name']?.toString() ?? name,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open artist right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openArtist(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _ArtworkThumb(
                imageUrl: artist.imageUrl,
                size: 72,
                circular: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  artist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openArtist(context),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRankRow extends StatelessWidget {
  final int rank;
  final _TrackRank track;

  const _TrackRankRow({
    required this.rank,
    required this.track,
  });

  void _showActions(BuildContext context) {
    showTrackMenu(
      context,
      track.track,
      onPlayNow: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track.track)),
        );
      },
      onGoToArtist: () async {
        final candidates =
            await ApiService().searchArtistsList(track.artist, limit: 6);
        if (!context.mounted || candidates.isEmpty) return;
        final artistData = candidates.first;
        final artistId = artistData['id']?.toString();
        if (artistId == null || artistId.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistScreen(
              artistId: artistId,
              artistName: artistData['name']?.toString() ?? track.artist,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerScreen(track: track.track)),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '$rank',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _ArtworkThumb(
                imageUrl: track.imageUrl,
                size: 84,
                circular: false,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.plays} ${track.plays == 1 ? 'play' : 'plays'}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: () => _showActions(context),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _StatsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.36),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  const _RoundActionButton({
    required this.icon,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 36.0 : 42.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.92),
            size: small ? 18 : 20,
          ),
        ),
      ),
    );
  }
}

class _ArtworkThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool circular;

  const _ArtworkThumb({
    required this.imageUrl,
    required this.size,
    required this.circular,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(circular ? size : 12);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF2B2B2E),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white54,
          size: 24,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String imageUrl;

  const _CoverImage({required this.imageUrl});

  static Widget _fallback() => Container(
        color: const Color(0xFF252527),
        child: const Center(
          child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 30),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty || imageUrl == 'null') return _fallback();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _fallback(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }
}

class _ArtistRank {
  final String name;
  final int plays;
  final String? imageUrl;

  const _ArtistRank({
    required this.name,
    required this.plays,
    required this.imageUrl,
  });

  factory _ArtistRank.fromMap(Map<String, dynamic> map) {
    return _ArtistRank(
      name: map['name']?.toString() ?? 'Unknown artist',
      plays: (map['plays'] as num?)?.toInt() ?? 0,
      imageUrl: map['image_url']?.toString(),
    );
  }
}

class _TrackRank {
  final String title;
  final String artist;
  final int plays;
  final String? imageUrl;
  final Map<String, dynamic> track;

  const _TrackRank({
    required this.title,
    required this.artist,
    required this.plays,
    required this.imageUrl,
    required this.track,
  });

  factory _TrackRank.fromMap(Map<String, dynamic> map) {
    final rawTrack = map['track'] is Map
        ? Map<String, dynamic>.from(map['track'] as Map)
        : <String, dynamic>{};
    return _TrackRank(
      title: map['title']?.toString() ?? 'Unknown track',
      artist: map['artist']?.toString() ?? '',
      plays: (map['plays'] as num?)?.toInt() ?? 0,
      imageUrl: map['image_url']?.toString(),
      track: rawTrack,
    );
  }
}

class _WeeklyStatsSection {
  final DateTime start;
  final DateTime end;
  final int totalPlays;
  final int uniqueArtists;
  final int uniqueTracks;
  final List<_ArtistRank> topArtists;
  final List<_TrackRank> topTracks;
  final List<String> heroImages;
  final String insightTitle;
  final String insightSubtitle;
  final String rangeLabel;
  final bool isCurrentWeek;

  const _WeeklyStatsSection({
    required this.start,
    required this.end,
    required this.totalPlays,
    required this.uniqueArtists,
    required this.uniqueTracks,
    required this.topArtists,
    required this.topTracks,
    required this.heroImages,
    required this.insightTitle,
    required this.insightSubtitle,
    required this.rangeLabel,
    required this.isCurrentWeek,
  });

  bool get isEmpty => totalPlays == 0;

  factory _WeeklyStatsSection.fromMap(Map<String, dynamic> map) {
    final startRaw = map['start_date']?.toString();
    final endRaw = map['end_date']?.toString();
    final insight = map['insight'] is Map
        ? Map<String, dynamic>.from(map['insight'] as Map)
        : <String, dynamic>{};

    return _WeeklyStatsSection(
      start: startRaw != null
          ? DateTime.tryParse(startRaw) ?? DateTime.now()
          : DateTime.now(),
      end: endRaw != null
          ? DateTime.tryParse(endRaw) ?? DateTime.now()
          : DateTime.now(),
      totalPlays: (map['total_plays'] as num?)?.toInt() ?? 0,
      uniqueArtists: (map['unique_artists'] as num?)?.toInt() ?? 0,
      uniqueTracks: (map['unique_tracks'] as num?)?.toInt() ?? 0,
      topArtists: ((map['top_artists'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => _ArtistRank.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      topTracks: ((map['top_tracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => _TrackRank.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      heroImages: ((map['hero_images'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      insightTitle: insight['title']?.toString() ?? '',
      insightSubtitle: insight['subtitle']?.toString() ?? '',
      rangeLabel: map['range_label']?.toString() ?? '',
      isCurrentWeek: map['is_current_week'] == true,
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
