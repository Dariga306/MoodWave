import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';

class LyricsScreen extends StatefulWidget {
  final String? artist;
  final String? title;
  const LyricsScreen({super.key, this.artist, this.title});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  String? _lyrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    final artist = widget.artist;
    final title = widget.title;
    if (artist == null || title == null || artist.isEmpty || title.isEmpty) {
      setState(() { _loading = false; _error = 'No track info'; });
      return;
    }
    try {
      final a = Uri.encodeComponent(artist);
      final t = Uri.encodeComponent(title);
      final resp = await http
          .get(Uri.parse('https://api.lyrics.ovh/v1/$a/$t'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = data['lyrics'] as String? ?? '';
        setState(() { _lyrics = raw.trim(); _loading = false; });
      } else {
        setState(() { _loading = false; _error = 'Lyrics not found'; });
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'Could not load lyrics'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0240), Color(0xFF0d0d20), Color(0xFF001230)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 80, left: -40,
              child: Container(width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.purple.withOpacity(0.2), Colors.transparent])))),
            Positioned(bottom: 100, right: -20,
              child: Container(width: 180, height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.pink.withOpacity(0.15), Colors.transparent])))),
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)),
                        ),
                        Column(children: [
                          Text('LYRICS', style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: const Color(0x80C8B4FF), letterSpacing: 0.1)),
                          if (widget.title != null)
                            Text(widget.title!, style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.text3),
                              overflow: TextOverflow.ellipsis),
                        ]),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2))
                        : _error != null
                            ? Center(child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_off_rounded, size: 48, color: AppColors.text3),
                                  const SizedBox(height: 12),
                                  Text(_error!, style: GoogleFonts.outfit(fontSize: 16, color: AppColors.text2)),
                                  const SizedBox(height: 6),
                                  Text('Try a different track', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
                                ],
                              ))
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                                child: Text(
                                  _lyrics ?? '',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    height: 1.8,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lyrics · lyrics.ovh',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
