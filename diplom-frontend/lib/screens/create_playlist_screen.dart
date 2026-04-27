import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

class CreatePlaylistScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPlaylist;
  const CreatePlaylistScreen({super.key, this.existingPlaylist});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  String _visibility = 'private';
  Uint8List? _coverBytes;
  bool _saving = false;

  bool get _isEditing => widget.existingPlaylist != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlaylist;
    _titleCtrl = TextEditingController(text: p?['title'] ?? '');
    _descCtrl = TextEditingController(text: p?['description'] ?? '');
    _visibility = (p?['visibility'] ?? 'private').toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _coverBytes = bytes);
    } catch (_) {}
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 14),
          Text('Choose cover', style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.purpleLight)),
            title: Text('From gallery', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.blue)),
            title: Text('Camera', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          if (_coverBytes != null)
            ListTile(
              leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent)),
              title: Text('Remove cover', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)),
              onTap: () { Navigator.pop(ctx); setState(() => _coverBytes = null); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a playlist name', style: GoogleFonts.outfit())),
      );
      return;
    }
    setState(() => _saving = true);

    String? coverUrl;
    if (_coverBytes != null) {
      final b64 = base64Encode(_coverBytes!);
      coverUrl = 'data:image/jpeg;base64,$b64';
    } else if (_isEditing) {
      coverUrl = widget.existingPlaylist!['cover_url'] as String?;
    }

    try {
      if (_isEditing) {
        await ApiService().updatePlaylist(
          widget.existingPlaylist!['id'] as int,
          title: title,
          description: _descCtrl.text.trim(),
          visibility: _visibility,
          coverUrl: coverUrl,
        );
      } else {
        await ApiService().createPlaylist(
          title,
          visibility: _visibility,
          description: _descCtrl.text.trim(),
          coverUrl: coverUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.outfit())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete playlist',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.text)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.outfit(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.text3))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService().deletePlaylist(widget.existingPlaylist!['id'] as int);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingCover = widget.existingPlaylist?['cover_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Playlist' : 'New Playlist',
            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cover image picker
          Center(
            child: GestureDetector(
              onTap: _showImageOptions,
              child: Stack(children: [
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _coverBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(_coverBytes!, fit: BoxFit.cover))
                      : existingCover != null && existingCover.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(existingCover, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _CoverPlaceholder()))
                          : _CoverPlaceholder(),
                ),
                Positioned(
                  bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Tap to change cover',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3))),
          const SizedBox(height: 28),

          // Title
          _Label('Name *'),
          const SizedBox(height: 8),
          _Field(controller: _titleCtrl, hint: 'Playlist name'),
          const SizedBox(height: 20),

          // Description
          _Label('Description'),
          const SizedBox(height: 8),
          _Field(controller: _descCtrl, hint: 'Tell us about this playlist', maxLines: 3),
          const SizedBox(height: 20),

          // Visibility
          _Label('Privacy'),
          const SizedBox(height: 12),
          _VisibilitySelector(
            value: _visibility,
            onChanged: (v) => setState(() => _visibility = v),
          ),
          const SizedBox(height: 36),

          // Create / Cancel buttons
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save' : 'Create',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Cancel', style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text2)),
            ),
          ),

          // Delete button (only in edit mode)
          if (_isEditing) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Delete playlist', style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.redAccent)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.white54),
      const SizedBox(height: 8),
      Text('Add cover', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
    ],
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.outfit(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _Field({required this.controller, required this.hint, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.purple)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

class _VisibilitySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _VisibilitySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      _VisOption('public', Icons.public_rounded, 'Public', 'Visible to everyone, appears in search'),
      _VisOption('friends', Icons.people_rounded, 'Friends', 'Only visible to people you follow'),
      _VisOption('private', Icons.lock_rounded, 'Private', 'Only visible to you'),
    ];
    return Column(children: options.map((o) {
      final selected = value == o.value;
      return GestureDetector(
        onTap: () => onChanged(o.value),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.purple.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.purple : AppColors.border),
          ),
          child: Row(children: [
            Icon(o.icon, size: 20, color: selected ? AppColors.purpleLight : AppColors.text3),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.label, style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: selected ? AppColors.text : AppColors.text2)),
              Text(o.desc, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3)),
            ])),
            if (selected)
              const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.purple),
          ]),
        ),
      );
    }).toList());
  }
}

class _VisOption {
  final String value, label, desc;
  final IconData icon;
  const _VisOption(this.value, this.icon, this.label, this.desc);
}
