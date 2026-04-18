import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isPublic = true;
  bool _showActivity = true;
  bool _showFollowers = true;
  bool _showRecentlyPlayed = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getPrivacySettings();
      if (!mounted) return;
      setState(() {
        _isPublic = data['is_public'] as bool? ?? true;
        _showActivity = data['show_activity'] as bool? ?? true;
        _showFollowers = data['show_followers'] as bool? ?? true;
        _showRecentlyPlayed = data['show_recently_played'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save(String key, bool value) async {
    setState(() => _saving = true);
    try {
      await ApiService().updatePrivacySettings({key: value});
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Failed to save setting');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.text, size: 20),
        ),
        title: Text('Privacy',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.purpleLight))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionLabel('Profile Visibility'),
                _PrivacyTile(
                  emoji: '🌍',
                  title: 'Public Profile',
                  subtitle: 'Anyone can find and view your profile',
                  value: _isPublic,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _isPublic = v);
                    _save('is_public', v);
                  },
                ),
                const SizedBox(height: 20),
                _SectionLabel('Activity'),
                _PrivacyTile(
                  emoji: '🎵',
                  title: 'Show Listening Activity',
                  subtitle: 'Friends can see what you\'re playing now',
                  value: _showActivity,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _showActivity = v);
                    _save('show_activity', v);
                  },
                ),
                _PrivacyTile(
                  emoji: '🕐',
                  title: 'Show Recently Played',
                  subtitle: 'Others can see your listening history',
                  value: _showRecentlyPlayed,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _showRecentlyPlayed = v);
                    _save('show_recently_played', v);
                  },
                ),
                const SizedBox(height: 20),
                _SectionLabel('Social'),
                _PrivacyTile(
                  emoji: '👥',
                  title: 'Show Followers',
                  subtitle: 'Others can see your follower count',
                  value: _showFollowers,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _showFollowers = v);
                    _save('show_followers', v);
                  },
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text3,
              letterSpacing: 0.8)),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool value, saving;
  final ValueChanged<bool> onChanged;
  const _PrivacyTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface3,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            Text(subtitle,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
          ]),
        ),
        saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.purpleLight))
            : Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.purpleLight,
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.purple.withOpacity(0.3)
                        : AppColors.surface3),
              ),
      ]),
    );
  }
}
