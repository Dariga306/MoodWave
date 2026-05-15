import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../genre_tracks_screen.dart';

// ─── Жанровые данные ────────────────────────────────────────────────────────

class _GenreData {
  final String name;
  final String emoji;
  final LinearGradient gradient;
  final String artUrl;

  const _GenreData(this.name, this.emoji, this.gradient, this.artUrl);
}

const _genres = [
  _GenreData(
      'Pop',
      '🎤',
      LinearGradient(
        colors: [Color(0xFF7c3aed), Color(0xFFa855f7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Rock',
      '🎸',
      LinearGradient(
        colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Hip-Hop',
      '🎙️',
      LinearGradient(
        colors: [Color(0xFF1c1917), Color(0xFF78716c)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Electronic',
      '🎛️',
      LinearGradient(
        colors: [Color(0xFF164e63), Color(0xFF06b6d4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1571330735066-03aaa9429d89?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Jazz',
      '🎷',
      LinearGradient(
        colors: [Color(0xFF78350f), Color(0xFFd97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'K-Pop',
      '✨',
      LinearGradient(
        colors: [Color(0xFF9d174d), Color(0xFFec4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Classical',
      '🎻',
      LinearGradient(
        colors: [Color(0xFF3f3f46), Color(0xFF71717a)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1507838153414-b4b713384a76?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'R&B',
      '🕊️',
      LinearGradient(
        colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1501612780327-45045538702b?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Latin',
      '🪗',
      LinearGradient(
        colors: [Color(0xFF7f1d1d), Color(0xFFef4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1504609813442-a8924e83f76e?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Country',
      '🤠',
      LinearGradient(
        colors: [Color(0xFF713f12), Color(0xFFca8a04)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Folk',
      '🪕',
      LinearGradient(
        colors: [Color(0xFF14532d), Color(0xFF22c55e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Funk',
      '🕺',
      LinearGradient(
        colors: [Color(0xFF831843), Color(0xFFdb2777)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1499364615650-ec38552f4f34?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Soul',
      '🔥',
      LinearGradient(
        colors: [Color(0xFF7c2d12), Color(0xFFf97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Indie',
      '🌿',
      LinearGradient(
        colors: [Color(0xFF064e3b), Color(0xFF10b981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1460723237483-7a6dc9d0b212?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Punk',
      '⚡',
      LinearGradient(
        colors: [Color(0xFF1e1b4b), Color(0xFF6366f1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1503095396549-807759245b35?auto=format&fit=crop&w=1200&q=80'),
  _GenreData(
      'Reggae',
      '🌴',
      LinearGradient(
        colors: [Color(0xFF052e16), Color(0xFF16a34a)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80'),
];

// ─── Публичный виджет секции жанров ─────────────────────────────────────────

class GenreSection extends StatelessWidget {
  const GenreSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemCount: _genres.length,
      itemBuilder: (ctx, i) => _GenreCard(data: _genres[i]),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final _GenreData data;
  const _GenreCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GenreTracksScreen(
            genre: d.name,
            emoji: d.emoji,
            gradient: d.gradient,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: d.artUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(gradient: d.gradient),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.10),
                    d.gradient.colors.first.withOpacity(0.48),
                    d.gradient.colors.last.withOpacity(0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  d.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 19,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: -18,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
