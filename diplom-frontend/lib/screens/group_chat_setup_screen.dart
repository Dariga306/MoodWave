import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class GroupChatSetupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialUsers;
  final int? sourceMatchId;
  final int? sourceChatId;

  const GroupChatSetupScreen({
    super.key,
    this.initialUsers = const [],
    this.sourceMatchId,
    this.sourceChatId,
  });

  @override
  State<GroupChatSetupScreen> createState() => _GroupChatSetupScreenState();
}

class _GroupChatSetupScreenState extends State<GroupChatSetupScreen> {
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _recommended = [];
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _selected = [];
  bool _loading = true;
  bool _creating = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = context.read<AuthProvider>().user;
      final myId = (me?['id'] as num?)?.toInt() ?? 0;
      final following = await ApiService().getUserFollowing(myId, limit: 100);
      final recommended = await _buildRecommendations(myId, following);
      if (!mounted) return;
      setState(() {
        _allUsers = following;
        _recommended = recommended;
        _selected
          ..clear()
          ..addAll(
              widget.initialUsers.map((u) => Map<String, dynamic>.from(u)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _buildRecommendations(
    int myId,
    List<Map<String, dynamic>> following,
  ) async {
    final seen = <int>{myId};
    final recs = <Map<String, dynamic>>[];

    void addUser(Map<String, dynamic> user) {
      final id = (user['id'] as num?)?.toInt();
      if (id == null || seen.contains(id)) return;
      seen.add(id);
      recs.add(Map<String, dynamic>.from(user));
    }

    for (final user in following) {
      final id = (user['id'] as num?)?.toInt();
      if (id != null) seen.add(id);
    }

    try {
      final history = await ApiService().getSearchHistory(limit: 12);
      for (final item in history.where((entry) =>
          entry['result_type']?.toString().toLowerCase() == 'profile')) {
        final id = int.tryParse((item['result_id'] ?? '').toString());
        if (id == null || seen.contains(id)) continue;
        try {
          final summary = await ApiService().getUserProfileSummary(
            id,
            playlistLimit: 0,
            tracksLimit: 0,
          );
          addUser({
            'id': id,
            'display_name':
                (summary['display_name'] ?? summary['username'] ?? 'User')
                    .toString(),
            'username': (summary['username'] ?? '').toString(),
            'avatar_url': (summary['avatar_url'] ?? '').toString(),
          });
        } catch (_) {}
      }
    } catch (_) {}

    for (final followed in following.take(8)) {
      final followedId = (followed['id'] as num?)?.toInt();
      if (followedId == null) continue;
      try {
        final secondDegree =
            await ApiService().getUserFollowing(followedId, limit: 10);
        for (final user in secondDegree) {
          addUser(user);
          if (recs.length >= 12) break;
        }
      } catch (_) {}
      if (recs.length >= 12) break;
    }

    return recs;
  }

  List<Map<String, dynamic>> get _visibleUsers {
    final q = _searchCtrl.text.trim().toLowerCase();
    final source = q.isEmpty
        ? _allUsers
        : (_searchResults.isNotEmpty
            ? _searchResults
            : [..._allUsers, ..._recommended]);
    final unique = <int, Map<String, dynamic>>{};
    for (final user in source) {
      final id = (user['id'] as num?)?.toInt();
      if (id != null) {
        unique[id] = Map<String, dynamic>.from(user);
      }
    }
    final users = unique.values.toList();
    if (q.isEmpty) return users;
    return users.where((u) {
      final name =
          (u['display_name'] ?? u['username'] ?? '').toString().toLowerCase();
      final username = (u['username'] ?? '').toString().toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  void _handleSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 240), () async {
      final remote = await ApiService().searchUsers(q, limit: 30);
      if (!mounted || _searchCtrl.text.trim().toLowerCase() != q) return;
      setState(() => _searchResults = remote);
    });
  }

  bool _isSelected(Map<String, dynamic> user) {
    final id = (user['id'] as num?)?.toInt();
    return _selected.any((item) => (item['id'] as num?)?.toInt() == id);
  }

  void _toggleUser(Map<String, dynamic> user) {
    final id = (user['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      final idx =
          _selected.indexWhere((item) => (item['id'] as num?)?.toInt() == id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(Map<String, dynamic>.from(user));
      }
    });
  }

  Future<void> _createGroupChat() async {
    if (_selected.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final roomName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : 'New Group';
      final group = await ApiService().createGroupChat(
        title: roomName,
        memberIds: _selected
            .map((user) => (user['id'] as num?)?.toInt())
            .whereType<int>()
            .toList(),
        avatarUrl: _avatarCtrl.text.trim().isNotEmpty
            ? _avatarCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      final groupChatId = (group['group_chat_id'] as num?)?.toInt();
      final me = context.read<AuthProvider>().user;
      final myName = (me?['display_name'] ?? me?['username'] ?? 'Someone').toString();
      final inviteText = '💬 $myName создал(а) группу «$roomName»! Присоединяйся с кодом: $groupChatId';
      if (widget.sourceMatchId != null) {
        try {
          await ApiService().sendTextMessage(widget.sourceMatchId!, inviteText);
        } catch (_) {}
      } else if (widget.sourceChatId != null) {
        try {
          await ApiService().sendDirectTextMessage(widget.sourceChatId!, inviteText);
        } catch (_) {}
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            groupChatId: groupChatId,
            partnerName: (group['title'] ?? roomName).toString(),
            partnerId: 0,
            partnerAvatarUrl: (group['avatar_url'] ?? '').toString(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось создать группу'),
          backgroundColor: Color(0xFF7f1d1d),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          'Group Chat',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.purpleLight,
                strokeWidth: 2,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _nameCtrl,
                          style: GoogleFonts.outfit(
                            color: AppColors.text,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Group name',
                            hintStyle:
                                GoogleFonts.outfit(color: AppColors.text3),
                            prefixIcon: const Icon(
                              Icons.groups_rounded,
                              color: AppColors.text3,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _avatarCtrl,
                          style: GoogleFonts.outfit(
                            color: AppColors.text,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Group avatar URL (optional)',
                            hintStyle:
                                GoogleFonts.outfit(color: AppColors.text3),
                            prefixIcon: const Icon(
                              Icons.image_rounded,
                              color: AppColors.text3,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: _handleSearchChanged,
                          style: GoogleFonts.outfit(
                            color: AppColors.text,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add people...',
                            hintStyle:
                                GoogleFonts.outfit(color: AppColors.text3),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.text3,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _selected.map((user) {
                        final name =
                            (user['display_name'] ?? user['username'] ?? 'User')
                                .toString();
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _toggleUser(user),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.text3,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (_searchCtrl.text.trim().isEmpty && _recommended.isNotEmpty)
                  _GroupSection(
                    title: 'Recommendations',
                    users: _recommended,
                    selectedPredicate: _isSelected,
                    onToggle: _toggleUser,
                  ),
                Expanded(
                  child: _GroupSection(
                    title: 'People you follow',
                    users: _visibleUsers,
                    selectedPredicate: _isSelected,
                    onToggle: _toggleUser,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selected.isEmpty || _creating
                            ? null
                            : _createGroupChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            height: 52,
                            child: _creating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Create group chat',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
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

class _GroupSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final bool Function(Map<String, dynamic>) selectedPredicate;
  final void Function(Map<String, dynamic>) onToggle;

  const _GroupSection({
    required this.title,
    required this.users,
    required this.selectedPredicate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        ...users.map((u) {
          final name =
              (u['display_name'] ?? u['username'] ?? 'User').toString();
          final username = (u['username'] ?? '').toString();
          final avatarUrl = (u['avatar_url'] ?? '').toString();
          final selected = selectedPredicate(u);
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradMixed,
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            title: Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            subtitle: username.isNotEmpty
                ? Text(
                    '@$username',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  )
                : null,
            trailing: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.purpleLight : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.purpleLight : AppColors.border,
                ),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: 16,
                color: selected ? Colors.white : AppColors.text3,
              ),
            ),
            onTap: () => onToggle(u),
          );
        }),
      ],
    );
  }
}
