import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import 'notification_settings_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filter = 0;
  final _filters = ['All', 'Matches', 'Friends', 'Music'];
  List<Map<String, dynamic>> _notifs = [];
  final Set<String> _readIds = {};
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
        _notifs =
            (data['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 0) return _notifs;
    if (_filter == 1)
      return _notifs
          .where((n) =>
              n['type'] == 'match' ||
              n['type'] == 'taste_match' ||
              n['type'] == 'like')
          .toList();
    if (_filter == 2)
      return _notifs
          .where((n) =>
              n['type'] == 'friend_request' ||
              n['type'] == 'new_follower' ||
              n['type'] == 'follow' ||
              n['type'] == 'friend_accepted')
          .toList();
    if (_filter == 3)
      return _notifs
          .where((n) =>
              n['type'] == 'new_release' ||
              n['type'] == 'new_album' ||
              n['type'] == 'room_invite' ||
              n['type'] == 'room_started')
          .toList();
    return _notifs;
  }

  int _countForFilter(int index) {
    if (index == 0) return _notifs.length;
    final prev = _filter;
    _filter = index;
    final count = _filtered.length;
    _filter = prev;
    return count;
  }

  int get _unreadCount =>
      _notifs.where((n) => !_readIds.contains(n['id']?.toString())).length;

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final today = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final notif in _filtered) {
      final createdAt =
          DateTime.tryParse((notif['created_at'] ?? '').toString());
      if (createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day) {
        today.add(notif);
      } else {
        earlier.add(notif);
      }
    }
    return {
      if (today.isNotEmpty) 'New': today,
      if (earlier.isNotEmpty) 'Earlier': earlier,
    };
  }

  void _removeNotif(String id) {
    setState(() => _notifs.removeWhere((n) => n['id'] == id));
  }

  void _markRead(String id) {
    setState(() => _readIds.add(id));
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifs) {
        final id = n['id']?.toString();
        if (id != null) _readIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
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
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications',
                            style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                                letterSpacing: -0.02 * 26)),
                        const SizedBox(height: 2),
                        Text(
                          _notifs.isEmpty
                              ? 'Likes, matches and requests live here'
                              : _unreadCount > 0
                                  ? '$_unreadCount unread'
                                  : 'All caught up',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const NotificationSettingsScreen())),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // ── Action row ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text(
                    _filters[_filter],
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text3),
                  ),
                  const Spacer(),
                  if (_notifs.isNotEmpty) ...[
                    if (_unreadCount > 0)
                      GestureDetector(
                        onTap: _markAllRead,
                        child: Text('Mark all read',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purpleLight)),
                      ),
                    if (_unreadCount > 0) const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => setState(() => _notifs.clear()),
                      child: Text('Clear all',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text3)),
                    ),
                  ],
                ],
              ),
            ),
            // ── Filter tabs ──────────────────────────────────────
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: _filter == i ? AppColors.gradPurple : null,
                      color: _filter == i ? null : AppColors.glass,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: _filter == i
                              ? AppColors.purple
                              : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_filters[i],
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _filter == i
                                    ? Colors.white
                                    : AppColors.text2)),
                        const SizedBox(width: 6),
                        Text(
                          '${_countForFilter(i)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _filter == i
                                ? Colors.white.withOpacity(0.92)
                                : AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── List ─────────────────────────────────────────────
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purpleLight))
                  : _filtered.isEmpty
                      ? _EmptyState(filterName: _filters[_filter])
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.purpleLight,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _grouped.entries
                                .map((e) => e.value.length + 1)
                                .fold<int>(0, (sum, v) => sum + v),
                            itemBuilder: (_, i) {
                              var cursor = 0;
                              for (final entry in _grouped.entries) {
                                if (i == cursor) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 10, 20, 6),
                                    child: Text(
                                      entry.key,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text3,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  );
                                }
                                cursor++;
                                final end = cursor + entry.value.length;
                                if (i < end) {
                                  final n = entry.value[i - cursor];
                                  final type = n['type'] as String? ?? '';
                                  final id = n['id']?.toString() ?? '';
                                  final isRead = _readIds.contains(id);
                                  if (type == 'friend_request') {
                                    return _FriendRequestCard(
                                      key: ValueKey(id),
                                      notif: n,
                                      isRead: isRead,
                                      onDismiss: () => _removeNotif(id),
                                    );
                                  }
                                  if (type == 'like') {
                                    return _LikeCard(
                                      key: ValueKey(id),
                                      notif: n,
                                      isRead: isRead,
                                      onDismiss: () => _removeNotif(id),
                                    );
                                  }
                                  if (type == 'new_follower' ||
                                      type == 'follow') {
                                    return _NewFollowerCard(
                                      notif: n,
                                      isRead: isRead,
                                      onMarkRead: id.isNotEmpty
                                          ? () => _markRead(id)
                                          : null,
                                    );
                                  }
                                  if (type == 'friend_accepted') {
                                    return _FriendAcceptedCard(
                                        notif: n, isRead: isRead);
                                  }
                                  if (type == 'new_album' ||
                                      type == 'new_release') {
                                    return _NewAlbumCard(
                                        notif: n, isRead: isRead);
                                  }
                                  if (type == 'room_invite' ||
                                      type == 'room_started') {
                                    return _RoomInviteCard(
                                      key: ValueKey(id),
                                      notif: n,
                                      isRead: isRead,
                                      onDismiss: () => _removeNotif(id),
                                    );
                                  }
                                  return _MatchCard(
                                    notif: n,
                                    isRead: isRead,
                                    onMarkRead: id.isNotEmpty
                                        ? () => _markRead(id)
                                        : null,
                                  );
                                }
                                cursor = end;
                              }
                              return const SizedBox.shrink();
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filterName;
  const _EmptyState({required this.filterName});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔔', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text(
            filterName == 'All'
                ? 'Likes, matches and friend requests will appear here'
                : 'No $filterName notifications yet',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

// ─── Unread dot ───────────────────────────────────────────────────────────────

Widget _unreadDot() => Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: AppColors.purpleLight,
        shape: BoxShape.circle,
      ),
    );

// ─── Match card ───────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  final VoidCallback? onMarkRead;
  const _MatchCard(
      {required this.notif, required this.isRead, this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final name = notif['user_name'] as String? ?? '?';
    final initial = notif['user_initial'] as String? ?? '?';
    final pct = notif['similarity_pct'] as int? ?? 0;
    final city = notif['city'] as String? ?? '';
    final time = notif['time'] as String? ?? '';
    final avatarUrl = buildMediaUrl((notif['avatar_url'] ?? '').toString());
    final rawUserId = notif['user_id'];
    final userId =
        rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');

    return GestureDetector(
      onTap: () {
        onMarkRead?.call();
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: userId)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        color: isRead ? Colors.transparent : AppColors.purpleLight.withOpacity(0.04),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isRead) _unreadDot() else const SizedBox(width: 8),
          const SizedBox(width: 6),
          Stack(children: [
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                gradient: AppColors.gradPink,
                shape: BoxShape.circle,
              ),
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
            ),
            Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: AppColors.purple,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2)),
                    child: const Center(
                        child: Text('🎵', style: TextStyle(fontSize: 9))))),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
                text: TextSpan(
              style: GoogleFonts.outfit(
                  fontSize: 14, height: 1.5, color: AppColors.text),
              children: [
                TextSpan(text: '$pct% match found — meet '),
                TextSpan(
                    text: name,
                    style: GoogleFonts.outfit(
                        color: AppColors.purpleLight,
                        fontWeight: FontWeight.w600)),
                if (city.isNotEmpty) TextSpan(text: ' from $city'),
              ],
            )),
            const SizedBox(height: 4),
            Row(children: [
              Text(time,
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              if (userId != null) ...[
                const Spacer(),
                Text('View profile',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purpleLight)),
              ],
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ─── Like card ────────────────────────────────────────────────────────────────

class _LikeCard extends StatefulWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  final VoidCallback onDismiss;
  const _LikeCard(
      {super.key,
      required this.notif,
      required this.isRead,
      required this.onDismiss});

  @override
  State<_LikeCard> createState() => _LikeCardState();
}

class _LikeCardState extends State<_LikeCard> {
  String? _action;

  Future<void> _decide(String decision) async {
    if (_action != null) return;
    final raw = widget.notif['user_id'];
    final userId = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    if (userId == 0) return;
    setState(() => _action = decision);
    try {
      final result = await ApiService().decideMatch(userId, decision);
      if (!mounted) return;
      final mutual = result['is_mutual'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'like'
                ? (mutual ? 'You matched. Chat is open now.' : 'Like sent back')
                : 'Passed',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: decision == 'like'
              ? AppColors.surface2
              : const Color(0xFF2a1522),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() => _action = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update this like right now',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF3d0000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.notif['user_name'] as String? ?? '?';
    final initial = widget.notif['user_initial'] as String? ?? '?';
    final city = widget.notif['city'] as String? ?? '';
    final time = widget.notif['time'] as String? ?? '';
    final avatarUrl = buildMediaUrl(
        (widget.notif['avatar_url'] as String? ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isRead ? AppColors.surface : AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: widget.isRead
                  ? AppColors.border
                  : AppColors.purpleLight.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                Container(
                  width: 46,
                  height: 46,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    gradient: AppColors.gradPurple,
                    shape: BoxShape.circle,
                  ),
                  child: avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                        )
                      : Center(
                          child: Text(initial,
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white))),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: const Color(0xFFef4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2)),
                    child: const Icon(Icons.favorite_rounded,
                        size: 10, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                          fontSize: 14, height: 1.5, color: AppColors.text),
                      children: [
                        TextSpan(
                            text: name,
                            style: GoogleFonts.outfit(
                                color: AppColors.purpleLight,
                                fontWeight: FontWeight.w700)),
                        const TextSpan(
                            text:
                                ' liked your music taste. Like back to open chat.'),
                        if (city.isNotEmpty) TextSpan(text: ' • $city'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(time,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _action != null ? null : () => _decide('like'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _action == 'like'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Like back',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _action != null ? null : () => _decide('skip'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: _action == 'skip'
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.purpleLight))
                          : Text('Pass',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Friend request card ──────────────────────────────────────────────────────

class _FriendRequestCard extends StatefulWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  final VoidCallback onDismiss;
  const _FriendRequestCard(
      {super.key,
      required this.notif,
      required this.isRead,
      required this.onDismiss});
  @override
  State<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<_FriendRequestCard> {
  bool _loading = false;
  String? _result;

  Future<void> _accept() async {
    final raw = widget.notif['user_id'];
    final userId = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    if (userId == 0) return;
    setState(() => _loading = true);
    try {
      await ApiService().acceptFriendRequest(userId);
      setState(() {
        _result = 'accepted';
        _loading = false;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onDismiss();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Could not accept request', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF3d0000),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _decline() async {
    final raw = widget.notif['user_id'];
    final userId = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    if (userId == 0) return;
    setState(() => _loading = true);
    try {
      await ApiService().declineFriendRequest(userId);
      setState(() {
        _result = 'declined';
        _loading = false;
      });
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
    final avatarUrl =
        buildMediaUrl((widget.notif['avatar_url'] ?? '').toString());

    return AnimatedOpacity(
      opacity: _result != null ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!widget.isRead) _unreadDot() else const SizedBox(width: 8),
          const SizedBox(width: 6),
          Stack(children: [
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF92400e), Color(0xFFf59e0b)]),
                shape: BoxShape.circle,
              ),
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(initial,
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white))),
                    )
                  : Center(
                      child: Text(initial,
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))),
            ),
            Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: const Color(0xFFf59e0b),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2)),
                    child: const Center(
                        child: Text('+',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold))))),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$name sent you a friend request',
                    style: GoogleFonts.outfit(
                        fontSize: 14, height: 1.5, color: AppColors.text)),
                if (_result == null) ...[
                  const SizedBox(height: 10),
                  _loading
                      ? const SizedBox(
                          height: 36,
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.purpleLight))))
                      : Row(children: [
                          Expanded(
                              child: GestureDetector(
                                  onTap: _accept,
                                  child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                          gradient: AppColors.gradPurple,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text('Accept',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white))))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: GestureDetector(
                                  onTap: _decline,
                                  child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                          color: AppColors.glass,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: AppColors.border)),
                                      child: Text('Decline',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text))))),
                        ]),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                      _result == 'accepted'
                          ? '✓ Friend added'
                          : '✗ Request declined',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: _result == 'accepted'
                              ? const Color(0xFF4ade80)
                              : AppColors.text3)),
                ],
                const SizedBox(height: 4),
                Text(time,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
              ])),
        ]),
      ),
    );
  }
}

// ─── New Follower card ────────────────────────────────────────────────────────

class _NewFollowerCard extends StatefulWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  final VoidCallback? onMarkRead;
  const _NewFollowerCard(
      {required this.notif, required this.isRead, this.onMarkRead});
  @override
  State<_NewFollowerCard> createState() => _NewFollowerCardState();
}

class _NewFollowerCardState extends State<_NewFollowerCard> {
  bool _following = false;
  bool _loading = false;

  Future<void> _followBack() async {
    final raw = widget.notif['user_id'];
    final userId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (userId == null || _loading) return;
    setState(() => _loading = true);
    try {
      await ApiService().followUser(userId);
      if (!mounted) return;
      setState(() {
        _following = true;
        _loading = false;
      });
      widget.onMarkRead?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.notif['user_name'] as String? ?? '?';
    final initial = (widget.notif['user_initial'] as String?) ??
        (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final time = widget.notif['time'] as String? ?? '';
    final avatarUrl =
        buildMediaUrl((widget.notif['avatar_url'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.isRead) _unreadDot() else const SizedBox(width: 8),
        const SizedBox(width: 6),
        Stack(children: [
          Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]),
              shape: BoxShape.circle,
            ),
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                  )
                : Center(
                    child: Text(initial,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
          ),
          Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2)),
                  child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 9))))),
        ]),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
              text: TextSpan(
            style: GoogleFonts.outfit(
                fontSize: 14, height: 1.5, color: AppColors.text),
            children: [
              TextSpan(
                  text: name,
                  style: GoogleFonts.outfit(
                      color: AppColors.purpleLight,
                      fontWeight: FontWeight.w600)),
              const TextSpan(text: ' started following you'),
            ],
          )),
          const SizedBox(height: 6),
          Row(children: [
            Text(time,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            const Spacer(),
            if (!_following)
              GestureDetector(
                onTap: _followBack,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.purpleLight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.purpleLight))
                      : Text('Follow back',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.purpleLight)),
                ),
              )
            else
              Text('Following',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                      fontWeight: FontWeight.w600)),
          ]),
        ])),
      ]),
    );
  }
}

// ─── Friend accepted card ─────────────────────────────────────────────────────

class _FriendAcceptedCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  const _FriendAcceptedCard({required this.notif, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final name = notif['user_name'] as String? ?? '?';
    final initial = (notif['user_initial'] as String?) ??
        (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final time = notif['time'] as String? ?? '';
    final avatarUrl = buildMediaUrl((notif['avatar_url'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isRead) _unreadDot() else const SizedBox(width: 8),
        const SizedBox(width: 6),
        Stack(children: [
          Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF22C55E)]),
              shape: BoxShape.circle,
            ),
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                  )
                : Center(
                    child: Text(initial,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
          ),
          Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2)),
                  child: const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white))),
        ]),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
              text: TextSpan(
            style: GoogleFonts.outfit(
                fontSize: 14, height: 1.5, color: AppColors.text),
            children: [
              TextSpan(
                  text: name,
                  style: GoogleFonts.outfit(
                      color: AppColors.purpleLight,
                      fontWeight: FontWeight.w600)),
              const TextSpan(text: ' accepted your friend request'),
            ],
          )),
          const SizedBox(height: 4),
          Text(time,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
      ]),
    );
  }
}

// ─── New Album card ───────────────────────────────────────────────────────────

class _NewAlbumCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  const _NewAlbumCard({required this.notif, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final artist = notif['artist_name'] as String? ?? '?';
    final album = (notif['album_title'] ?? notif['album_name']) as String? ??
        'New release';
    final coverUrl = notif['cover_url'] as String?;
    final time = notif['time'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isRead) _unreadDot() else const SizedBox(width: 8),
        const SizedBox(width: 6),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFFDB2777)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: coverUrl != null && coverUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('💿', style: TextStyle(fontSize: 20)))))
              : const Center(
                  child: Text('💿', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.purpleLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('New Release',
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purpleLight)),
          ),
          const SizedBox(height: 4),
          RichText(
              text: TextSpan(
            style: GoogleFonts.outfit(
                fontSize: 14, height: 1.5, color: AppColors.text),
            children: [
              TextSpan(
                  text: artist,
                  style: GoogleFonts.outfit(
                      color: AppColors.purpleLight,
                      fontWeight: FontWeight.w600)),
              const TextSpan(text: ' · '),
              TextSpan(
                  text: album,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          )),
          const SizedBox(height: 4),
          Text(time,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
      ]),
    );
  }
}

// ─── Room Invite card ─────────────────────────────────────────────────────────

class _RoomInviteCard extends StatefulWidget {
  final Map<String, dynamic> notif;
  final bool isRead;
  final VoidCallback onDismiss;
  const _RoomInviteCard(
      {super.key,
      required this.notif,
      required this.isRead,
      required this.onDismiss});
  @override
  State<_RoomInviteCard> createState() => _RoomInviteCardState();
}

class _RoomInviteCardState extends State<_RoomInviteCard> {
  bool _joining = false;

  Future<void> _join() async {
    final rawId = widget.notif['room_id'];
    final roomId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    setState(() => _joining = true);
    try {
      if (roomId != null) {
        await ApiService().joinRoom(roomId);
        if (!mounted) return;
        widget.onDismiss();
      }
    } catch (_) {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomName =
        (widget.notif['room_name'] ?? widget.notif['title'] ?? 'Listening room')
            .toString();
    final inviter =
        (widget.notif['user_name'] ?? widget.notif['sender_name'] ?? 'A friend')
            .toString();
    final time = (widget.notif['time'] ?? '').toString();
    final hasRoomId = widget.notif['room_id'] != null;
    final isRoomStarted =
        (widget.notif['type'] ?? '') == 'room_started';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: widget.isRead
                  ? AppColors.border
                  : const Color(0xFF14B8A6).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.gradTeal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.headphones_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRoomStarted
                        ? '$inviter opened a listening room'
                        : '$inviter invited you to $roomName',
                    style: GoogleFonts.outfit(
                        fontSize: 14, height: 1.45, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(time,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.text3)),
                ],
              ),
            ),
            if (hasRoomId) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _joining ? null : _join,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Join',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
