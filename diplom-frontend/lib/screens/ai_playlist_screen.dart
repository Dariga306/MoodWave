import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class AIPlaylistScreen extends StatelessWidget {
  const AIPlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('AI Playlist', style: GoogleFonts.outfit(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: AppColors.text, letterSpacing: -0.02 * 26)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.purpleDark.withOpacity(0.15),
                              AppColors.pink.withOpacity(0.1),
                            ]),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
                          ),
                          child: Text('✦ AI Powered', style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.purpleLight, letterSpacing: 0.04)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Describe a vibe, place, or feeling',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Suggestion chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  children: ['🌨 Snowy evening', '🏃 Morning run', '☕ Sunday coffee',
                    '🌙 Late night drive', '😢 Healing playlist']
                      .map((c) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(c, style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text2)),
                      )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Prompt area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF14062D).withOpacity(0.8),
                      const Color(0xFF08081C).withOpacity(0.8),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.purple.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✦ YOUR PROMPT', style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.purpleLight, letterSpacing: 0.1)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          'Songs for a cold winter night drive through Astana, something melancholic but beautiful, indie and alt rock vibes, songs that feel like falling snow...',
                          style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text, height: 1.55),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: [
                          _AiParam(label: 'LENGTH', value: '🎵 20 songs'),
                          _AiParam(label: 'MOOD', value: '🌙 Melancholic'),
                          _AiParam(label: 'ERA', value: '2010 – 2024'),
                          _AiParam(label: 'LANGUAGE', value: '🌍 Any'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryBtn,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Generate Playlist', style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('✦ GENERATED FOR YOU', style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.text3, letterSpacing: 0.06)),
              ),
              const SizedBox(height: 8),
              // Result card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.purpleDark.withOpacity(0.15),
                            AppColors.pink.withOpacity(0.1),
                          ]),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                          border: const Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(children: [
                          Container(width: 56, height: 56,
                            decoration: BoxDecoration(gradient: AppColors.gradMixed,
                                borderRadius: BorderRadius.circular(14)),
                            child: const Center(child: Text('❄️', style: TextStyle(fontSize: 26)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Winter Night Drive', style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                            Text('AI · 20 songs · ~1h 18m',
                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, children: [
                              _Tag('Indie', AppColors.purple),
                              _Tag('Alt Rock', AppColors.blue),
                              _Tag('Chill', AppColors.pink),
                            ]),
                          ])),
                        ]),
                      ),
                      _AiTrackMini(emoji: '🌨', gradient: AppColors.gradMixed,
                          title: 'Sweater Weather', artist: 'The Neighbourhood',
                          why: 'Matches snowy, melancholic vibe'),
                      _AiTrackMini(emoji: '⭐',
                          gradient: const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                          title: 'Somebody Else', artist: 'The 1975',
                          why: 'Cold + emotional + driving tempo'),
                      _AiTrackMini(emoji: '🌙',
                          gradient: const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF06b6d4)]),
                          title: 'Snowfall', artist: 'NIKI',
                          why: 'Literally titled Snowfall ❄️'),
                      // Buttons
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x0AFFFFFF)))),
                        child: Row(children: [
                          Expanded(child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(gradient: AppColors.gradPurple,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('Save Playlist', textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
                          const SizedBox(width: 10),
                          Expanded(child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border)),
                            child: Text('Regenerate', textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiParam extends StatelessWidget {
  final String label, value;
  const _AiParam({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.text3, letterSpacing: 0.08)),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.purpleLight)),
      ]),
    );
  }
}

class _AiTrackMini extends StatelessWidget {
  final String emoji, title, artist, why;
  final LinearGradient gradient;
  const _AiTrackMini({required this.emoji, required this.gradient,
      required this.title, required this.artist, required this.why});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
              overflow: TextOverflow.ellipsis),
          Text(artist, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text2)),
          Text(why, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.purpleLight,
              fontStyle: FontStyle.italic)),
        ])),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: GoogleFonts.outfit(
          fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.9))),
    );
  }
}
