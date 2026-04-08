import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'main/main_screen.dart';

// Popular cities shown before typing
const List<String> _popularCities = [
  'New York',
  'London',
  'Paris',
  'Tokyo',
  'Dubai',
  'Berlin',
  'Sydney',
  'Toronto',
  'Seoul',
  'Beijing',
  'Mumbai',
  'Istanbul',
  'Barcelona',
  'Amsterdam',
  'Vienna',
  'Prague',
  'Warsaw',
  'Kyiv',
  'Moscow',
  'Saint Petersburg',
  'Almaty',
  'Astana',
  'Tashkent',
  'Bishkek',
  'Baku',
  'Tbilisi',
  'Yerevan',
  'Minsk',
  'Riga',
  'Vilnius',
  'Tallinn',
  'Helsinki',
  'Stockholm',
  'Oslo',
  'Copenhagen',
  'Lisbon',
  'Madrid',
  'Rome',
  'Milan',
  'Athens',
  'Budapest',
  'Bucharest',
  'Sofia',
  'Belgrade',
  'Zagreb',
  'Sarajevo',
  'Singapore',
  'Bangkok',
  'Jakarta',
  'Kuala Lumpur',
  'Manila',
  'Ho Chi Minh City',
  'Hanoi',
  'Dhaka',
  'Karachi',
  'Lahore',
  'Cairo',
  'Lagos',
  'Nairobi',
  'Casablanca',
  'Johannesburg',
  'São Paulo',
  'Buenos Aires',
  'Rio de Janeiro',
  'Bogotá',
  'Lima',
  'Santiago',
  'Mexico City',
  'Los Angeles',
  'Chicago',
  'Houston',
];

String _capitalize(String s) => s.trim().isEmpty
    ? s
    : s
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

class CitySelectScreen extends StatefulWidget {
  const CitySelectScreen({super.key});

  @override
  State<CitySelectScreen> createState() => _CitySelectScreenState();
}

class _CitySelectScreenState extends State<CitySelectScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  bool _dropdownVisible = false;
  bool _searchLoading = false;
  List<String> _networkCities = [];
  String _selected = '';
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Do NOT close dropdown on focus loss — controlled manually.
    // This prevents the dropdown from closing before tap fires on web.
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<String> get _suggestions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _popularCities.take(12).toList();
    if (_networkCities.isNotEmpty) return _networkCities;
    return _popularCities
        .where((c) => c.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  void _onChanged(String value) {
    setState(() {
      _networkCities = [];
      _searchQuery = value;
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchCities(q));
  }

  Future<void> _fetchCities(String q) async {
    if (!mounted) return;
    setState(() => _searchLoading = true);
    try {
      final cities = await ApiService().searchCities(q);
      if (!mounted) return;
      setState(() => _networkCities = cities);
    } catch (_) {
      // silently fall back to local suggestions
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  String _friendlyError(dynamic e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'Session expired. Please sign in again.';
      if (code == 403) return 'Please verify your email before continuing.';
      if (code == 422) return 'Please enter a valid city name.';
      if (code != null && code >= 500)
        return 'Server is unavailable. Try again later.';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown)
        return 'No internet connection. Please try again.';
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout)
        return 'Request timed out. Try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _continue() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter your city', style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF3d0000),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final city = _capitalize(raw);
    setState(() => _loading = true);

    // Save city locally immediately so it's never lost
    context.read<AuthProvider>().updateUser({'city': city});

    try {
      await ApiService().updateMe({'city': city});
    } catch (_) {
      // Backend unavailable — city already saved locally, continue silently
    }

    if (!mounted) return;
    await context.read<AuthProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final showDropdown =
        _dropdownVisible && (_suggestions.isNotEmpty || _searchLoading);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        onTap: () {
          _focus.unfocus();
          setState(() => _dropdownVisible = false);
        },
        child: Container(
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
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _dot(done: true),
                            const SizedBox(width: 6),
                            _dot(done: true),
                            const SizedBox(width: 6),
                            _dot(done: true),
                            const SizedBox(width: 6),
                            _dot(active: true),
                          ]),
                      const SizedBox(height: 20),
                      Text('Your city',
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text('For weather moods & local charts',
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: AppColors.text2)),
                      const SizedBox(height: 20),
                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _focus.hasFocus
                                  ? AppColors.purple.withOpacity(0.6)
                                  : AppColors.border),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 14),
                          _searchLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.text3))
                              : const Icon(Icons.search_rounded,
                                  size: 20, color: AppColors.text3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onChanged: _onChanged,
                              onTap: () =>
                                  setState(() => _dropdownVisible = true),
                              style: GoogleFonts.outfit(
                                  fontSize: 16, color: AppColors.text),
                              decoration: InputDecoration(
                                hintText: 'Search any city in the world...',
                                hintStyle: GoogleFonts.outfit(
                                    fontSize: 16, color: AppColors.text3),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                setState(() => _networkCities = []);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.text3),
                              ),
                            ),
                        ]),
                      ),
                      // Dropdown suggestions
                      if (showDropdown)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: _searchLoading && _suggestions.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.purpleLight),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _suggestions.length,
                                      itemBuilder: (_, i) {
                                        final cityName = _suggestions[i];
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFF7C3AED),
                                            size: 18,
                                          ),
                                          title: Text(
                                            cityName,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selected = cityName;
                                              _ctrl.text = cityName;
                                              _searchQuery = cityName;
                                              _dropdownVisible = false;
                                              _networkCities = [];
                                            });
                                            FocusScope.of(context).unfocus();
                                          },
                                          tileColor: _selected == cityName
                                              ? const Color(0xFF7C3AED)
                                                  .withOpacity(0.15)
                                              : Colors.transparent,
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  child: GestureDetector(
                    onTap: _loading ? null : _continue,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: _ctrl.text.trim().isNotEmpty
                            ? AppColors.primaryBtn
                            : const LinearGradient(
                                colors: [Color(0xFF2a2a3d), Color(0xFF2a2a3d)]),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _ctrl.text.trim().isNotEmpty
                            ? [
                                BoxShadow(
                                    color:
                                        AppColors.purpleDark.withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12))
                              ]
                            : [],
                      ),
                      child: _loading
                          ? const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)))
                          : Text("Let's go →",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ctrl.text.trim().isNotEmpty
                                      ? Colors.white
                                      : AppColors.text3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot({bool done = false, bool active = false}) {
    final w = done
        ? 20.0
        : active
            ? 14.0
            : 7.0;
    final c = done
        ? AppColors.purple
        : active
            ? AppColors.purpleLight
            : AppColors.surface3;
    return Container(
        width: w,
        height: 7,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(100)));
  }
}
