import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filter = 0;
  final _filters = ['All', 'Matches', 'Friends'];
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getNotifications();
      if (!mounted) return;
      setState(() {
        _notifs = (data['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 0) return _notifs;
    if (_filter == 1) return _notifs.where((n) => n['type'] == 'match').toList();
    if (_filter == 2) return _notifs.where((n) => n['type'] == 'friend_request').toList();
    return _notifs;
  }

  void _removeNotif(String id) {
    setState(() => _notifs.removeWhere((n) => n['id'] == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Notifications', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  if (_notifs.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _notifs.clear()),
                      child: Text('Clear all', style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.purpleLight)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                itemCount: _filters.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: _filter == i ? AppColors.gradPurple : null,
                      color: _filter == i ? null : AppColors.glass,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: _filter == i ? AppColors.purple : AppColors.border),
                    ),
                    child: Text(_filters[i], style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _filter == i ? Colors.white : AppColors.text2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight))
                  : _filtered.isEmpty
                      ? _EmptyState(filterName: _filters[_filter])
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.purpleLight,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final n = _filtered[i];
                              if (n['type'] == 'friend_request') {
                                return _FriendRequestCard(
                                  key: ValueKey(n['id']),
                                  notif: n,
                                  onDismiss: () => _removeNotif(n['id'] as String),
                                );
                              }
                              return _MatchCard(notif: n);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filterName;
  const _EmptyState({required this.filterName});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔔', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text('No notifications yet',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
      const SizedBox(height: 6),
      Text(
        filterName == 'All'
            ? 'Matches and friend requests will appear here'
            : 'No $filterName notifications yet',
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _MatchCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final name = notif['user_name'] as String? ?? '?';
    final initial = notif['user_initial'] as String? ?? '?';
    final pct = notif['similarity_pct'] as int? ?? 0;
    final city = notif['city'] as String? ?? '';
    final time = notif['time'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(gradient: AppColors.gradPink, shape: BoxShape.circle),
            child: Center(child: Text(initial, style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
          Positioned(bottom: -2, right: -2,
            child: Container(width: 20, height: 20,
              decoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2)),
              child: const Center(child: Text('🎵', style: TextStyle(fontSize: 9))))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(
            style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: AppColors.text),
            children: [
              TextSpan(text: '$pct% match found — meet '),
              TextSpan(text: name,
                  style: GoogleFonts.outfit(color: AppColors.purpleLight, fontWeight: FontWeight.w600)),
              if (city.isNotEmpty) TextSpan(text: ' from $city'),
            ],
          )),
          const SizedBox(height: 4),
          Text(time, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
      ]),
    );
  }
}

class _FriendRequestCard extends StatefulWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onDismiss;
  const _FriendRequestCard({super.key, required this.notif, required this.onDismiss});
  @override
  State<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<_FriendRequestCard> {
  bool _loading = false;
  String? _result; // 'accepted' | 'declined'

  Future<void> _accept() async {
    final userId = widget.notif['user_id'] as int;
    setState(() => _loading = true);
    try {
      await ApiService().acceptFriendRequest(userId);
      setState(() { _result = 'accepted'; _loading = false; });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not accept request', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF3d0000),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _decline() async {
    final userId = widget.notif['user_id'] as int;
    setState(() => _loading = true);
    try {
      await ApiService().declineFriendRequest(userId);
      setState(() { _result = 'declined'; _loading = false; });
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.notif['user_name'] as String? ?? '?';
    final initial = widget.notif['user_initial'] as String? ?? '?';
    final time = widget.notif['time'] as String? ?? '';

    return AnimatedOpacity(
      opacity: _result != null ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(width: 46, height: 46,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)]),
                shape: BoxShape.circle),
              child: Center(child: Text(initial, style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
            Positioned(bottom: -2, right: -2,
              child: Container(width: 20, height: 20,
                decoration: BoxDecoration(color: const Color(0xFFf59e0b), shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2)),
                child: const Center(child: Text('+', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name sent you a friend request',
                style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: AppColors.text)),
            if (_result == null) ...[
              const SizedBox(height: 10),
              _loading
                  ? const SizedBox(height: 36, child: Center(
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight))))
                  : Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: _accept,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(gradient: AppColors.gradPurple, borderRadius: BorderRadius.circular(10)),
                          child: Text('Accept', textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))))),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: _decline,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border)),
                          child: Text('Decline', textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))))),
                    ]),
            ] else ...[
              const SizedBox(height: 6),
              Text(_result == 'accepted' ? '✓ Friend added' : '✗ Request declined',
                  style: GoogleFonts.outfit(fontSize: 12,
                      color: _result == 'accepted' ? const Color(0xFF4ade80) : AppColors.text3)),
            ],
            const SizedBox(height: 4),
            Text(time, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ])),
        ]),
      ),
    );
  }
}
