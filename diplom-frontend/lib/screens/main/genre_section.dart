import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../genre_tracks_screen.dart';

class _GenreData {
  final String name;
  final String emoji;
  final LinearGradient gradient;
  final Color accentColor;
  final String artUrl;

  const _GenreData({
    required this.name,
    required this.emoji,
    required this.gradient,
    required this.accentColor,
    required this.artUrl,
  });
}

const _genres = [
  _GenreData(
    name: 'Pop',
    emoji: '🎤',
    gradient: LinearGradient(
      colors: [Color(0xFF5B2EA6), Color(0xFF9A4DFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFB38BFF),
    artUrl:
        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=900&q=80',
  ),
  _GenreData(
    name: 'Rock',
    emoji: '🎸',
    gradient: LinearGradient(
      colors: [Color(0xFF234A93), Color(0xFF5E7FD4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF7FA7FF),
    artUrl:
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=80',
  ),
  _GenreData(
    name: 'Hip-Hop',
    emoji: '🎙',
    gradient: LinearGradient(
      colors: [Color(0xFF2F5FB8), Color(0xFF6E8EEA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF6CA6FF),
    artUrl:
        'https://images.unsplash.com/photo-1521334884684-d80222895322?w=900&q=80',
  ),
  _GenreData(
    name: 'Electronic',
    emoji: '🎛',
    gradient: LinearGradient(
      colors: [Color(0xFF255A73), Color(0xFF2DA7CF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF5AD7FF),
    artUrl:
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=80',
  ),
  _GenreData(
    name: 'Jazz',
    emoji: '🎷',
    gradient: LinearGradient(
      colors: [Color(0xFF8A5A18), Color(0xFFD5943B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFC96E),
    artUrl:
        'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=80',
  ),
  _GenreData(
    name: 'K-Pop',
    emoji: '✨',
    gradient: LinearGradient(
      colors: [Color(0xFF8B3DA9), Color(0xFFF07B8E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFA2DA),
    artUrl:
        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=900&q=80',
  ),
  _GenreData(
    name: 'R&B',
    emoji: '🕊',
    gradient: LinearGradient(
      colors: [Color(0xFF5B2D92), Color(0xFF8B62D6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFB89CFF),
    artUrl:
        'https://images.unsplash.com/photo-1507874457470-272b3c8d8ee2?w=900&q=80',
  ),
  _GenreData(
    name: 'Latin',
    emoji: '💃',
    gradient: LinearGradient(
      colors: [Color(0xFFAF4D27), Color(0xFFF07C4A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFB178),
    artUrl:
        'https://images.unsplash.com/photo-1504609773096-104ff2c73ba4?w=900&q=80',
  ),
  _GenreData(
    name: 'Indie',
    emoji: '🌿',
    gradient: LinearGradient(
      colors: [Color(0xFF3B6A51), Color(0xFF66B07E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF93E1B1),
    artUrl:
        'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=900&q=80',
  ),
  _GenreData(
    name: 'Afrobeat',
    emoji: '🥁',
    gradient: LinearGradient(
      colors: [Color(0xFF876017), Color(0xFFD59A2E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFCF6A),
    artUrl:
        'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=80',
  ),
  _GenreData(
    name: 'Classical',
    emoji: '🎻',
    gradient: LinearGradient(
      colors: [Color(0xFF465B8E), Color(0xFF7E93C7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFAFC4FF),
    artUrl:
        'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=900&q=80',
  ),
  _GenreData(
    name: 'Country',
    emoji: '🤠',
    gradient: LinearGradient(
      colors: [Color(0xFF7D5327), Color(0xFFC58A43)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFF6BE72),
    artUrl:
        'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=900&q=80',
  ),
  _GenreData(
    name: 'Metal',
    emoji: '🤘',
    gradient: LinearGradient(
      colors: [Color(0xFF44508E), Color(0xFF7A86D1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFA8B7FF),
    artUrl:
        'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=80',
  ),
  _GenreData(
    name: 'Blues',
    emoji: '🎼',
    gradient: LinearGradient(
      colors: [Color(0xFF28598C), Color(0xFF62A4D9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF8FD1FF),
    artUrl:
        'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=900&q=80',
  ),
  _GenreData(
    name: 'Lo-Fi',
    emoji: '🌙',
    gradient: LinearGradient(
      colors: [Color(0xFF4E4C9A), Color(0xFF8A78E8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFB2A6FF),
    artUrl:
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=900&q=80',
  ),
  _GenreData(
    name: 'Reggaeton',
    emoji: '🔥',
    gradient: LinearGradient(
      colors: [Color(0xFF9A4A34), Color(0xFFE7805D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFB08D),
    artUrl:
        'https://images.unsplash.com/photo-1504609773096-104ff2c73ba4?w=900&q=80',
  ),
];

class GenreSection extends StatelessWidget {
  const GenreSection({super.key});

  @override
  Widget build(BuildContext context) {
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
        itemCount: _genres.length,
        itemBuilder: (ctx, i) => _GenreCard(data: _genres[i]),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final _GenreData data;

  const _GenreCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GenreTracksScreen(
            genre: data.name,
            emoji: data.emoji,
            gradient: data.gradient,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: data.accentColor.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: data.artUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(gradient: data.gradient),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(gradient: data.gradient),
                ),
              ),
              // subtle colour tint top → transparent mid → dark bottom for text
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      data.accentColor.withValues(alpha: 0.28),
                      data.accentColor.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.52),
                    ],
                    stops: const [0.0, 0.40, 1.0],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0,
                        shadows: const [
                          Shadow(
                            color: Color(0x70000000),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        data.accentColor.withValues(alpha: 0.78),
                        data.accentColor.withValues(alpha: 0.34),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
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
