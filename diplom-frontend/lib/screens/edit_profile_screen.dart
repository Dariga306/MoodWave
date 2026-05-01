import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helper.dart';
import '../utils/show_snackbar.dart';

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
  String? _gender;
  bool _saving = false;
  bool _showAvatarPicker = false;
  bool _showBannerPicker = false;
  Uint8List? _avatarBytes;
  Uint8List? _bannerBytes;
  String? _savedAvatarUrl;
  String? _savedBannerUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.user['display_name'] ?? widget.user['first_name'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.user['username'] ?? '');
    _cityCtrl = TextEditingController(text: widget.user['city'] ?? '');
    _bioCtrl = TextEditingController(text: widget.user['bio'] ?? '');
    _avatarPreset = widget.user['avatar_preset'] ?? 0;
    _bannerPreset = widget.user['banner_preset'] ?? 0;
    _isPublic = widget.user['is_public'] ?? true;
    _showActivity = widget.user['show_activity'] ?? true;
    _gender = widget.user['gender'];
    _savedAvatarUrl = widget.user['avatar_url'] as String?;
    _savedBannerUrl = widget.user['banner_url'] as String?;
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _showAvatarPicker = false;
    });
  }

  Future<void> _pickBannerImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bannerBytes = bytes;
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
    final avatarUrl = _savedAvatarUrl ?? '';
    final bannerUrl = _savedBannerUrl ?? '';
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

                  // Privacy toggles
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
    ValueChanged<bool> onChanged,
  ) {
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
                  color: Colors.white)),
          Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        GestureDetector(
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
}
