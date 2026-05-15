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
    accentColor: Color(0xFF9A4DFF),
    artUrl:
        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=900&q=80',
  ),
  _GenreData(
    name: 'Rock',
    emoji: '🎸',
    gradient: LinearGradient(
      colors: [Color(0xFF1a3a7a), Color(0xFF4466CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF4466CC),
    artUrl:
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&q=80',
  ),
  _GenreData(
    name: 'Hip-Hop',
    emoji: '🎙',
    gradient: LinearGradient(
      colors: [Color(0xFF0d2a5c), Color(0xFF2255BB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF3D7FFF),
    artUrl:
        'https://images.unsplash.com/photo-1521334884684-d80222895322?w=900&q=80',
  ),
  _GenreData(
    name: 'Electronic',
    emoji: '🎛',
    gradient: LinearGradient(
      colors: [Color(0xFF063a52), Color(0xFF0D96C2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF00C8FF),
    artUrl:
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=80',
  ),
  _GenreData(
    name: 'Jazz',
    emoji: '🎷',
    gradient: LinearGradient(
      colors: [Color(0xFF6b3e0a), Color(0xFFCC8020)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFAA30),
    artUrl:
        'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=900&q=80',
  ),
  _GenreData(
    name: 'K-Pop',
    emoji: '✨',
    gradient: LinearGradient(
      colors: [Color(0xFF6b1a7a), Color(0xFFCC44AA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF66CC),
    artUrl:
        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=900&q=80',
  ),
  _GenreData(
    name: 'R&B',
    emoji: '🕊',
    gradient: LinearGradient(
      colors: [Color(0xFF3d1066), Color(0xFF7B2FBB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFAA66FF),
    artUrl:
        'https://images.unsplash.com/photo-1507874457470-272b3c8d8ee2?w=900&q=80',
  ),
  _GenreData(
    name: 'Latin',
    emoji: '💃',
    gradient: LinearGradient(
      colors: [Color(0xFF8a2a0a), Color(0xFFDD5522)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF7744),
    artUrl:
        'https://images.unsplash.com/photo-1504609773096-104ff2c73ba4?w=900&q=80',
  ),
  _GenreData(
    name: 'Indie',
    emoji: '🌿',
    gradient: LinearGradient(
      colors: [Color(0xFF1a4a32), Color(0xFF2E8B57)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF44CC88),
    artUrl:
        'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?w=900&q=80',
  ),
  _GenreData(
    name: 'Afrobeat',
    emoji: '🥁',
    gradient: LinearGradient(
      colors: [Color(0xFF5c3a08), Color(0xFFBB7A18)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFFBB33),
    artUrl:
        'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=900&q=80',
  ),
  _GenreData(
    name: 'Classical',
    emoji: '🎻',
    gradient: LinearGradient(
      colors: [Color(0xFF1e2d55), Color(0xFF3D5A9E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF7799EE),
    artUrl:
        'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=900&q=80',
  ),
  _GenreData(
    name: 'Country',
    emoji: '🤠',
    gradient: LinearGradient(
      colors: [Color(0xFF5c3810), Color(0xFFAA7030)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFDDA050),
    artUrl:
        'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=900&q=80',
  ),
  _GenreData(
    name: 'Metal',
    emoji: '🤘',
    gradient: LinearGradient(
      colors: [Color(0xFF1a1a3a), Color(0xFF444488)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF8888EE),
    artUrl:
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=900&q=80',
  ),
  _GenreData(
    name: 'Blues',
    emoji: '🎼',
    gradient: LinearGradient(
      colors: [Color(0xFF0d2e52), Color(0xFF1A6EA0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF44AADD),
    artUrl:
        'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=900&q=80',
  ),
  _GenreData(
    name: 'Lo-Fi',
    emoji: '🌙',
    gradient: LinearGradient(
      colors: [Color(0xFF1e1c52), Color(0xFF4A48A8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFF9988FF),
    artUrl:
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=900&q=80',
  ),
  _GenreData(
    name: 'Reggaeton',
    emoji: '🔥',
    gradient: LinearGradient(
      colors: [Color(0xFF7a2210), Color(0xFFCC4422)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentColor: Color(0xFFFF6644),
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
          childAspectRatio: 2.0,
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: data.accentColor.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background photo
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
              // Color overlay — accent tint across top half, dark at bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      data.accentColor.withValues(alpha: 0.70),
                      data.gradient.colors.last.withValues(alpha: 0.55),
                      const Color(0xDD000000),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      data.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
