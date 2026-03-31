import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';

// ══════════════════════════════════════════
// LISTENING PARTY
// ══════════════════════════════════════════
class ListeningPartyScreen extends StatefulWidget {
  const ListeningPartyScreen({super.key});
  @override
  State<ListeningPartyScreen> createState() => _ListeningPartyScreenState();
}

class _ListeningPartyScreenState extends State<ListeningPartyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.glass,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AnimatedBuilder(
                              animation: _blinkCtrl,
                              builder: (_, __) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFef4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFFef4444).withOpacity(0.25)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Opacity(opacity: 0.3 + 0.7 * _blinkCtrl.value,
                                    child: Container(width: 7, height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFef4444), shape: BoxShape.circle))),
                                  const SizedBox(width: 6),
                                  Text('LIVE PARTY', style: GoogleFonts.outfit(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFf87171))),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Winter Vibes Night', style: GoogleFonts.outfit(
                                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.02 * 20)),
                            Text('Hosted by Aigerim', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
                          ]),
                        ),
                      ),
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.glass,
                            borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: const Icon(Icons.local_bar_rounded, size: 18, color: AppColors.text2)),
                    ]),
                  ],
                ),
              ),
            ),
            // Cover area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(24)),
                child: Stack(children: [
                  Container(decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(24))),
                  const Center(child: Text('🌨', style: TextStyle(fontSize: 80))),
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(8, (i) => AnimatedMusicBars(
                          color1: AppColors.purpleLight, color2: AppColors.pink,
                          barCount: 1, barWidth: 4, maxHeight: 30)),
                      ),
                    )),
                ]),
              ),
            ),
            // Now playing
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(width: 52, height: 52,
                  decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(13)),
                  child: const Center(child: Text('🌨', style: TextStyle(fontSize: 24)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sweater Weather', style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  Text('The Neighbourhood', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                  const SizedBox(height: 6),
                  Stack(children: [
                    Container(height: 3, decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(100))),
                    FractionallySizedBox(widthFactor: 0.42, child: Container(height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                        borderRadius: BorderRadius.circular(100)))),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('1:24', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                    Text('3:51', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                  ]),
                ])),
              ]),
            ),
            // Listeners
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LISTENING TOGETHER · 8 PEOPLE', style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2, letterSpacing: 0.04)),
                  const SizedBox(height: 12),
                  Row(children: [
                    ...[('A', AppColors.gradMixed, 6), ('D', AppColors.gradBlue, 5),
                      ('M', AppColors.gradPink, 4), ('K', AppColors.gradTeal, 3),
                      ('S', AppColors.gradOrange, 2)].map((p) => Transform.translate(
                      offset: Offset(-8.0 * (6 - p.$3), 0),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(gradient: p.$2, shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2)),
                        child: Center(child: Text(p.$1, style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))))),
                    Transform.translate(
                      offset: const Offset(-40, 0),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2)),
                        child: Center(child: Text('+3', style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2))))),
                  ]),
                  const SizedBox(height: 4),
                  Text('All listening in sync 🎵', style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                ]),
              ),
            ),
            // Live chat
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  _PartyMsg('D', AppColors.gradBlue, 'Daniyar', 'this song is perfect for tonight ❄️'),
                  _PartyMsg('M', AppColors.gradPink, 'Madi', 'omg yes!! 🥺🥺'),
                  _PartyMsg('A', AppColors.gradMixed, 'Aigerim · Host', 'next up is Snowfall by NIKI 🌨',
                      isHost: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: AppColors.surface2,
                    child: Row(children: [
                      Expanded(child: Text('React or type...', style: GoogleFonts.outfit(
                          fontSize: 14, color: AppColors.text3))),
                      Text('❤️ 🔥 😭', style: const TextStyle(fontSize: 18)),
                    ]),
                  ),
                ]),
              ),
            ),
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.glass,
                      borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.queue_music_rounded, size: 16, color: AppColors.text),
                    const SizedBox(width: 8),
                    Text('Add Song', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ]))),
                const SizedBox(width: 10),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: AppColors.gradPurple,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.35), blurRadius: 16)]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Invite Friends', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyMsg extends StatelessWidget {
  final String letter, name, text;
  final LinearGradient gradient;
  final bool isHost;
  const _PartyMsg(this.letter, this.gradient, this.name, this.text, {this.isHost = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
          child: Center(child: Text(letter, style: GoogleFonts.outfit(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700,
              color: isHost ? AppColors.pink : AppColors.purpleLight)),
          Text(text, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// DISCOVER / GLOBAL
// ══════════════════════════════════════════
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _tab = 0;
  final _tabs = ['🌍 Global', '🔥 Viral', '🆕 New Releases', '📈 Rising'];

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Discover', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.glass,
                        borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.text2)),
                ]),
              ),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  itemCount: _tabs.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: _tab == i ? AppColors.gradPurple : null,
                        color: _tab == i ? null : AppColors.glass,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: _tab == i ? AppColors.purple : AppColors.border),
                      ),
                      child: Text(_tabs[i], style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _tab == i ? Colors.white : AppColors.text2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Global card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF14062D).withOpacity(0.9),
                      const Color(0xFF08081C).withOpacity(0.9),
                    ]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.purple.withOpacity(0.2)),
                  ),
                  child: Stack(children: [
                    Positioned(top: -30, right: -30,
                      child: Container(width: 140, height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [AppColors.purple.withOpacity(0.15), Colors.transparent])))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🌍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('Global Top 50', style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.02 * 22)),
                      Text('Updated every 24 hours', style: GoogleFonts.outfit(
                          fontSize: 13, color: const Color(0x99C8B4FF))),
                      const SizedBox(height: 14),
                      Row(children: [
                        _GcStat('2.1B', 'plays today'),
                        const SizedBox(width: 20),
                        _GcStat('184', 'countries'),
                        const SizedBox(width: 20),
                        _GcStat('47M', 'listeners'),
                      ]),
                    ]),
                  ]),
                ),
              ),
              const SectionHeader(title: 'Trending by Country', action: 'All →'),
              const SizedBox(height: 8),
              _CountryRow('🇺🇸', 'United States', "APT. — Rose ft. Bruno Mars", '1', isGold: true),
              _CountryRow('🇰🇷', 'South Korea', 'How Sweet — NewJeans', '2', isSilver: true),
              _CountryRow('🇰🇿', 'Kazakhstan', 'Sweater Weather — The Neighbourhood', '3', isBronze: true),
              _CountryRow('🇬🇧', 'United Kingdom', "Good Luck Babe! — Chappell Roan", '4'),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Viral This Week', action: 'More →'),
              const SizedBox(height: 12),
              _TrendBar("APT. · Rose ft. Bruno Mars", "412M plays", 0.95,
                  const LinearGradient(colors: [Color(0xFF7c3aed), AppColors.pink])),
              const SizedBox(height: 10),
              _TrendBar("Die With A Smile · Lady Gaga", "389M", 0.82,
                  const LinearGradient(colors: [Color(0xFF1e3a8a), AppColors.blue])),
              const SizedBox(height: 10),
              _TrendBar("Espresso · Sabrina Carpenter", "340M", 0.74,
                  const LinearGradient(colors: [Color(0xFF92400e), Color(0xFFf59e0b)])),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GcStat extends StatelessWidget {
  final String value, label;
  const _GcStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700,
        color: const Color(0xE6C8B4FF))),
    Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0x80C8B4FF))),
  ]);
}

class _CountryRow extends StatelessWidget {
  final String flag, country, track, pos;
  final bool isGold, isSilver, isBronze;
  const _CountryRow(this.flag, this.country, this.track, this.pos,
      {this.isGold = false, this.isSilver = false, this.isBronze = false});
  @override
  Widget build(BuildContext context) {
    Color posColor = isGold ? const Color(0xFFf59e0b)
        : isSilver ? const Color(0xFF94a3b8)
        : isBronze ? const Color(0xFFc2774a) : AppColors.text3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
          child: Center(child: Text(flag, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(country, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text(track, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2),
              overflow: TextOverflow.ellipsis),
        ])),
        Text(pos, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: posColor)),
      ]),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final String label, plays;
  final double pct;
  final LinearGradient gradient;
  const _TrendBar(this.label, this.plays, this.pct, this.gradient);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis)),
        Text(plays, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 4, decoration: BoxDecoration(
            color: AppColors.surface3, borderRadius: BorderRadius.circular(100))),
        FractionallySizedBox(widthFactor: pct, child: Container(height: 4,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(100)))),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════
// CITY CHARTS
// ══════════════════════════════════════════
class CityChartsScreen extends StatefulWidget {
  const CityChartsScreen({super.key});
  @override
  State<CityChartsScreen> createState() => _CityChartsScreenState();
}

class _CityChartsScreenState extends State<CityChartsScreen> with SingleTickerProviderStateMixin {
  int _city = 0;
  late AnimationController _blinkCtrl;
  final _cities = ['📍 Astana', '🌆 Almaty', '🏙 Shymkent', '🌍 Kazakhstan'];

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('City Charts', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.glass,
                        borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.search_rounded, size: 18, color: AppColors.text2)),
                ]),
              ),
              // City hero
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF080A28), Color(0xFF0D0D1A)]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.blue.withOpacity(0.2)),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: RadialGradient(center: const Alignment(0.7, 0),
                        colors: [AppColors.blue.withOpacity(0.1), Colors.transparent])))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('🇰🇿', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text('Astana', style: GoogleFonts.outfit(
                            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                      ]),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _blinkCtrl,
                        builder: (_, __) => Row(children: [
                          Opacity(opacity: 0.3 + 0.7 * _blinkCtrl.value,
                            child: Container(width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22c55e), shape: BoxShape.circle))),
                          const SizedBox(width: 5),
                          Text('Updated live · just now', style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF22c55e))),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [AppColors.blueLight, AppColors.cyan]).createShader(b),
                        child: Text('4,821', style: GoogleFonts.outfit(
                            fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      Text('people streaming right now in your city',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                    ]),
                  ]),
                ),
              ),
              // City switcher
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  itemCount: _cities.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _city = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _city == i
                            ? AppColors.blue.withOpacity(0.2) : AppColors.glass,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: _city == i ? AppColors.blue.withOpacity(0.4) : AppColors.border),
                      ),
                      child: Text(_cities[i], style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _city == i ? AppColors.blueLight : AppColors.text2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Chart items
              _ChartItem('1', '🌨', AppColors.gradMixed, 'Sweater Weather', 'The Neighbourhood', '3:51', '▲ 2', true, isGold: true),
              _ChartItem('2', '🌊', const LinearGradient(colors: [Color(0xFF1e3a8a), Color(0xFF06b6d4)]), 'Midnight Rain', 'Taylor Swift', '3:42', '—', false, isSilver: true),
              _ChartItem('3', '🌿', AppColors.gradTeal, 'Snowfall', 'NIKI', '3:18', 'NEW', false, isBronze: true, isNew: true),
              _ChartItem('4', '⭐', const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]), 'Somebody Else', 'The 1975', '5:02', '▲ 5', true),
              _ChartItem('5', '🎸', const LinearGradient(colors: [Color(0xFF4c1d95), Color(0xFF7c3aed)]), 'R U Mine?', 'Arctic Monkeys', '3:21', '▲ 1', true),
              _ChartItem('6', '🌹', AppColors.gradPink, 'Creep', 'Radiohead', '3:56', '—', false),
              _ChartItem('7', '🎤', const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)]), 'HUMBLE.', 'Kendrick Lamar', '2:57', '▲ 3', true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartItem extends StatelessWidget {
  final String num, emoji, title, artist, dur, trend;
  final LinearGradient gradient;
  final bool isUp, isGold, isSilver, isBronze, isNew;
  const _ChartItem(this.num, this.emoji, this.gradient, this.title, this.artist,
      this.dur, this.trend, this.isUp, {this.isGold = false, this.isSilver = false,
        this.isBronze = false, this.isNew = false});
  @override
  Widget build(BuildContext context) {
    Color numColor = isGold ? const Color(0xFFf59e0b)
        : isSilver ? const Color(0xFF94a3b8)
        : isBronze ? const Color(0xFFc2774a) : AppColors.text3;
    Color trendColor = isNew ? AppColors.purpleLight
        : isUp ? const Color(0xFF22c55e) : const Color(0xFF94a3b8);
    Color trendBg = isNew ? AppColors.purple.withOpacity(0.12)
        : isUp ? const Color(0xFF22c55e).withOpacity(0.1)
        : const Color(0xFF94a3b8).withOpacity(0.08);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        SizedBox(width: 24, child: Text(num, textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: numColor))),
        const SizedBox(width: 14),
        Container(width: 46, height: 46,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(11)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              overflow: TextOverflow.ellipsis),
          Text(artist, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(dur, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: trendBg, borderRadius: BorderRadius.circular(100)),
            child: Text(trend, style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700, color: trendColor))),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// RADIO
// ══════════════════════════════════════════
class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Radio', style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: AppColors.text, letterSpacing: -0.02 * 26)),
                  Text('Create Station', style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purpleLight)),
                ]),
              ),
              // Live now card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(children: [
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)])),
                      child: Stack(children: [
                        Container(color: Colors.black.withOpacity(0.1)),
                        const Center(child: Text('📻', style: TextStyle(fontSize: 64))),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: SizedBox(height: 40,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) => const AnimatedMusicBars(
                                color1: AppColors.purpleLight, color2: AppColors.pink,
                                barCount: 1, barWidth: 4, maxHeight: 28)))),
                        ),
                      ]),
                    ),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 7, height: 7,
                              decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('ON AIR', style: GoogleFonts.outfit(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.pink, letterSpacing: 0.12)),
                          ]),
                          const SizedBox(height: 4),
                          Text('MoodWave Indie Radio', style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.01 * 18)),
                          Text('Sweater Weather — The Neighbourhood',
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2)),
                          Text('🎧 1,284 listeners now',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                        ])),
                        Row(children: [
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.pink.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppColors.pink, size: 18)),
                          const SizedBox(width: 8),
                          Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 14)],
                            ),
                            child: const Icon(Icons.pause_rounded, color: Colors.white, size: 22)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SectionHeader(title: 'Featured Stations', action: 'All →'),
              const SizedBox(height: 12),
              _RadioCard('🎸', 'Indie Night Radio', 'Indie · Alt Rock', '847',
                  const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed)])),
              _RadioCard('❄️', 'Winter Chill Radio', 'Ambient · Lo-fi · Snow vibes', '2,134',
                  const LinearGradient(colors: [Color(0xFF164e63), Color(0xFF06b6d4)])),
              _RadioCard('✨', 'K-Pop Hits Radio', 'K-Pop · Korean Pop · BTS, NewJeans', '5,412',
                  const LinearGradient(colors: [Color(0xFF9d174d), Color(0xFFec4899)])),
              _RadioCard('🎤', 'Hip-Hop Central', 'Hip-Hop · Trap · R&B', '3,891',
                  const LinearGradient(colors: [Color(0xFF1c1917), Color(0xFF57534e)])),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  final String emoji, name, genre, listeners;
  final LinearGradient gradient;
  const _RadioCard(this.emoji, this.name, this.genre, this.listeners, this.gradient);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 100,
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(children: [
            Container(color: Colors.black.withOpacity(0.2)),
            Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
            Positioned(bottom: 12, left: 16, right: 60, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(genre, style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.white.withOpacity(0.6))),
              ])),
            Positioned(top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(children: [
                  Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: Color(0xFF22c55e), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(listeners, style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.8))),
                ]),
              )),
            Positioned(bottom: 12, right: 12,
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20))),
          ]),
        ),
      ),
    );
  }
}
