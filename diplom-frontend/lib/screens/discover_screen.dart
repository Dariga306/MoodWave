import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'modals.dart';
import 'player_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final int initialTab;
  final String? initialGenre;
  const DiscoverScreen({super.key, this.initialTab = 0, this.initialGenre});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<dynamic> _globalTop = [];
  List<dynamic> _trending = [];
  List<dynamic> _viral = [];
  List<dynamic> _newReleases = [];
  List<dynamic> _rising = [];
  String _contextCity = '';
  String _source = 'global';
  Timer? _refreshTimer;

  int _activeTab = 0;
  late final TabController _tabCtrl;

  static const _tabs = [
    '🌐 Global',
    '🔥 Viral',
    '🆕 New Releases',
    '📈 Rising'
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, _tabs.length - 1);
    if (widget.initialGenre != null && widget.initialGenre!.isNotEmpty) {
      _activeTab = 0;
    }
    _tabCtrl = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _activeTab,
    )..addListener(() {
        if (!_tabCtrl.indexIsChanging) return;
        setState(() => _activeTab = _tabCtrl.index);
      });
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fallbackCity =
          context.read<AuthProvider>().user?['city']?.toString().trim() ?? '';
      final data = await ApiService().getDiscover(
        city: fallbackCity.isEmpty ? null : fallbackCity,
      );
      if (!mounted) return;
      setState(() {
        _globalTop = data['global_top'] as List? ?? [];
        _trending = data['trending'] as List? ?? [];
        _viral = data['viral'] as List? ?? [];
        _newReleases = data['new_releases'] as List? ?? [];
        _rising = data['rising'] as List? ?? _trending;
        _contextCity = data['city']?.toString() ?? '';
        _source = data['source']?.toString() ?? 'global';
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  List<dynamic> get _currentTracks => switch (_activeTab) {
        0 => _globalTop,
        1 => _viral,
        2 => _newReleases,
        _ => _rising,
      };

  Map<String, dynamic>? get _heroTrack {
    final list = _currentTracks;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  String _fmt(dynamic ms) {
    final v = ms is int ? ms : (int.tryParse('$ms') ?? 0);
    if (v <= 0) return '';
    return '${v ~/ 60000}:${((v % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purpleLight,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildTabInfo()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(tabCtrl: _tabCtrl, tabs: _tabs),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (_currentTracks.isEmpty)
              SliverFillRemaining(child: _EmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TrackRow(
                    index: i,
                    track: Map<String, dynamic>.from(_currentTracks[i] as Map)
                      ..['queue'] = _currentTracks,
                    fmt: _fmt,
                  ),
                  childCount: _currentTracks.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabInfo() {
    final count = _currentTracks.length;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(_tabSub,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text2)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count tracks',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text3)),
            ),
          ]),
          if (_contextCity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _source == 'city'
                  ? 'Based on $_contextCity plus global chart leaders'
                  : 'Showing worldwide chart leaders for $_contextCity',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.text3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GlassButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: ShaderMask(
                  shaderCallback: (r) =>
                      AppColors.titleGradient.createShader(r),
                  child: Text('Discover',
                      style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.6)),
                ),
              ),
            ),
            _GlassButton(icon: Icons.refresh_rounded, onTap: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.purpleLight),
        ),
      );
    }
    final hero = _heroTrack;
    if (hero == null) return const SizedBox.shrink();

    final coverUrl = hero['cover_url']?.toString();
    final title = hero['title']?.toString() ?? '';
    final artist = hero['artist']?.toString() ?? '';
    final badge = hero['badge']?.toString();
    final plays = hero['play_count'];
    final playsStr = plays != null && plays > 0 ? _fmtPlays(plays) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: hero))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.surface2),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.surface2),
                  )
                else
                  Container(
                      decoration:
                          const BoxDecoration(gradient: AppColors.gradMixed)),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.3, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (playsStr != null)
                          _MetricBadge(
                            label: '$playsStr live',
                            color: const Color(0xFFf472b6),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(100)),
                          child: Text(_tabLabel,
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ]),
                      const Spacer(),
                      Text(title,
                          style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              shadows: const [Shadow(blurRadius: 8)]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(artist,
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70)),
                        if (playsStr != null) ...[
                          const SizedBox(width: 10),
                          Text('· $playsStr listening now',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: Colors.white54)),
                        ],
                        if (badge != null && badge.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            badge == 'VIRAL'
                                ? 'rising fast'
                                : badge == 'NEW'
                                    ? 'fresh release'
                                    : 'momentum up',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _PlayButton(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerScreen(track: hero)))),
                        const SizedBox(width: 10),
                        _GlassButton(
                          icon: Icons.more_horiz_rounded,
                          onTap: () => _showTrackActions(context, hero),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _tabContexts = [
    ('🌍 Global Charts', 'What the world plays right now'),
    ('🔥 Viral Hits', 'Spreading fast everywhere'),
    ('🆕 New Releases', 'Fresh drops this week'),
    ('📈 Rising', 'Gaining momentum now'),
  ];

  String get _tabLabel =>
      _activeTab < _tabContexts.length ? _tabContexts[_activeTab].$1 : '';
  String get _tabSub =>
      _activeTab < _tabContexts.length ? _tabContexts[_activeTab].$2 : '';

  String _fmtPlays(dynamic n) {
    final v = n is int ? n : (int.tryParse('$n') ?? 0);
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;
  final List<String> tabs;
  const _TabBarDelegate({required this.tabCtrl, required this.tabs});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.bg.withOpacity(0.85),
          alignment: Alignment.center,
          child: TabBar(
            controller: tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.only(left: 16),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
                gradient: AppColors.gradNeonPurple,
                borderRadius: BorderRadius.circular(100)),
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            labelStyle:
                GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.text2,
            tabs: tabs.map((t) => Tab(text: t, height: 36)).toList(),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

class _TrackRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> track;
  final String Function(dynamic) fmt;

  const _TrackRow(
      {required this.index, required this.track, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final title = track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? '';
    final coverUrl = track['cover_url']?.toString();
    final dur = fmt(track['duration_ms']);
    final plays = track['play_count'];
    final growth = track['growth_percent'];
    final isTopTen = index < 10;

    final rankColors = [
      const Color(0xFFf59e0b),
      const Color(0xFF94a3b8),
      const Color(0xFFc2774a),
    ];
    final rankColor = index < 3 ? rankColors[index] : AppColors.text3;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isTopTen ? Colors.white.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isTopTen ? Colors.white.withOpacity(0.06) : Colors.transparent,
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: index < 3
                ? Text(['🥇', '🥈', '🥉'][index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16))
                : Text('${index + 1}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: rankColor)),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (_, __, ___) => _CoverFallback(),
                    )
                  : _CoverFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text2)),
                ),
                if (plays != null && plays > 0) ...[
                  Text(' · ${_fmtShort(plays)} live',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.text3)),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          if (plays != null && plays > 0)
            _MetricBadge(
              label: _fmtShort(plays),
              color: index < 3 ? rankColor : AppColors.purpleLight,
              small: true,
            ),
          if (growth is num && growth > 0) ...[
            const SizedBox(width: 6),
            _MetricBadge(
              label: '+${growth.toInt()}%',
              color: const Color(0xFF22c55e),
              small: true,
            ),
          ],
          if (dur.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dur,
                style:
                    GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showTrackActions(context, track),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.text3.withOpacity(0.86)),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtShort(dynamic n) {
    final v = n is int ? n : (int.tryParse('$n') ?? 0);
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  const _MetricBadge(
      {required this.label, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: small ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3)),
      );
}

void _showTrackActions(BuildContext context, Map<String, dynamic> track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF12071f),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            title: Text('Play now',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              );
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.playlist_play_rounded, color: Colors.white),
            title: Text('Add to playlist',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylist(context, track: track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: Colors.white),
            title: Text('Share track',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showShareTrack(context, track: track);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: AppColors.gradNeonPurple,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neonPurple.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text('Play',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      );
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      );
}

class _CoverFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface2,
        child: const Center(child: Text('🎵', style: TextStyle(fontSize: 20))),
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('😶‍🌫️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Could not load discover',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text('Tap to retry',
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.purpleLight)),
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📻', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Nothing here yet',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Play more tracks to see your discover feed',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
        ]),
      );
}
