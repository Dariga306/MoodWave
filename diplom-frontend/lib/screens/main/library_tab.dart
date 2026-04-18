import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../artist_screen.dart';
import '../playlist_screen.dart';
import '../profile_tab_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _filter = 0; // 0=All, 1=Playlists, 2=Artists
  final _filters = ['All', 'Playlists', 'Artists'];

  List<dynamic> _playlists = [];
  List<Map<String, dynamic>> _artists = [];
  bool _loading = true;
  bool _artistsLoaded = false;
  bool _artistsLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getPlaylists();
      if (!mounted) return;
      setState(() { _playlists = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadArtists() async {
    if (_artistsLoaded) return;
    setState(() => _artistsLoading = true);
    try {
      final raw = await ApiService().getFollowedArtistsDetails();
      if (!mounted) return;
      setState(() {
        _artists = raw.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _artistsLoaded = true;
        _artistsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _artistsLoaded = true; _artistsLoading = false; });
    }
  }

  void _onFilterChanged(int i) {
    setState(() => _filter = i);
    if (i == 2) _loadArtists();
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Playlist', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.purple)),
            filled: true, fillColor: AppColors.glass,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Create', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ApiService().createPlaylist(ctrl.text.trim());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(children: [
                    // Header row: avatar + title + search + create
                    Row(children: [
                      // Avatar → profile
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ProfileTabScreen())),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.purple.withOpacity(0.4), width: 1.5),
                          ),
                          child: Center(child: Text(initial,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Your Library',
                          style: GoogleFonts.outfit(
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: AppColors.text, letterSpacing: -0.3)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _createPlaylist,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradPurple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Filter chips
                    SizedBox(
                      height: 34,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _onFilterChanged(i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: _filter == i ? AppColors.gradPurple : null,
                              color: _filter == i ? null : AppColors.glass,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: _filter == i ? AppColors.purple : AppColors.border),
                            ),
                            child: Text(_filters[i],
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _filter == i ? Colors.white : AppColors.text2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)),
              )

            // ── Artists filter ──────────────────────────────────────
            else if (_filter == 2 && _artistsLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)),
              )

            else if (_filter == 2)
              _artists.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🎤', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No followed artists yet',
                              style: GoogleFonts.outfit(
                                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 6),
                          Text('Follow artists to see them here',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                        ]),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final artist = _artists[i];
                          final name = (artist['name'] ?? 'Unknown Artist').toString();
                          final pic = artist['picture_medium']?.toString()
                              ?? artist['picture']?.toString();
                          final fans = artist['nb_fan'] as int?;
                          final artistId = artist['id'];
                          final fansStr = fans != null
                              ? (fans >= 1000000
                                  ? '${(fans / 1000000).toStringAsFixed(1)}M fans'
                                  : fans >= 1000
                                      ? '${(fans / 1000).toStringAsFixed(0)}K fans'
                                      : '$fans fans')
                              : 'Artist';
                          return GestureDetector(
                            onTap: () {
                              if (artistId != null) {
                                Navigator.push(ctx, MaterialPageRoute(
                                  builder: (_) => ArtistScreen(
                                    artistId: artistId.toString(),
                                    artistName: name,
                                  ),
                                ));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                              child: Row(children: [
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradPink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: pic != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                              imageUrl: pic, fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Center(
                                                  child: Text(name[0].toUpperCase(),
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 20, fontWeight: FontWeight.w700,
                                                          color: Colors.white)))))
                                      : Center(
                                          child: Text(name[0].toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                  fontSize: 20, fontWeight: FontWeight.w700,
                                                  color: Colors.white))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: GoogleFonts.outfit(
                                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                                  Text(fansStr, style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                                ])),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 20),
                              ]),
                            ),
                          );
                        },
                        childCount: _artists.length,
                      ),
                    )

            // ── Playlists (All / Playlists filter) ─────────────────
            else if (_playlists.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🎵', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 14),
                    Text('Your library is empty',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text('Create your first playlist',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _createPlaylist,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(gradient: AppColors.primaryBtn, borderRadius: BorderRadius.circular(14)),
                        child: Text('Create Playlist',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PlaylistItem(
                    playlist: _playlists[i] as Map<String, dynamic>,
                    onRefresh: _load,
                  ),
                  childCount: _playlists.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback onRefresh;
  const _PlaylistItem({required this.playlist, required this.onRefresh});

  void _showOptions(BuildContext context) {
    final id = playlist['id'] as int? ?? 0;
    final title = (playlist['title'] ?? 'Untitled').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(title,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 8),
              _menuItem(context, Icons.edit_rounded, 'Rename', () {
                Navigator.pop(context);
                _renamePlaylist(context, id, title);
              }),
              _menuItem(context, Icons.share_rounded, 'Share', () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: 'Playlist: $title'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }),
              _menuItem(context, Icons.delete_rounded, 'Delete', () {
                Navigator.pop(context);
                _deletePlaylist(context, id);
              }, color: Colors.redAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      VoidCallback onTap, {Color? color}) {
    final c = color ?? AppColors.text;
    return ListTile(
      leading: Icon(icon, size: 22, color: c),
      title: Text(label, style: GoogleFonts.outfit(fontSize: 15, color: c)),
      onTap: onTap,
    );
  }

  void _renamePlaylist(BuildContext context, int id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Playlist',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.purple)),
            filled: true, fillColor: AppColors.glass,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true && ctrl.text.trim().isNotEmpty) {
        try {
          await ApiService().updatePlaylist(id, title: ctrl.text.trim());
          onRefresh();
        } catch (_) {}
      }
    });
  }

  void _deletePlaylist(BuildContext context, int id) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Playlist',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.outfit(color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true) {
        try {
          await ApiService().deletePlaylist(id);
          onRefresh();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = playlist['id'] as int? ?? 0;
    final title = playlist['title'] ?? 'Untitled';
    final trackCount = playlist['track_count'] ?? playlist['tracks_count'] ?? 0;
    final coverUrl = playlist['cover_url'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaylistScreen(
            playlistId: id,
            playlistTitle: title.toString(),
          ))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(children: [
          // Cover
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const Center(child: Text('🎵', style: TextStyle(fontSize: 22)))))
                : const Center(child: Text('🎵', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              Text('Playlist · $trackCount songs',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ]),
          ),
          GestureDetector(
            onTap: () => _showOptions(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.text3),
            ),
          ),
        ]),
      ),
    );
  }
}
