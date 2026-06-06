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
  // Social
  bool _newFollower = true;
  bool _friendRequest = true;
  bool _friendAccepted = true;

  // Discovery
  bool _matchFound = true;
  bool _likeBack = true;

  // Music
  bool _newRelease = true;
  bool _artistActivity = false;
  bool _playlistSaved = true;
  bool _playlistCollaboration = true;

  // Rooms
  bool _roomInvite = true;
  bool _roomStarted = false;

  // Product
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
        _friendAccepted = data['friend_accepted'] as bool? ?? true;
        _matchFound = data['match_found'] as bool? ?? true;
        _likeBack = data['like_back'] as bool? ?? true;
        _newRelease = data['new_release'] as bool? ?? true;
        _artistActivity = data['artist_activity'] as bool? ?? false;
        _playlistSaved = data['playlist_saved'] as bool? ?? true;
        _playlistCollaboration =
            data['playlist_collaboration'] as bool? ?? true;
        _roomInvite = data['room_invite'] as bool? ?? true;
        _roomStarted = data['room_started'] as bool? ?? false;
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
        title: Text('Notification Settings',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.purpleLight))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // ── Social ──────────────────────────────────────
                _SectionLabel('Social'),
                _NotifTile(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: const Color(0xFF7C3AED),
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
                  icon: Icons.handshake_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Friend Requests',
                  subtitle: 'When someone sends a friend request',
                  value: _friendRequest,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _friendRequest = v);
                    _save('friend_request', v);
                  },
                ),
                _NotifTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Friend Accepted',
                  subtitle: 'When someone accepts your friend request',
                  value: _friendAccepted,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _friendAccepted = v);
                    _save('friend_accepted', v);
                  },
                ),
                const SizedBox(height: 20),

                // ── Discovery ────────────────────────────────────
                _SectionLabel('Discovery'),
                _NotifTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFDB2777),
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
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Likes & Like Back',
                  subtitle: 'When someone likes your music taste',
                  value: _likeBack,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _likeBack = v);
                    _save('like_back', v);
                  },
                ),
                const SizedBox(height: 20),

                // ── Music ────────────────────────────────────────
                _SectionLabel('Music'),
                _NotifTile(
                  icon: Icons.album_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'New Releases',
                  subtitle: 'New albums from artists you follow',
                  value: _newRelease,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _newRelease = v);
                    _save('new_release', v);
                  },
                ),
                _NotifTile(
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Artist Activity',
                  subtitle: 'Updates from artists you follow',
                  value: _artistActivity,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _artistActivity = v);
                    _save('artist_activity', v);
                  },
                ),
                _NotifTile(
                  icon: Icons.playlist_add_check_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Playlist Saves',
                  subtitle: 'When someone saves your playlist',
                  value: _playlistSaved,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _playlistSaved = v);
                    _save('playlist_saved', v);
                  },
                ),
                _NotifTile(
                  icon: Icons.queue_music_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Playlist Collaboration',
                  subtitle: 'Invites and updates in collaborative playlists',
                  value: _playlistCollaboration,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _playlistCollaboration = v);
                    _save('playlist_collaboration', v);
                  },
                ),
                const SizedBox(height: 20),

                // ── Rooms ────────────────────────────────────────
                _SectionLabel('Rooms'),
                _NotifTile(
                  icon: Icons.headphones_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  title: 'Room Invites',
                  subtitle: 'When a friend invites you to a Live Room',
                  value: _roomInvite,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _roomInvite = v);
                    _save('room_invite', v);
                  },
                ),
                _NotifTile(
                  icon: Icons.sensors_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Room Started',
                  subtitle: 'When a friend opens a listening room',
                  value: _roomStarted,
                  saving: _saving,
                  onChanged: (v) {
                    setState(() => _roomStarted = v);
                    _save('room_started', v);
                  },
                ),
                const SizedBox(height: 20),

                // ── Product ──────────────────────────────────────
                _SectionLabel('Product'),
                _NotifTile(
                  icon: Icons.campaign_outlined,
                  iconColor: AppColors.text3,
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
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value, saving;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.iconColor,
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
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            Text(subtitle,
                style:
                    GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
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
