import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'equalizer_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _crossfade = true;
  bool _activity = false;

  void _openEditProfile() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: Map<String, dynamic>.from(user)),
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
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Your account will be hidden for 30 days.',
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2, height: 1.6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFf59e0b).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFf59e0b).withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
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
                if (mounted) showErrorSnackBar(context, ErrorHelper.parseError(e));
              }
            },
            child: Text('Deactivate',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFf59e0b), fontWeight: FontWeight.w700)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Text('🗑️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Delete Account',
                style: GoogleFonts.outfit(
                    fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'This permanently deletes your account and ALL data. Cannot be undone.',
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2, height: 1.6),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFef4444).withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                hintStyle: GoogleFonts.outfit(color: AppColors.text3, fontSize: 14),
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
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3)),
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
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false);
                      } on DioException catch (e) {
                        if (mounted) showErrorSnackBar(context, ErrorHelper.parseError(e));
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

  Widget _infoPoint(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text2))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final displayName = user?['display_name'] ?? user?['username'] ?? 'User';
    final city = user?['city'] ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

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
              // User card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _openEditProfile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.purpleDark.withOpacity(0.1),
                        AppColors.pink.withOpacity(0.07),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.purple.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              gradient: AppColors.gradMixed,
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(displayName,
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text)),
                            if (city.isNotEmpty)
                              Text(city,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.text3)),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.text3),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SettingsGroup(label: 'Account', children: [
                GestureDetector(
                  onTap: _openEditProfile,
                  child: _SettingRow(
                      emoji: '👤',
                      bg: AppColors.purple.withOpacity(0.15),
                      name: 'Edit Profile',
                      sub: 'Photo, name, username'),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen())),
                  child: _SettingRow(
                      emoji: '🔑',
                      bg: AppColors.purple.withOpacity(0.15),
                      name: 'Change Password',
                      sub: 'Update your password'),
                ),
                _SettingRow(
                    emoji: '🔔',
                    bg: AppColors.blue.withOpacity(0.15),
                    name: 'Notifications',
                    sub: 'Matches, friends, music'),
                _SettingRow(
                    emoji: '🔒',
                    bg: const Color(0xFF22c55e).withOpacity(0.15),
                    name: 'Privacy',
                    sub: 'Who can see your activity'),
              ]),
              _SettingsGroup(label: 'Playback', children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
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
                _SettingRow(
                    emoji: '📶',
                    bg: AppColors.cyan.withOpacity(0.15),
                    name: 'Streaming Quality',
                    sub: '320 kbps · High',
                    trailing: Row(children: [
                      Text('High',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.text3)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.text3, size: 16),
                    ])),
                _SettingRow(
                    emoji: '🔀',
                    bg: AppColors.pink.withOpacity(0.15),
                    name: 'Crossfade',
                    sub: 'Between songs',
                    trailing: _Toggle(
                        value: _crossfade,
                        onChanged: (v) => setState(() => _crossfade = v))),
              ]),
              _SettingsGroup(label: 'Discovery', children: [
                _SettingRow(
                    emoji: '📍',
                    bg: AppColors.purple.withOpacity(0.15),
                    name: 'Location for Matching',
                    sub: city.isNotEmpty ? city : 'Not set'),
                _SettingRow(
                    emoji: '☁️',
                    bg: AppColors.blue.withOpacity(0.15),
                    name: 'Weather Integration'),
                _SettingRow(
                    emoji: '👁',
                    bg: const Color(0xFF22c55e).withOpacity(0.15),
                    name: 'Show My Activity',
                    sub: 'Friends can see what you play',
                    trailing: _Toggle(
                        value: _activity,
                        onChanged: (v) async {
                          setState(() => _activity = v);
                          try {
                            await ApiService()
                                .updateMe({'show_activity': v});
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
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 17)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3), blurRadius: 4)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
