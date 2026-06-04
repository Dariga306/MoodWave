import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';
import 'social_tab.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _socialBadge = 0;
  Timer? _badgePollTimer;
  Timer? _presenceTimer;
  static const _lastReadKeyPrefix = 'last_read_v1_';
  static const _mutedChatsKey = 'muted_chat_threads_v1';

  late final List<Widget?> _tabs =
      List<Widget?>.filled(4, null, growable: false)..[0] = const HomeTab();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    MiniPlayerOverlayController.forceVisible();
    MiniPlayerOverlayController.setBottomOffset(74);
    GlobalBottomNavController.hide();
    GlobalBottomNavController.setIndex(_currentIndex);
    GlobalBottomNavController.registerTapHandler(_onTabTap);
    // Delay badge + presence so home tab critical content loads first
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _initBadge();
      _sendPresenceHeartbeat();
    });
    _badgePollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _pollBadge());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendPresenceHeartbeat(),
    );
  }

  @override
  void dispose() {
    MiniPlayerOverlayController.setBottomOffset(0);
    GlobalBottomNavController.unregisterTapHandler();
    _badgePollTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendPresenceHeartbeat() async {
    await ApiService().sendPresenceHeartbeat();
  }

  Future<void> _initBadge() async {
    _pollBadge();
  }

  Future<void> _pollBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = (prefs.getStringList(_mutedChatsKey) ?? const []).toSet();
      final chats = await ApiService().getChats();
      final requests = <Map<String, String>>[];
      for (final raw in chats) {
        final chat = Map<String, dynamic>.from(raw as Map);
        final key = _chatKey(chat);
        if (muted.contains(key)) continue;
        final firebaseId = (chat['firebase_chat_id'] ?? '').toString();
        if (firebaseId.isEmpty) continue;
        final since = prefs.getString('$_lastReadKeyPrefix$key') ??
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String();
        requests
            .add({'key': key, 'firebase_chat_id': firebaseId, 'since': since});
      }
      final counts = requests.isEmpty
          ? <String, int>{}
          : await ApiService().getUnreadCounts(requests);
      final total = counts.values.fold<int>(0, (sum, item) => sum + item);
      if (mounted) {
        setState(() => _socialBadge = total);
        GlobalBottomNavController.setSocialBadge(total);
      }
    } catch (_) {}
  }

  String _chatKey(Map<String, dynamic> chat) {
    final gid = chat['group_chat_id'];
    final cid = chat['chat_id'];
    final mid = chat['match_id'];
    if (gid != null) return 'g:$gid';
    if (cid != null) return 'c:$cid';
    return 'm:$mid';
  }

  void _onTabTap(int i) {
    _tabs[i] ??= _buildTab(i);
    setState(() => _currentIndex = i);
    GlobalBottomNavController.setIndex(i);
    if (i == 2) {
      Future.delayed(const Duration(milliseconds: 500), _pollBadge);
    }
  }

  Widget _buildTab(int index) {
    return switch (index) {
      0 => const HomeTab(),
      1 => const SearchTab(),
      2 => const SocialTab(),
      3 => const LibraryTab(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    _tabs[_currentIndex] ??= _buildTab(_currentIndex);

    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _tabs.length,
          (index) => _tabs[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        socialBadge: _socialBadge,
      ),
    );
  }
}
