import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/media_url.dart';
import '../utils/show_snackbar.dart';
import 'taste_preferences_screen.dart';

// 12 gradient presets for avatar
const List<List<Color>> _avatarGradients = [
  [Color(0xFF7C3AED), Color(0xFFDB2777)],
  [Color(0xFF2563EB), Color(0xFF7C3AED)],
  [Color(0xFF059669), Color(0xFF2563EB)],
  [Color(0xFFD97706), Color(0xFFDC2626)],
  [Color(0xFF7C3AED), Color(0xFF2563EB)],
  [Color(0xFFDB2777), Color(0xFFEF4444)],
  [Color(0xFF0891B2), Color(0xFF059669)],
  [Color(0xFF6D28D9), Color(0xFF0891B2)],
  [Color(0xFF374151), Color(0xFF6D28D9)],
  [Color(0xFFB45309), Color(0xFF065F46)],
  [Color(0xFF9D174D), Color(0xFF6D28D9)],
  [Color(0xFF1E40AF), Color(0xFF065F46)],
];

// 6 banner presets
const List<List<Color>> _bannerGradients = [
  [Color(0xFF150825), Color(0xFF3d1a6e)],
  [Color(0xFF1a1a3e), Color(0xFF7C3AED)],
  [Color(0xFF0d1a3d), Color(0xFF2563EB)],
  [Color(0xFF0d2618), Color(0xFF059669)],
  [Color(0xFF3d1a1a), Color(0xFFDC2626)],
  [Color(0xFF08080f), Color(0xFF374151)],
];

const List<String> _genderOptions = [
  'Male',
  'Female',
  'Non-binary',
  'Prefer not to say',
];

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({required this.user, super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _bioCtrl;
  late int _avatarPreset;
  late int _bannerPreset;
  late bool _isPublic;
  late bool _showActivity;
  late bool _showFollowers;
  late bool _hideMusicTaste;
  late bool _matchingEnabled;
  late bool _showMatchCity;
  late bool _hideForwardProfile;
  String? _gender;
  bool _saving = false;
  bool _showAvatarPicker = false;
  bool _showBannerPicker = false;
  Uint8List? _avatarBytes;
  Uint8List? _bannerBytes;
  String? _savedAvatarUrl;
  String? _savedBannerUrl;
  int _previewVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    MiniPlayerOverlayController.suppress();
    GlobalBottomNavController.hide();
    _nameCtrl = TextEditingController(
        text: widget.user['display_name'] ?? widget.user['first_name'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.user['username'] ?? '');
    _cityCtrl = TextEditingController(text: widget.user['city'] ?? '');
    _bioCtrl = TextEditingController(text: widget.user['bio'] ?? '');
    _avatarPreset = widget.user['avatar_preset'] ?? 0;
    _bannerPreset = widget.user['banner_preset'] ?? 0;
    _isPublic = widget.user['is_public'] ?? true;
    _showActivity = widget.user['show_activity'] ?? true;
    _showFollowers = widget.user['show_followers'] ?? true;
    _hideMusicTaste = widget.user['hide_music_taste'] ?? false;
    _matchingEnabled = widget.user['matching_enabled'] ?? true;
    _showMatchCity = widget.user['show_match_city'] ?? true;
    _hideForwardProfile = widget.user['hide_forward_profile'] ?? false;
    _gender = widget.user['gender'];
    _savedAvatarUrl = widget.user['avatar_url'] as String?;
    _savedBannerUrl = widget.user['banner_url'] as String?;
  }

  Future<void> _openMusicTaste() async {
    final auth = context.read<AuthProvider>();
    final authUser = auth.user;
    final userId = (authUser?['id'] ?? widget.user['id']) as int?;
    var initialGenres = (((authUser?['genres'] as List?) ??
            (widget.user['genres'] as List?) ??
            const [])
        .map((item) => item.toString())
        .toList());
    var initialArtists = <Map<String, dynamic>>[];

    if (userId != null) {
      try {
        final summary = await ApiService().getUserProfileSummary(
          userId,
          playlistLimit: 1,
          tracksLimit: 1,
        );
        initialArtists = ((summary['favorite_artists'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final summaryGenres =
            (((summary['user'] as Map?)?['genres'] as List?) ?? const [])
                .map((item) => item.toString())
                .toList();
        if (summaryGenres.isNotEmpty) {
          initialGenres = summaryGenres;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TastePreferencesScreen(
          initialGenres: initialGenres,
          initialArtists: initialArtists,
        ),
      ),
    );
    if (!mounted || updated != true) return;
    await auth.reload();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageCropScreen(
          imageBytes: bytes,
          title: 'Adjust avatar',
          aspectRatio: 1,
          outputWidth: 512,
        ),
      ),
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _avatarBytes = cropped;
      _showAvatarPicker = false;
    });
  }

  Future<void> _pickBannerImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageCropScreen(
          imageBytes: bytes,
          title: 'Adjust banner',
          aspectRatio: 2.22,
          outputWidth: 1280,
        ),
      ),
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _bannerBytes = cropped;
      _showBannerPicker = false;
    });
  }

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 14),
            Text('Change Avatar',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded,
                      size: 18, color: AppColors.purpleLight)),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              subtitle: Text('Use your own photo',
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatarImage();
              },
            ),
            ListTile(
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.palette_rounded,
                      size: 18, color: AppColors.blue)),
              title: Text('Choose Color Preset',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              subtitle: Text('Pick a gradient color',
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _showAvatarPicker = true;
                  _showBannerPicker = false;
                });
              },
            ),
            if (_avatarBytes != null)
              ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.redAccent)),
                title: Text('Remove Photo',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) setState(() => _avatarBytes = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBannerOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 14),
            Text('Change Banner',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded,
                      size: 18, color: AppColors.purpleLight)),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              subtitle: Text('Use your own photo',
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
              onTap: () {
                Navigator.pop(ctx);
                _pickBannerImage();
              },
            ),
            ListTile(
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.palette_rounded,
                      size: 18, color: AppColors.blue)),
              title: Text('Choose Color Preset',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              subtitle: Text('Pick a gradient color',
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _showBannerPicker = true;
                  _showAvatarPicker = false;
                });
              },
            ),
            if (_bannerBytes != null)
              ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.redAccent)),
                title: Text('Remove Photo',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) setState(() => _bannerBytes = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    MiniPlayerOverlayController.unsuppress();
    GlobalBottomNavController.show();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showErrorSnackBar(context, 'Name cannot be empty');
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final updates = <String, dynamic>{
        'display_name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatar_preset': _avatarPreset,
        'banner_preset': _bannerPreset,
        'is_public': _isPublic,
        'show_activity': _showActivity,
        'show_followers': _showFollowers,
        'hide_music_taste': _hideMusicTaste,
        'matching_enabled': _matchingEnabled,
        'show_match_city': _showMatchCity,
        'hide_forward_profile': _hideForwardProfile,
        if (_gender != null) 'gender': _gender,
      };

      // Clear old cached images before updating if new ones are being uploaded
      if (_avatarBytes != null &&
          _savedAvatarUrl != null &&
          _savedAvatarUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(_savedAvatarUrl!);
      }
      if (_bannerBytes != null &&
          _savedBannerUrl != null &&
          _savedBannerUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(_savedBannerUrl!);
      }

      final updatedUser = await ApiService().updateMe(
        updates,
        avatarBytes: _avatarBytes,
        bannerBytes: _bannerBytes,
      );
      if (!mounted) return;

      final nextAvatarUrl = updatedUser['avatar_url'] as String?;
      final nextBannerUrl = updatedUser['banner_url'] as String?;

      // Clear newly cached images to ensure fresh load
      if (nextAvatarUrl != null && nextAvatarUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(nextAvatarUrl);
      }
      if (nextBannerUrl != null && nextBannerUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(nextBannerUrl);
      }

      auth.updateUser(updatedUser);
      await auth.reload();
      auth.bumpProfileRevision();
      if (!mounted) return;
      setState(() {
        _savedAvatarUrl = nextAvatarUrl;
        _savedBannerUrl = nextBannerUrl;
        _avatarBytes = null;
        _bannerBytes = null;
        _previewVersion = DateTime.now().millisecondsSinceEpoch;
      });
      showSuccessSnackBar(context, 'Profile updated successfully!');
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = ErrorHelper.parseError(e);
      showErrorSnackBar(context, msg);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = (_nameCtrl.text.isNotEmpty
            ? _nameCtrl.text
            : widget.user['display_name'] ?? 'U')[0]
        .toUpperCase();
    final avatarUrl = buildMediaUrl(_savedAvatarUrl, version: _previewVersion);
    final bannerUrl = buildMediaUrl(_savedBannerUrl, version: _previewVersion);
    final bannerColors = _bannerGradients[_bannerPreset];
    final avatarColors = _avatarGradients[_avatarPreset];

    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Banner + avatar area
              GestureDetector(
                onTap: _showBannerOptions,
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: bannerColors),
                  ),
                  child: Stack(clipBehavior: Clip.none, children: [
                    if (_bannerBytes != null)
                      Positioned.fill(
                        child: Image.memory(
                          _bannerBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (bannerUrl.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.palette_outlined,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('Banner',
                                style: GoogleFonts.outfit(
                                    fontSize: 11, color: Colors.white70)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('Save',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                    // Avatar
                    Positioned(
                      bottom: -40,
                      left: 20,
                      child: GestureDetector(
                        onTap: _showAvatarOptions,
                        child: Stack(children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: avatarColors),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF08080f), width: 3),
                            ),
                            child: _avatarBytes != null
                                ? ClipOval(
                                    child: Image.memory(
                                      _avatarBytes!,
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                    ),
                                  )
                                : avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              const SizedBox(),
                                          errorWidget: (_, __, ___) => Center(
                                            child: Text(initial,
                                                style: GoogleFonts.outfit(
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(initial,
                                            style: GoogleFonts.outfit(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white)),
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.purple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF08080f), width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),

              // Banner picker
              if (_showBannerPicker)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BANNER COLOR',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text3,
                                letterSpacing: 0.08)),
                        const SizedBox(height: 8),
                        Row(
                            children:
                                List.generate(_bannerGradients.length, (i) {
                          return GestureDetector(
                            onTap: () => setState(() {
                              _bannerPreset = i;
                              _showBannerPicker = false;
                            }),
                            child: Container(
                              width: 44,
                              height: 28,
                              margin: EdgeInsets.only(
                                  right:
                                      i < _bannerGradients.length - 1 ? 6 : 0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _bannerGradients[i]),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _bannerPreset == i
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2),
                              ),
                            ),
                          );
                        })),
                      ]),
                ),

              const SizedBox(height: 48),

              // Avatar picker
              if (_showAvatarPicker)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AVATAR COLOR',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text3,
                                letterSpacing: 0.08)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_avatarGradients.length, (i) {
                            return GestureDetector(
                              onTap: () => setState(() {
                                _avatarPreset = i;
                                _showAvatarPicker = false;
                              }),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _avatarGradients[i]),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _avatarPreset == i
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2),
                                ),
                                child: _avatarPreset == i
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ]),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(children: [
                  const SizedBox(height: 8),
                  Text('Tap avatar or banner to change · Gallery or preset',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.text3)),
                  const SizedBox(height: 20),

                  _buildField('NAME', _nameCtrl, Icons.person_outline_rounded,
                      hint: 'Your name'),
                  const SizedBox(height: 14),
                  _buildField(
                      'USERNAME', _usernameCtrl, Icons.alternate_email_rounded,
                      hint: 'username',
                      subtitle: 'Can be changed once every 30 days'),
                  const SizedBox(height: 14),
                  _buildField('CITY', _cityCtrl, Icons.location_city_rounded,
                      hint: 'Your city'),
                  const SizedBox(height: 14),

                  // Bio field
                  _buildBioField(),
                  const SizedBox(height: 14),

                  // Gender selector
                  _buildGenderSelector(),
                  const SizedBox(height: 14),

                  _buildActionRow(
                    'Music Taste',
                    'Choose genres and favorite artists',
                    Icons.library_music_rounded,
                    _openMusicTaste,
                  ),
                  const SizedBox(height: 14),

                  // Privacy toggles
                  _buildToggleRow(
                    'Appear in Music Match',
                    'Let other people discover you in Music Match',
                    Icons.auto_awesome_rounded,
                    _matchingEnabled,
                    (v) => setState(() => _matchingEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Public Profile',
                    'Anyone can see your profile',
                    Icons.public_rounded,
                    _isPublic,
                    (v) => setState(() => _isPublic = v),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Show Activity',
                    'Friends see what you\'re listening to',
                    Icons.visibility_rounded,
                    _showActivity,
                    (v) => setState(() => _showActivity = v),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Show Followers',
                    'Others can see your follower count',
                    Icons.people_rounded,
                    _showFollowers,
                    (v) => setState(() => _showFollowers = v),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Show Music Taste',
                    'Display your genres and favorite artists',
                    Icons.music_note_rounded,
                    !_hideMusicTaste,
                    (v) => setState(() => _hideMusicTaste = !v),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Show City in Matching',
                    'Display your city on Music Match cards',
                    Icons.location_on_rounded,
                    _showMatchCity,
                    _matchingEnabled
                        ? (v) => setState(() => _showMatchCity = v)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    'Hide Forward Profile',
                    'Forwarded messages will not link to your profile',
                    Icons.forward_to_inbox_rounded,
                    _hideForwardProfile,
                    (v) => setState(() => _hideForwardProfile = v),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool readOnly = false,
    String? subtitle,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 0.08)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: readOnly ? AppColors.glass : AppColors.border),
        ),
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.outfit(
              fontSize: 15, color: readOnly ? AppColors.text3 : Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: AppColors.text3, fontSize: 15),
            prefixIcon: Icon(icon,
                size: 18,
                color: readOnly ? AppColors.surface3 : AppColors.text3),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 5, left: 4),
          child: Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
        ),
    ]);
  }

  Widget _buildBioField() {
    final len = _bioCtrl.text.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('BIO',
            style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.text3,
                letterSpacing: 0.08)),
        const Spacer(),
        Text('$len/150',
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
      ]),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tell something about yourself...',
            hintStyle: GoogleFonts.outfit(color: AppColors.text3, fontSize: 14),
            border: InputBorder.none,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGenderSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('GENDER',
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 0.08)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _gender,
            hint: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('Select gender (optional)',
                  style:
                      GoogleFonts.outfit(color: AppColors.text3, fontSize: 15)),
            ),
            isExpanded: true,
            dropdownColor: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            icon: const Icon(Icons.expand_more_rounded, color: AppColors.text3),
            style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Prefer not to say',
                    style: GoogleFonts.outfit(color: AppColors.text3)),
              ),
              ..._genderOptions.map((g) => DropdownMenuItem<String?>(
                    value: g,
                    child: Text(g),
                  )),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
        ),
      ),
    ]);
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    final enabled = onChanged != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.text3),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : AppColors.text2)),
          Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        GestureDetector(
          onTap: enabled ? () => onChanged(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 26,
            decoration: BoxDecoration(
              gradient: value
                  ? const LinearGradient(
                      colors: [AppColors.purpleDark, AppColors.purple])
                  : null,
              color: value
                  ? null
                  : (enabled ? AppColors.surface3 : AppColors.glass),
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
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3), blurRadius: 4)
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActionRow(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.purpleLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.text3,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final double aspectRatio;
  final int outputWidth;

  const _ImageCropScreen({
    required this.imageBytes,
    required this.title,
    required this.aspectRatio,
    required this.outputWidth,
  });

  @override
  State<_ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<_ImageCropScreen> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;
  ui.Image? _decodedImage;
  double _scale = 1;
  double _startScale = 1;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.imageBytes, (image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _decodedImage = image);
    });
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Size _coverSize(Size cropSize) {
    final image = _decodedImage;
    if (image == null) return cropSize;
    final imageAspect = image.width / image.height;
    final cropAspect = cropSize.width / cropSize.height;
    if (imageAspect > cropAspect) {
      return Size(cropSize.height * imageAspect, cropSize.height);
    }
    return Size(cropSize.width, cropSize.width / imageAspect);
  }

  Offset _clampOffset(Offset value, Size cropSize, Size baseSize) {
    final scaledWidth = baseSize.width * _scale;
    final scaledHeight = baseSize.height * _scale;
    final maxDx = math.max(0.0, (scaledWidth - cropSize.width) / 2);
    final maxDy = math.max(0.0, (scaledHeight - cropSize.height) / 2);
    return Offset(
      value.dx.clamp(-maxDx, maxDx).toDouble(),
      value.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  void _resetCrop() {
    setState(() {
      _scale = 1;
      _startScale = 1;
      _offset = Offset.zero;
    });
  }

  Future<void> _saveCrop() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final pixelRatio = widget.outputWidth / boundary.size.width;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || data == null) return;
      Navigator.of(context).pop(data.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cropWidth = (screenWidth - 40).clamp(260.0, 360.0).toDouble();
    final cropHeight = cropWidth / widget.aspectRatio;
    final isAvatar = widget.aspectRatio == 1;
    final cropSize = Size(cropWidth, cropHeight);
    final baseSize = _coverSize(cropSize);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.text),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveCrop,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.purpleLight,
                    ),
                  )
                : Text(
                    'Done',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.purpleLight,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: cropWidth + 18,
                    height: cropHeight + 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isAvatar ? 999 : 28),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                  ),
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isAvatar ? cropWidth / 2 : 22),
                      child: SizedBox(
                        width: cropWidth,
                        height: cropHeight,
                        child: GestureDetector(
                          onScaleStart: (_) => _startScale = _scale,
                          onScaleUpdate: (details) {
                            setState(() {
                              _scale =
                                  (_startScale * details.scale).clamp(1.0, 5.0);
                              _offset = _clampOffset(
                                _offset + details.focalPointDelta,
                                cropSize,
                                baseSize,
                              );
                            });
                          },
                          child: ColoredBox(
                            color: Colors.black,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.translate(
                                  offset: _offset,
                                  child: Transform.scale(
                                    scale: _scale,
                                    child: SizedBox(
                                      width: baseSize.width,
                                      height: baseSize.height,
                                      child: Image.memory(
                                        widget.imageBytes,
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Move and zoom the image so the best part sits inside the frame.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _resetCrop,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Reset position',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.text2),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: _saving ? null : _saveCrop,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryBtn,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Use this image',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
