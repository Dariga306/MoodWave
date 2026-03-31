import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Shows Add to Playlist bottom sheet
void showAddToPlaylist(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AddToPlaylistSheet(),
  );
}

/// Shows Share Track bottom sheet
void showShareTrack(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ShareTrackSheet(),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  const _AddToPlaylistSheet();
  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final Set<int> _added = {0};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Add to Playlist', style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          ),
          // Track row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(gradient: AppColors.gradMixed, borderRadius: BorderRadius.circular(13)),
                child: const Center(child: Text('🌨', style: TextStyle(fontSize: 24)))),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sweater Weather', style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text('The Neighbourhood · 3:51',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2)),
              ]),
            ]),
          ),
          Divider(color: AppColors.border, height: 1),
          // New playlist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.purpleDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.purple.withOpacity(0.3), style: BorderStyle.solid),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.purpleLight, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New Playlist', style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                Text('Create a new playlist',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              ]),
            ]),
          ),
          // Playlist rows
          ...[
            ('❄️', const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed)]),
                'Winter Nights', '18 songs · Collab', 0),
            ('🌙', const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF312e81)]),
                'Late Night Drive', '32 songs', 1),
            ('🎧', AppColors.gradMixed, 'Liked Songs', '847 songs', 2),
            ('🏃', const LinearGradient(colors: [Color(0xFF064e3b), Color(0xFF10b981)]),
                'Workout Anthems', '24 songs', 3),
          ].map((p) {
            final isAdded = _added.contains(p.$5);
            return GestureDetector(
              onTap: () => setState(() {
                if (isAdded) _added.remove(p.$5); else _added.add(p.$5);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x08FFFFFF)))),
                child: Row(children: [
                  Container(width: 46, height: 46,
                    decoration: BoxDecoration(gradient: p.$2, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(p.$1, style: const TextStyle(fontSize: 20)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.$3, style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(p.$4, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                  ])),
                  if (isAdded)
                    Container(width: 24, height: 24,
                      decoration: BoxDecoration(gradient: AppColors.gradPurple, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 12))
                  else
                    Container(width: 24, height: 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border2, width: 1.5))),
                ]),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.4), blurRadius: 20)],
              ),
              child: Text('Done', textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareTrackSheet extends StatelessWidget {
  const _ShareTrackSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text('Share Track', style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          ),
          // Preview card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF7c3aed), Color(0xFF0d1a3d)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border2),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(width: 68, height: 68,
                  decoration: BoxDecoration(gradient: AppColors.gradMixed,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)]),
                  child: const Center(child: Text('🌨', style: TextStyle(fontSize: 32)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sweater Weather', style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.01 * 18)),
                  Text('The Neighbourhood', style: GoogleFonts.outfit(
                      fontSize: 14, color: const Color(0xB3C8B4FF))),
                  const SizedBox(height: 10),
                  Container(height: 3, decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                    child: FractionallySizedBox(widthFactor: 0.38, alignment: Alignment.centerLeft,
                      child: Container(decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
                        borderRadius: BorderRadius.circular(100))))),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.graphic_eq_rounded, size: 10, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('MoodWave', style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white54)),
                  ]),
                ])),
              ]),
            ),
          ),
          // Apps
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text('SHARE TO', style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ShareApp('💬', 'WhatsApp', const LinearGradient(colors: [Color(0xFF075e54), Color(0xFF25d366)])),
              _ShareApp('📘', 'Messenger', const LinearGradient(colors: [Color(0xFF1877f2), Color(0xFF42a5f5)])),
              _ShareApp('✈️', 'Telegram', const LinearGradient(colors: [Color(0xFF0088cc), Color(0xFF29b6f6)])),
              _ShareApp('📸', 'Instagram', const LinearGradient(colors: [Color(0xFFe1306c), Color(0xFFfd1d1d), Color(0xFFf56040)])),
              _ShareApp('💌', 'In Chat', null),
            ]),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.text),
                  const SizedBox(width: 8),
                  Text('Copy Link', style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                ]))),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppColors.gradPurple,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.purpleDark.withOpacity(0.35), blurRadius: 16)]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Share to Story', style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ]))),
            ]),
          ),
          // Send to match
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.purple.withOpacity(0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.favorite_rounded, color: AppColors.purpleLight, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Send to Match', style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.purpleLight)),
                  Text('Daniyar, Madi and 3 others',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareApp extends StatelessWidget {
  final String emoji, name;
  final LinearGradient? gradient;
  const _ShareApp(this.emoji, this.name, this.gradient);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? AppColors.surface2 : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))),
      const SizedBox(height: 7),
      Text(name, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2)),
    ]);
  }
}
