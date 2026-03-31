import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'city_select_screen.dart';

const List<Map<String, String>> _allMoods = [
  {'key': 'study', 'label': 'Study', 'emoji': '📚'},
  {'key': 'workout', 'label': 'Workout', 'emoji': '🏃'},
  {'key': 'sleep', 'label': 'Sleep', 'emoji': '😴'},
  {'key': 'driving', 'label': 'Driving', 'emoji': '🚗'},
  {'key': 'party', 'label': 'Party', 'emoji': '🎉'},
  {'key': 'sad', 'label': 'Sad', 'emoji': '😢'},
  {'key': 'morning', 'label': 'Morning', 'emoji': '☕'},
  {'key': 'late_night', 'label': 'Late Night', 'emoji': '🌙'},
];

class MoodSelectScreen extends StatefulWidget {
  const MoodSelectScreen({super.key});

  @override
  State<MoodSelectScreen> createState() => _MoodSelectScreenState();
}

class _MoodSelectScreenState extends State<MoodSelectScreen> {
  final Set<String> _selected = {};
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final moods = _selected
          .map((k) => {'mood': k, 'weight': 1.0})
          .toList();
      if (moods.isNotEmpty) {
        await ApiService().saveMoods(moods);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CitySelectScreen()));
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
                      _dot(done: true),
                      const SizedBox(width: 6),
                      _dot(done: true),
                      const SizedBox(width: 6),
                      _dot(active: true),
                      const SizedBox(width: 6),
                      _dot(),
                    ]),
                    const SizedBox(height: 20),
                    Text('Your vibes',
                        style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text('What moods do you listen to music in?',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: _allMoods.map((m) {
                      final sel = _selected.contains(m['key']);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) {
                            _selected.remove(m['key']);
                          } else {
                            _selected.add(m['key']!);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: sel ? AppColors.gradMixed : null,
                            color: sel ? null : AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: sel
                                  ? Colors.transparent
                                  : AppColors.border,
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: AppColors.purpleDark
                                            .withOpacity(0.3),
                                        blurRadius: 12)
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(m['emoji']!,
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(m['label']!,
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.text2)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: GestureDetector(
                  onTap: _loading ? null : _continue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryBtn,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.purpleDark.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 12))
                      ],
                    ),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : Text('Continue →',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
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
    final c = done
        ? AppColors.purple
        : active
            ? AppColors.purpleLight
            : AppColors.surface3;
    return Container(
      width: w,
      height: 7,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(100)),
    );
  }
}
