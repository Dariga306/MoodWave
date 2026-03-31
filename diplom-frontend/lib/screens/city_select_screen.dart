import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'main/main_screen.dart';

const List<String> _popularCities = [
  // Kazakhstan
  'Astana', 'Almaty', 'Shymkent', 'Karaganda', 'Aktobe',
  'Pavlodar', 'Semey', 'Kostanay', 'Atyrau', 'Oral',
  'Turkistan', 'Taraz', 'Kyzylorda', 'Aktau', 'Temirtau',
  'Zhezkazgan', 'Balkhash',
  // CIS
  'Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg',
  'Bishkek', 'Tashkent', 'Baku', 'Tbilisi', 'Minsk', 'Kyiv',
  // World
  'London', 'Berlin', 'Paris', 'New York', 'Tokyo', 'Dubai',
  'Istanbul', 'Seoul',
];

// Normalize common Russian city name inputs to English
String _normalizeCity(String city) {
  const map = {
    'астана': 'Astana', 'алматы': 'Almaty', 'шымкент': 'Shymkent',
    'москва': 'Moscow', 'санкт-петербург': 'Saint Petersburg',
    'санкт петербург': 'Saint Petersburg', 'питер': 'Saint Petersburg',
    'новосибирск': 'Novosibirsk', 'екатеринбург': 'Yekaterinburg',
    'бишкек': 'Bishkek', 'ташкент': 'Tashkent', 'баку': 'Baku',
    'тбилиси': 'Tbilisi', 'минск': 'Minsk', 'киев': 'Kyiv',
    'киiв': 'Kyiv', 'лондон': 'London', 'берлин': 'Berlin',
    'париж': 'Paris', 'токио': 'Tokyo', 'дубай': 'Dubai',
    'стамбул': 'Istanbul', 'сеул': 'Seoul',
  };
  final key = city.trim().toLowerCase();
  return map[key] ?? city.trim().split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
}

class CitySelectScreen extends StatefulWidget {
  const CitySelectScreen({super.key});

  @override
  State<CitySelectScreen> createState() => _CitySelectScreenState();
}

class _CitySelectScreenState extends State<CitySelectScreen> {
  final _ctrl = TextEditingController();
  String? _selected;
  bool _loading = false;
  String _searchQuery = '';

  List<String> get _filteredCities {
    if (_searchQuery.isEmpty) return _popularCities;
    final q = _searchQuery.toLowerCase();
    return _popularCities.where((c) => c.toLowerCase().contains(q)).toList();
  }

  bool get _showCustomOption {
    if (_searchQuery.length < 2) return false;
    return _filteredCities.isEmpty ||
        !_filteredCities.any((c) => c.toLowerCase() == _searchQuery.toLowerCase());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final raw = _selected ?? (_ctrl.text.trim().isNotEmpty ? _ctrl.text.trim() : null);
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select or enter your city', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF3d0000),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final city = _normalizeCity(raw);
    setState(() => _loading = true);
    try {
      await ApiService().updateMe({'city': city});
      if (mounted) context.read<AuthProvider>().updateUser({'city': city});
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  void _selectCity(String city) {
    setState(() {
      _selected = city;
      _ctrl.text = city;
      _searchQuery = city;
    });
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
            colors: [Color(0xFF0d1a3d), Color(0xFF08080f)],
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
                      _dot(done: true), const SizedBox(width: 6),
                      _dot(active: true),
                    ]),
                    const SizedBox(height: 20),
                    Text('Your city', style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text('For weather moods & local charts',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 16),
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.location_city_rounded, size: 18, color: AppColors.text3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: (v) => setState(() {
                              _searchQuery = v.trim();
                              if (_selected != null && _selected != v.trim()) {
                                _selected = null;
                              }
                            }),
                            style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: 'Search city...',
                              hintStyle: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ]),
                    ),
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
                      children: [
                        ..._filteredCities.map((city) {
                          final sel = _selected == city;
                          return GestureDetector(
                            onTap: () => _selectCity(city),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: sel ? AppColors.gradMixed : null,
                                color: sel ? null : AppColors.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: sel ? Colors.transparent : AppColors.border),
                              ),
                              child: Text(city, style: GoogleFonts.outfit(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppColors.text2)),
                            ),
                          );
                        }),
                        if (_showCustomOption)
                          GestureDetector(
                            onTap: () => _selectCity(_normalizeCity(_searchQuery)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: AppColors.purple.withOpacity(0.4)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_rounded, size: 14, color: AppColors.purpleLight),
                                const SizedBox(width: 4),
                                Text('Use: ${_normalizeCity(_searchQuery)}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: AppColors.purpleLight)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: Builder(builder: (context) {
                  final hasCity = _selected != null || _ctrl.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: (_loading || !hasCity) ? null : _continue,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity, padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: hasCity ? AppColors.primaryBtn
                            : const LinearGradient(colors: [Color(0xFF2a2a3d), Color(0xFF2a2a3d)]),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: hasCity ? [BoxShadow(
                            color: AppColors.purpleDark.withOpacity(0.4),
                            blurRadius: 30, offset: const Offset(0, 12))] : [],
                      ),
                      child: _loading
                          ? const Center(child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                          : Text("Let's go →", textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: hasCity ? Colors.white : AppColors.text3)),
                    ),
                  );
                }),
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
