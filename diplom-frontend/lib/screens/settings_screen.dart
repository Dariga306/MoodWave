import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'equalizer_screen.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'weather_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _crossfade = true;
  bool _activity = false;
  String _streamingQuality = '320';
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _crossfade = prefs.getBool('crossfade') ?? true;
      _streamingQuality = prefs.getString('streaming_quality') ?? '320';
      _activity = prefs.getBool('show_activity') ?? false;
    });
  }

  void _showStreamingQualityDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Streaming Quality',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose audio quality for playback. Higher quality uses more data.',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text2, height: 1.5)),
              const SizedBox(height: 16),
              for (final option in [
                {'label': 'Low (96 kbps)', 'sub': 'Saves data', 'value': '96'},
                {'label': 'Normal (160 kbps)', 'sub': 'Balanced', 'value': '160'},
                {'label': 'High (320 kbps)', 'sub': 'Best quality', 'value': '320'},
              ])
                GestureDetector(
                  onTap: () async {
                    setDialog(() => _streamingQuality = option['value']!);
                    setState(() => _streamingQuality = option['value']!);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('streaming_quality', option['value']!);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _streamingQuality == option['value']
                          ? AppColors.purple.withOpacity(0.15)
                          : AppColors.surface3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _streamingQuality == option['value']
                            ? AppColors.purple.withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(option['label']!,
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text)),
                        Text(option['sub']!,
                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                      ])),
                      if (_streamingQuality == option['value'])
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.purpleLight, size: 20),
                    ]),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done',
                  style: GoogleFonts.outfit(
                      color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Cache?',
            style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text('This will clear cached images and temporary data. Your playlists and account data are kept.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFef4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _clearingCache = true);
    try {
      // Clear Flutter in-memory image cache
      imageCache.clear();
      imageCache.clearLiveImages();
      // Clear SharedPreferences cache keys only (not auth tokens)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('streaming_quality');
      await prefs.remove('crossfade');
      if (mounted) {
        setState(() {
          _clearingCache = false;
          _streamingQuality = '320';
          _crossfade = true;
        });
        showSuccessSnackBar(context, 'Cache cleared successfully');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _clearingCache = false);
        showErrorSnackBar(context, 'Could not clear cache');
      }
    }
  }

  void _openEditProfile() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(user: Map<String, dynamic>.from(user)),
      ),
    );
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showDeactivateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('⏸️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Deactivate Account',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Your account will be hidden for 30 days.',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.text2, height: 1.6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFf59e0b).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFf59e0b).withOpacity(0.2)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoPoint('✅', 'Log back in anytime to restore'),
              _infoPoint('✅', 'All your data is kept safe'),
              _infoPoint('✅', 'Friends cannot see your profile'),
              _infoPoint('⚠️', 'After 30 days → permanently deleted'),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService().deactivateAccount();
                if (!mounted) return;
                await context.read<AuthProvider>().logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              } on DioException catch (e) {
                if (mounted)
                  showErrorSnackBar(context, ErrorHelper.parseError(e));
              }
            },
            child: Text('Deactivate',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFf59e0b),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    final confirmCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Text('🗑️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Delete Account',
                style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'This permanently deletes your account and ALL data. Cannot be undone.',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppColors.text2, height: 1.6),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFef4444).withOpacity(0.2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoPoint('❌', 'All matches deleted'),
                    _infoPoint('❌', 'All chats deleted'),
                    _infoPoint('❌', 'All playlists deleted'),
                    _infoPoint('❌', 'Cannot be recovered'),
                  ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmCtrl,
              onChanged: (_) => setDialogState(() {}),
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type DELETE to confirm',
                hintStyle:
                    GoogleFonts.outfit(color: AppColors.text3, fontSize: 14),
                filled: true,
                fillColor: AppColors.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppColors.text3)),
            ),
            TextButton(
              onPressed: confirmCtrl.text == 'DELETE'
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await ApiService().deleteAccount();
                        if (!mounted) return;
                        context.read<AuthProvider>().logout();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (_) => false);
                      } on DioException catch (e) {
                        if (mounted)
                          showErrorSnackBar(context, ErrorHelper.parseError(e));
                      }
                    }
                  : null,
              child: Text('Delete Forever',
                  style: GoogleFonts.outfit(
                      color: confirmCtrl.text == 'DELETE'
                          ? const Color(0xFFef4444)
                          : AppColors.text3,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCityDialog(String currentCity) async {
    final ctrl = TextEditingController(text: currentCity);
    final newCity = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Your City',
            style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g. Almaty',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3),
            filled: true,
            fillColor: AppColors.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Save',
                style: GoogleFonts.outfit(
                    color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (newCity == null || newCity.isEmpty) return;
    try {
      await ApiService().updateMe({'city': newCity});
      if (mounted) {
        context.read<AuthProvider>().updateUser({'city': newCity});
        showSuccessSnackBar(context, 'City updated to $newCity');
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Could not update city');
    }
  }

  void _showPlaybackSourceInfo() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Playback Sources',
            style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _infoPoint('🎵', 'Track metadata & covers: Deezer API'),
          _infoPoint('▶️', 'Full audio playback: YouTube'),
          _infoPoint('🔍', 'Search & discovery: Deezer catalog'),
          _infoPoint('🎤', 'Artist & album pages: Deezer'),
          const SizedBox(height: 8),
          Text('Audio quality is determined by YouTube and cannot be changed manually.',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.text3, height: 1.5)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.outfit(
                    color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _infoPoint(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text2))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final city = user?['city'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text('Settings',
                    style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.02 * 26)),
              ),
              _SettingsGroup(label: 'Account', children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen())),
                  child: _SettingRow(
                      emoji: '🔑',
                      bg: AppColors.purple.withOpacity(0.15),
                      name: 'Change Password',
                      sub: 'Update your password'),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const NotificationSettingsScreen())),
                  child: _SettingRow(
                      emoji: '🔔',
                      bg: AppColors.blue.withOpacity(0.15),
                      name: 'Notifications',
                      sub: 'Matches, friends, music'),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacySettingsScreen())),
                  child: _SettingRow(
                      emoji: '🔒',
                      bg: const Color(0xFF22c55e).withOpacity(0.15),
                      name: 'Privacy',
                      sub: 'Who can see your activity'),
                ),
              ]),
              _SettingsGroup(label: 'Playback', children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EqualizerScreen())),
                  child: _SettingRow(
                      emoji: '🎚',
                      bg: AppColors.purple.withOpacity(0.15),
                      name: 'Equalizer',
                      sub: 'Custom EQ · Bass Boost on',
                      trailing: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.2)),
                          ),
                          child: Text('Custom',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purpleLight)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.text3, size: 16),
                      ])),
                ),
                GestureDetector(
                  onTap: _showStreamingQualityDialog,
                  child: _SettingRow(
                      emoji: '📶',
                      bg: AppColors.cyan.withOpacity(0.15),
                      name: 'Streaming Quality',
                      sub: 'YouTube playback · Deezer metadata',
                      trailing: Row(children: [
                        Text('$_streamingQuality kbps',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.text3, size: 16),
                      ])),
                ),
                GestureDetector(
                  onTap: _showPlaybackSourceInfo,
                  child: _SettingRow(
                      emoji: '▶️',
                      bg: const Color(0xFFFF0000).withOpacity(0.12),
                      name: 'Playback Source',
                      sub: 'Full tracks from YouTube, covers from Deezer',
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.2)),
                          ),
                          child: Text('Active',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purpleLight)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.text3, size: 16),
                      ])),
                ),
                _SettingRow(
                    emoji: '🔀',
                    bg: AppColors.pink.withOpacity(0.15),
                    name: 'Crossfade',
                    sub: 'Between songs',
                    trailing: _Toggle(
                        value: _crossfade,
                        onChanged: (v) async {
                          setState(() => _crossfade = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('crossfade', v);
                        })),
              ]),
              _SettingsGroup(label: 'Storage', children: [
                GestureDetector(
                  onTap: _clearingCache ? null : _clearCache,
                  child: _SettingRow(
                    emoji: '🗂',
                    bg: AppColors.blue.withOpacity(0.15),
                    name: 'Cache & Storage',
                    sub: 'Clear cached images and temp data',
                    trailing: _clearingCache
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.purpleLight))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Clear',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: const Color(0xFFef4444))),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.text3, size: 16),
                          ]),
                  ),
                ),
              ]),
              _SettingsGroup(label: 'Discovery', children: [
                GestureDetector(
                  onTap: () => _showCityDialog(city),
                  child: _SettingRow(
                      emoji: '📍',
                      bg: AppColors.purple.withOpacity(0.15),
                      name: 'Location for Matching',
                      sub: city.isNotEmpty ? city : 'Tap to set your city',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.text3, size: 16)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WeatherScreen())),
                  child: _SettingRow(
                      emoji: '☁️',
                      bg: AppColors.blue.withOpacity(0.15),
                      name: 'Weather Integration',
                      sub: 'View mood-based recommendations',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.text3, size: 16)),
                ),
                _SettingRow(
                    emoji: '👁',
                    bg: const Color(0xFF22c55e).withOpacity(0.15),
                    name: 'Show My Activity',
                    sub: 'Friends can see what you play',
                    trailing: _Toggle(
                        value: _activity,
                        onChanged: (v) async {
                          setState(() => _activity = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('show_activity', v);
                          try {
                            await ApiService().updateMe({'show_activity': v});
                          } catch (_) {}
                        })),
              ]),
              _SettingsGroup(label: 'Session', children: [
                GestureDetector(
                  onTap: _signOut,
                  child: _SettingRow(
                      emoji: '🚪',
                      bg: AppColors.glass,
                      name: 'Sign Out',
                      sub: 'Log out of your account'),
                ),
                GestureDetector(
                  onTap: _showDeactivateDialog,
                  child: _SettingRow(
                      emoji: '⏸️',
                      bg: const Color(0xFFf59e0b).withOpacity(0.12),
                      name: 'Deactivate for 30 days',
                      sub: 'Hide your account temporarily',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFf59e0b), size: 16)),
                ),
                GestureDetector(
                  onTap: _showDeleteDialog,
                  child: _SettingRow(
                      emoji: '🗑️',
                      bg: const Color(0xFFef4444).withOpacity(0.12),
                      name: 'Delete Account',
                      sub: 'Permanently delete all data',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFef4444), size: 16)),
                ),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _SettingsGroup({required this.label, required this.children});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
                letterSpacing: 0.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18)),
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String emoji, name;
  final Color bg;
  final String? sub;
  final Widget? trailing;
  const _SettingRow(
      {required this.emoji,
      required this.bg,
      required this.name,
      this.sub,
      this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 17)))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          if (sub != null)
            Text(sub!,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        trailing ??
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3, size: 16),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  colors: [AppColors.purpleDark, AppColors.purple])
              : null,
          color: value ? null : AppColors.surface3,
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
