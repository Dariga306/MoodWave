import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});
  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  bool _eqOn = true;
  bool _bassBoost = true;
  bool _surround = false;
  bool _normalize = true;
  int _preset = 1;
  final _presets = ['Flat', 'Bass Boost', 'Treble Boost', 'Rock', 'Classical', 'Electronic', 'Vocal'];
  final List<String> _hz = ['60', '150', '400', '1K', '3K', '8K', '16K'];

  // Band values per preset [60Hz, 150Hz, 400Hz, 1kHz, 3kHz, 8kHz, 16kHz]
  static const _presetBands = <List<double>>[
    [0, 0, 0, 0, 0, 0, 0],         // Flat
    [6, 5, 2, 0, -1, -2, -3],      // Bass Boost
    [-2, -1, 0, 2, 4, 6, 6],       // Treble Boost
    [4, 3, 0, -1, 2, 4, 5],        // Rock
    [3, 2, 0, -2, -1, 2, 3],       // Classical
    [4, 2, 0, 3, 2, 4, 5],         // Electronic
    [0, 2, 4, 4, 2, 1, 0],         // Vocal
  ];

  late List<double> _bands;

  @override
  void initState() {
    super.initState();
    _bands = List<double>.from(_presetBands[_preset]);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedPreset = prefs.getInt('eq_preset') ?? 1;
    setState(() {
      _preset = savedPreset;
      _bands = List<double>.from(_presetBands[savedPreset]);
      _eqOn = prefs.getBool('eq_on') ?? true;
      _bassBoost = prefs.getBool('eq_bass_boost') ?? (savedPreset == 1);
      _surround = prefs.getBool('eq_surround') ?? false;
      _normalize = prefs.getBool('eq_normalize') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('eq_preset', _preset);
    await prefs.setBool('eq_on', _eqOn);
    await prefs.setBool('eq_bass_boost', _bassBoost);
    await prefs.setBool('eq_surround', _surround);
    await prefs.setBool('eq_normalize', _normalize);
  }

  void _applyPreset(int index) {
    setState(() {
      _preset = index;
      _bands = List<double>.from(_presetBands[index]);
      _bassBoost = index == 1;
    });
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF080814), Color(0xFF100820), Color(0xFF060e1a)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(bottom: 200, left: 0, right: 0,
              child: Center(child: Container(width: 280, height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    AppColors.purpleDark.withOpacity(0.12), Colors.transparent]),
                )))),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(color: AppColors.glass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border)),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Equalizer', style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                          Text('Audio Settings', style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.text3)),
                        ])),
                        Row(children: [
                          AnimatedMusicBars(
                            color1: AppColors.purpleLight, color2: AppColors.purple,
                            barCount: 3, barWidth: 3, maxHeight: 20),
                          const SizedBox(width: 8),
                          _SmallToggle(value: _eqOn, onChanged: (v) {
                            setState(() => _eqOn = v);
                            _savePrefs();
                          }),
                          const SizedBox(width: 6),
                          Text('On', style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
                        ]),
                      ]),
                    ),
                    // Now playing bar
                    Builder(builder: (ctx) {
                      final player = ctx.watch<PlayerProvider>();
                      final track = player.track;
                      final title = track?['title']?.toString()
                          ?? track?['trackName']?.toString()
                          ?? 'Nothing playing';
                      final artist = track?['artist']?.toString()
                          ?? track?['artistName']?.toString()
                          ?? 'Open the player to start';
                      final cover = track?['cover_url']?.toString()
                          ?? track?['artworkUrl100']?.toString();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                  gradient: AppColors.gradMixed,
                                  borderRadius: BorderRadius.circular(10)),
                              child: cover != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                          imageUrl: cover,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Center(
                                              child: Text('🎵',
                                                  style: TextStyle(fontSize: 20)))))
                                  : const Center(
                                      child: Text('🎵', style: TextStyle(fontSize: 20))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text2)),
                            ])),
                            if (player.isPlaying)
                              AnimatedMusicBars(
                                  color1: AppColors.purpleLight, color2: AppColors.pink,
                                  barCount: 3, barWidth: 3, maxHeight: 20),
                          ]),
                        ),
                      );
                    }),
                    // EQ Bands
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (i) {
                            final val = _bands[i];
                            final isNeg = val < 0;
                            return Expanded(
                              child: GestureDetector(
                                onVerticalDragUpdate: (d) {
                                  setState(() {
                                    _bands[i] = (_bands[i] - d.delta.dy / 10).clamp(-12.0, 12.0);
                                  });
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(val == 0 ? '0' : '${val > 0 ? '+' : ''}${val.toStringAsFixed(0)}',
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700,
                                            color: isNeg ? AppColors.pinkLight : AppColors.purpleLight)),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 120,
                                      child: Stack(alignment: Alignment.center, children: [
                                        Container(width: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        // Center line
                                        Positioned(top: 60,
                                          child: Container(height: 1, width: 16,
                                            color: Colors.white.withOpacity(0.15))),
                                        // Fill
                                        Positioned(
                                          top: isNeg ? 60 : 60 - (val / 12) * 55,
                                          child: Container(
                                            width: 4,
                                            height: (val.abs() / 12 * 55).clamp(0, 55),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: isNeg ? Alignment.topCenter : Alignment.bottomCenter,
                                                end: isNeg ? Alignment.bottomCenter : Alignment.topCenter,
                                                colors: isNeg
                                                    ? [AppColors.pinkLight, AppColors.pink]
                                                    : [AppColors.purpleLight, AppColors.purpleDark],
                                              ),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                          ),
                                        ),
                                        // Thumb
                                        Positioned(
                                          top: 60 - (val / 12) * 55 - 8,
                                          child: Container(
                                            width: 16, height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.white, shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(
                                                  color: AppColors.purple.withOpacity(0.5), blurRadius: 8)],
                                            ),
                                          ),
                                        ),
                                      ]),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(_hz[i], style: GoogleFonts.outfit(
                                        fontSize: 9, fontWeight: FontWeight.w600,
                                        color: AppColors.text3, letterSpacing: 0.03)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Presets
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20),
                        itemCount: _presets.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _applyPreset(i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _preset == i ? AppColors.gradPurple : null,
                              color: _preset == i ? null : AppColors.glass,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                  color: _preset == i ? AppColors.purple : AppColors.border),
                            ),
                            child: Text(_presets[i], style: GoogleFonts.outfit(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _preset == i ? Colors.white : AppColors.text2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Extra settings
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [
                        _EqRow(emoji: '🔊', bg: AppColors.purple.withOpacity(0.15),
                            name: 'Bass Boost', sub: 'Enhance low frequencies',
                            toggle: _SmallToggle(value: _bassBoost,
                                onChanged: (v) { setState(() => _bassBoost = v); _savePrefs(); })),
                        const SizedBox(height: 8),
                        _EqRow(emoji: '🎧', bg: AppColors.blue.withOpacity(0.15),
                            name: '3D Surround', sub: 'Virtual spatial audio',
                            toggle: _SmallToggle(value: _surround,
                                onChanged: (v) { setState(() => _surround = v); _savePrefs(); })),
                        const SizedBox(height: 8),
                        _EqRow(emoji: '🔇', bg: const Color(0xFF22c55e).withOpacity(0.15),
                            name: 'Loudness Normalize', sub: 'Consistent volume across songs',
                            toggle: _SmallToggle(value: _normalize,
                                onChanged: (v) { setState(() => _normalize = v); _savePrefs(); })),
                      ]),
                    ),
                    const SizedBox(height: 32),
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

class _EqRow extends StatelessWidget {
  final String emoji, name, sub;
  final Color bg;
  final Widget toggle;
  const _EqRow({required this.emoji, required this.bg, required this.name,
      required this.sub, required this.toggle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 15)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text(sub, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ])),
        toggle,
      ]),
    );
  }
}

class _SmallToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SmallToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38, height: 22,
        decoration: BoxDecoration(
          gradient: value ? const LinearGradient(colors: [AppColors.purpleDark, AppColors.purple]) : null,
          color: value ? null : AppColors.surface3,
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}
