import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  'Male', 'Female', 'Non-binary', 'Prefer not to say',
];

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({required this.user, super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
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

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(
        text: widget.user['first_name'] ?? widget.user['display_name'] ?? '');
    _lastNameCtrl = TextEditingController(text: widget.user['last_name'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.user['username'] ?? '');
    _cityCtrl = TextEditingController(text: widget.user['city'] ?? '');
    _bioCtrl = TextEditingController(text: widget.user['bio'] ?? '');
    _avatarPreset = widget.user['avatar_preset'] ?? 0;
    _bannerPreset = widget.user['banner_preset'] ?? 0;
    _isPublic = widget.user['is_public'] ?? true;
    _showActivity = widget.user['show_activity'] ?? true;
    _gender = widget.user['gender'];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      showErrorSnackBar(context, 'First name cannot be empty');
      return;
    }
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'display_name': _firstNameCtrl.text.trim(),
        'avatar_preset': _avatarPreset,
        'banner_preset': _bannerPreset,
        'is_public': _isPublic,
        'show_activity': _showActivity,
        if (_gender != null) 'gender': _gender,
      };
      await ApiService().updateMe(updates);
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(updates);
      showSuccessSnackBar(context, 'Profile updated successfully!');
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, ErrorHelper.parseError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = (_firstNameCtrl.text.isNotEmpty
            ? _firstNameCtrl.text
            : widget.user['display_name'] ?? 'U')[0]
        .toUpperCase();
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
                onTap: () => setState(() {
                  _showBannerPicker = !_showBannerPicker;
                  _showAvatarPicker = false;
                }),
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: bannerColors),
                  ),
                  child: Stack(children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.palette_outlined, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('Banner', style: GoogleFonts.outfit(
                                fontSize: 11, color: Colors.white70)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _saving
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('Save',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, fontWeight: FontWeight.w700,
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
                        onTap: () => setState(() {
                          _showAvatarPicker = !_showAvatarPicker;
                          _showBannerPicker = false;
                        }),
                        child: Stack(children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: avatarColors),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF08080f), width: 3),
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: GoogleFonts.outfit(
                                      fontSize: 30, fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.purple,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF08080f), width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BANNER COLOR', style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.text3, letterSpacing: 0.08)),
                    const SizedBox(height: 8),
                    Row(children: List.generate(_bannerGradients.length, (i) {
                      return GestureDetector(
                        onTap: () => setState(() {
                          _bannerPreset = i;
                          _showBannerPicker = false;
                        }),
                        child: Container(
                          width: 44, height: 28,
                          margin: EdgeInsets.only(right: i < _bannerGradients.length - 1 ? 6 : 0),
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

              const SizedBox(height: 52),

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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AVATAR COLOR', style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.text3, letterSpacing: 0.08)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8,
                      children: List.generate(_avatarGradients.length, (i) {
                        return GestureDetector(
                          onTap: () => setState(() {
                            _avatarPreset = i;
                            _showAvatarPicker = false;
                          }),
                          child: Container(
                            width: 44, height: 44,
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
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
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
                  Text('Tap avatar or banner to change',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.text3)),
                  const SizedBox(height: 20),

                  _buildField('FIRST NAME', _firstNameCtrl, Icons.person_outline_rounded,
                      hint: 'Your first name'),
                  const SizedBox(height: 14),
                  _buildField('LAST NAME', _lastNameCtrl, Icons.person_outline_rounded,
                      hint: 'Your last name (optional)'),
                  const SizedBox(height: 14),
                  _buildField('USERNAME', _usernameCtrl, Icons.alternate_email_rounded,
                      hint: 'username', readOnly: true,
                      subtitle: 'Username cannot be changed'),
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
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.text3, letterSpacing: 0.08)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: readOnly ? AppColors.glass : AppColors.border),
        ),
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.outfit(
              fontSize: 15,
              color: readOnly ? AppColors.text3 : Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: AppColors.text3, fontSize: 15),
            prefixIcon: Icon(icon,
                size: 18,
                color: readOnly ? AppColors.surface3 : AppColors.text3),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.text3, letterSpacing: 0.08)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGenderSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('GENDER',
          style: GoogleFonts.outfit(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.text3, letterSpacing: 0.08)),
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
                  style: GoogleFonts.outfit(color: AppColors.text3, fontSize: 15)),
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(subtitle,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
        ])),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 26,
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
                width: 20, height: 20,
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
        ),
      ]),
    );
  }
}
