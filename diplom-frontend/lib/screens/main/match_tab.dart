import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../chat_screen.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> {
  List<dynamic> _candidates = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getMatchCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = data;
        _currentIndex = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _current =>
      _candidates.isNotEmpty && _currentIndex < _candidates.length
          ? _candidates[_currentIndex] as Map<String, dynamic>
          : null;

  int get _remaining =>
      _candidates.length > _currentIndex + 1
          ? _candidates.length - _currentIndex - 1
          : 0;

  Future<void> _like() async {
    if (_deciding || _current == null) return;
    final candidate = Map<String, dynamic>.from(_current!);
    final userId = candidate['user_id'] as int;
    setState(() => _deciding = true);
    try {
      final result = await ApiService().decideMatch(userId, 'like');
      if (!mounted) return;
      if (result['is_mutual'] == true) {
        await _showMutualDialog(candidate, result['match_id'] as int? ?? 0);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _deciding = false;
      _currentIndex++;
    });
  }

  Future<void> _skip() async {
    if (_deciding || _current == null) return;
    final userId = _current!['user_id'] as int;
    setState(() => _deciding = true);
    try {
      await ApiService().decideMatch(userId, 'skip');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _deciding = false;
      _currentIndex++;
    });
  }

  Future<void> _showMutualDialog(Map<String, dynamic> candidate, int matchId) async {
    final name = candidate['display_name'] ?? candidate['username'] ?? 'User';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("It's a match! 🎵",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text(
            "$name liked you back! You now have a shared music taste.",
            style: GoogleFonts.outfit(color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    matchId: matchId,
                    partnerName: name,
                    partnerId: candidate['user_id'] as int? ?? 0,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Chat now',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Music Match',
                            style: GoogleFonts.outfit(
                                fontSize: 26, fontWeight: FontWeight.w800,
                                color: AppColors.text, letterSpacing: -0.02 * 26)),
                        const SizedBox(height: 2),
                        Text(
                          _loading
                              ? 'Looking for matches...'
                              : _candidates.isEmpty
                                  ? 'No matches right now'
                                  : '$_remaining more waiting',
                          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded, size: 16, color: AppColors.text2),
                            const SizedBox(width: 6),
                            Text('Refresh',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: AppColors.text2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight)),
              )
            else if (_current == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Center(
                  child: Column(children: [
                    const Text('🎵', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 16),
                    Text('No matches yet',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text('Listen to more music to improve your taste vector\nand find people with similar taste.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryBtn,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('Try again',
                            style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              )
            else
              _buildCard(_current!),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> candidate) {
    final name = candidate['display_name'] ?? candidate['username'] ?? 'User';
    final city = candidate['city'] ?? '';
    final similarity = candidate['similarity_pct'] ?? 0;
    final icebreaker = candidate['icebreaker'] ?? 'You have similar music taste!';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card background with avatar
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1a0533), Color(0xFF0d1a3d), Color(0xFF1a0533)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (city.isNotEmpty)
                        Positioned(
                          top: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22c55e),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(city,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.8))),
                            ]),
                          ),
                        ),
                      Center(
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradMixed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.purpleDark.withOpacity(0.4),
                                  blurRadius: 30),
                            ],
                          ),
                          child: Center(
                            child: Text(initial,
                                style: GoogleFonts.outfit(
                                    fontSize: 36, fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.outfit(
                                        fontSize: 20, fontWeight: FontWeight.w800,
                                        color: AppColors.text)),
                                if (city.isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 14, color: AppColors.text2),
                                    const SizedBox(width: 4),
                                    Text(city,
                                        style: GoogleFonts.outfit(
                                            fontSize: 13, color: AppColors.text2)),
                                  ]),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => const LinearGradient(
                                    colors: [AppColors.purpleLight, AppColors.pink])
                                    .createShader(b),
                                child: Text('$similarity%',
                                    style: GoogleFonts.outfit(
                                        fontSize: 20, fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                              Text('match',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11, color: AppColors.text3)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Icebreaker
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(icebreaker,
                            style: GoogleFonts.outfit(
                                fontSize: 13, height: 1.55,
                                color: AppColors.text2)),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _deciding ? null : _like,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradPurple,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.purpleDark.withOpacity(0.35),
                                        blurRadius: 16)
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.favorite_rounded,
                                        size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(_deciding ? '...' : 'Like',
                                        style: GoogleFonts.outfit(
                                            fontSize: 14, fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: _deciding ? null : _skip,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.glass,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.close_rounded,
                                        size: 18, color: AppColors.text),
                                    const SizedBox(width: 8),
                                    Text('Pass',
                                        style: GoogleFonts.outfit(
                                            fontSize: 14, fontWeight: FontWeight.w700,
                                            color: AppColors.text)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Swipe hints
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _swipeHint('✕', false),
              const SizedBox(width: 20),
              Text('Tap to decide',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
              const SizedBox(width: 20),
              _swipeHint('♥', true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_remaining > 0)
          Center(
            child: Text('$_remaining more people waiting...',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _swipeHint(String symbol, bool isLike) {
    final color = isLike ? const Color(0xFF22c55e) : const Color(0xFFef4444);
    return Row(
      children: [
        if (!isLike) ...[
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Center(
                child: Text(symbol, style: TextStyle(fontSize: 14, color: color))),
          ),
          const SizedBox(width: 6),
          Text('Pass', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ] else ...[
          Text('Like', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
          const SizedBox(width: 6),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Center(
                child: Text(symbol, style: TextStyle(fontSize: 14, color: color))),
          ),
        ],
      ],
    );
  }
}
