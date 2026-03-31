import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'mood_select_screen.dart';

const List<String> _allGenres = [
  'Pop', 'Rock', 'Indie Rock', 'Alt Pop', 'Electronic', 'Hip-Hop', 'R&B',
  'Jazz', 'Classical', 'Ambient', 'Lo-fi', 'K-Pop', 'Latin', 'Reggae',
  'Metal', 'Punk', 'Punk Rock', 'Post-Punk', 'Emo', 'Hardcore',
  'Alternative', 'Grunge', 'Folk', 'Country', 'Blues', 'Soul', 'Funk',
  'Disco', 'House', 'Techno', 'Drum & Bass', 'Dubstep', 'Trap', 'Phonk',
  'Afrobeats', 'Bossa Nova', 'Synthwave', 'Vaporwave', 'Shoegaze',
  'Math Rock', 'Post-Rock', 'Noise Rock',
];

class GenreSelectScreen extends StatefulWidget {
  const GenreSelectScreen({super.key});

  @override
  State<GenreSelectScreen> createState() => _GenreSelectScreenState();
}

class _GenreSelectScreenState extends State<GenreSelectScreen> {
  final Set<String> _selected = {};
  bool _loading = false;

  Future<void> _continue() async {
    if (_selected.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Select at least 3 genres', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF3d0000),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final genres = _selected.toList().asMap().entries.map((e) => {
        'genre': e.value,
        'weight': 1.0 - (e.key * 0.02),
      }).toList();
      await ApiService().saveGenres(genres);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MoodSelectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF150825), Color(0xFF08080f)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step dots
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _dot(done: true), const SizedBox(width: 6),
                      _dot(done: true), const SizedBox(width: 6),
                      _dot(active: true), const SizedBox(width: 6),
                      _dot(),
                    ]),
                    const SizedBox(height: 20),
                    Text('Your music taste', style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text('Select at least 3 genres you love',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 4),
                    Text('${_selected.length} selected',
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _selected.length >= 3 ? AppColors.purpleLight : AppColors.text3)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _allGenres.map((g) {
                        final sel = _selected.contains(g);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              _selected.remove(g);
                            } else {
                              _selected.add(g);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: sel ? AppColors.gradMixed : null,
                              color: sel ? null : AppColors.surface,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: sel ? Colors.transparent : AppColors.border,
                              ),
                              boxShadow: sel ? [BoxShadow(
                                  color: AppColors.purpleDark.withOpacity(0.3), blurRadius: 10)] : [],
                            ),
                            child: Text(g, style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppColors.text2)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: GestureDetector(
                  onTap: _loading ? null : _continue,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: _selected.length >= 3 ? AppColors.primaryBtn
                          : const LinearGradient(colors: [Color(0xFF2a2a3d), Color(0xFF2a2a3d)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _selected.length >= 3 ? [BoxShadow(
                          color: AppColors.purpleDark.withOpacity(0.4),
                          blurRadius: 30, offset: const Offset(0, 12))] : [],
                    ),
                    child: _loading
                        ? const Center(child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : Text('Continue →', textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: _selected.length >= 3 ? Colors.white : AppColors.text3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot({bool done = false, bool active = false}) {
    final w = done ? 20.0 : active ? 14.0 : 7.0;
    final c = done ? AppColors.purple : active ? AppColors.purpleLight : AppColors.surface3;
    return Container(
      width: w, height: 7,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(100)),
    );
  }
}
