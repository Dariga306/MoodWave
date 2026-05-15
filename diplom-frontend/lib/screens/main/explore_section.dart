import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../extra_screens.dart';
import '../weather_screen.dart';
import '../ai_playlist_screen.dart';

// ─── Модель карточки Explore ─────────────────────────────────────────────────

class _ExploreItem {
  final String emoji;
  final String label;
  final LinearGradient gradient;
  final bool isLive;   // показывать LIVE-бейджик
  final WidgetBuilder destination;

  const _ExploreItem({
    required this.emoji,
    required this.label,
    required this.gradient,
    required this.destination,
    this.isLive = false,
  });
}

// ─── Публичный виджет ────────────────────────────────────────────────────────

class ExploreSection extends StatelessWidget {
  const ExploreSection({super.key});

  List<_ExploreItem> _items() => [
        _ExploreItem(
          emoji: '🌍',
          label: 'Discover',
          gradient: AppColors.gradBlue,
          destination: (_) => const DiscoverScreen(),
        ),
        _ExploreItem(
          emoji: '🏙',
          label: 'Charts',
          gradient: AppColors.gradPurple,
          isLive: true,
          destination: (_) => const CityChartsScreen(),
        ),
        _ExploreItem(
          emoji: '📻',
          label: 'Radio',
          gradient: AppColors.gradMixed,
          isLive: true,
          destination: (_) => const RadioScreen(),
        ),
        _ExploreItem(
          emoji: '🎉',
          label: 'Party',
          gradient: AppColors.gradPink,
          isLive: true,
          destination: (_) => const BrowseRoomsScreen(),
        ),
        _ExploreItem(
          emoji: '✦',
          label: 'AI Mix',
          gradient: AppColors.gradOrange,
          destination: (_) => const AIPlaylistScreen(),
        ),
        _ExploreItem(
          emoji: '🌨',
          label: 'Weather',
          gradient: AppColors.gradCyan,
          destination: (_) => const WeatherScreen(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _ExploreCard(item: items[i]),
      ),
    );
  }
}

// ─── Карточка Explore ────────────────────────────────────────────────────────

class _ExploreCard extends StatelessWidget {
  final _ExploreItem item;
  const _ExploreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: item.destination)),
      child: Container(
        decoration: BoxDecoration(
          gradient: item.gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Emoji + label по центру
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // LIVE-бейджик (правый верхний угол)
            if (item.isLive)
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFef4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Пульс-точка
                      _LiveDot(),
                      const SizedBox(width: 3),
                      Text(
                        'LIVE',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
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

// ─── Анимированная точка ●  ──────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
}