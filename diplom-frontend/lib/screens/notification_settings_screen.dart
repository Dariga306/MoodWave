import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/show_snackbar.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _newFollower = true;
  bool _friendRequest = true;
  bool _matchFound = true;
  bool _roomInvite = true;
  bool _promotions = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _newFollower = data['new_follower'] as bool? ?? true;
        _friendRequest = data['friend_request'] as bool? ?? true;
        _matchFound = data['match_found'] as bool? ?? true;
        _roomInvite = data['room_invite'] as bool? ?? true;
        _promotions = data['promotions'] as bool? ?? false;
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
      await ApiService().updateNotificationSettings({key: value});
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
        title: Text('Notifications',
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
                _SectionLabel('Social'),
                _NotifTile(
                  emoji: '👥',
                  title: 'New Follower',
                  subtitle: 'When someone follows you',
                  value: _newFollower,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _newFollower = v);
                    _save('new_follower', v);
                  },
                ),
                _NotifTile(
                  emoji: '🤝',
                  title: 'Friend Requests',
                  subtitle: 'When someone sends a friend request',
                  value: _friendRequest,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _friendRequest = v);
                    _save('friend_request', v);
                  },
                ),
                const SizedBox(height: 20),
                _SectionLabel('Discovery'),
                _NotifTile(
                  emoji: '✨',
                  title: 'Music Matches',
                  subtitle: 'When a high-similarity match is found',
                  value: _matchFound,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _matchFound = v);
                    _save('match_found', v);
                  },
                ),
                _NotifTile(
                  emoji: '🎧',
                  title: 'Room Invites',
                  subtitle: 'When a friend invites you to a listening room',
                  value: _roomInvite,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _roomInvite = v);
                    _save('room_invite', v);
                  },
                ),
                const SizedBox(height: 20),
                _SectionLabel('Other'),
                _NotifTile(
                  emoji: '📣',
                  title: 'Promotions & News',
                  subtitle: 'Updates about new MoodWave features',
                  value: _promotions,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _promotions = v);
                    _save('promotions', v);
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

class _NotifTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool value, saving;
  final ValueChanged<bool> onChanged;
  const _NotifTile({
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
