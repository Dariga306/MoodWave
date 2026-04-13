import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
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

  late final List<Widget?> _tabs =
      List<Widget?>.filled(4, null, growable: false)..[0] = const HomeTab();

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
            onTap: (i) => setState(() => _currentIndex = i),
          ),
        ],
      ),
    );
  }
}
