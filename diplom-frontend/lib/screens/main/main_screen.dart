import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/player_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/mini_player.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';
import 'social_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _socialBadge = 0;
  DateTime? _lastSeenSocial;
  Timer? _badgePollTimer;

  late final List<Widget?> _tabs =
      List<Widget?>.filled(4, null, growable: false)..[0] = const HomeTab();

  @override
  void initState() {
    super.initState();
    _initBadge();
    _badgePollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollBadge());
  }

  @override
  void dispose() {
    _badgePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('last_seen_social');
    if (str != null) {
      _lastSeenSocial = DateTime.tryParse(str)?.toLocal();
    } else {
      _lastSeenSocial = DateTime.now();
      await prefs.setString('last_seen_social', _lastSeenSocial!.toIso8601String());
    }
    _pollBadge();
  }

  Future<void> _pollBadge() async {
    if (_currentIndex == 2 || _lastSeenSocial == null) return;
    try {
      final chats = await ApiService().getChats();
      int count = 0;
      for (final raw in chats) {
        final chat = raw as Map;
        final lastAt = chat['last_message_at'] as String?;
        if (lastAt == null) continue;
        final normalized = lastAt.endsWith('Z') || lastAt.contains('+') ? lastAt : '${lastAt}Z';
        final dt = DateTime.tryParse(normalized)?.toLocal();
        if (dt != null && dt.isAfter(_lastSeenSocial!)) count++;
      }
      if (mounted) setState(() => _socialBadge = count);
    } catch (_) {}
  }

  Future<void> _clearSocialBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('last_seen_social', now.toIso8601String());
    if (mounted) setState(() {
      _socialBadge = 0;
      _lastSeenSocial = now;
    });
  }

  void _onTabTap(int i) {
    if (i == 2 && _currentIndex != 2) {
      _clearSocialBadge();
    }
    _tabs[i] ??= _buildTab(i);
    setState(() => _currentIndex = i);
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

    final hasTrack = context.select<PlayerProvider, bool>((p) => p.hasTrack);

    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _tabs.length,
          (index) => _tabs[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTrack) const MiniPlayer(),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
            socialBadge: _socialBadge,
          ),
        ],
      ),
    );
  }
}
