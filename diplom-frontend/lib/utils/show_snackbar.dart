import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Beautiful glassmorphism snackbars ───────────────────────────────────────

void showErrorSnackBar(BuildContext context, String message) =>
    _show(context, message: message, type: _SnackType.error);

void showSuccessSnackBar(BuildContext context, String message) =>
    _show(context, message: message, type: _SnackType.success);

void showInfoSnackBar(BuildContext context, String message) =>
    _show(context, message: message, type: _SnackType.info);

// ─── Internal ────────────────────────────────────────────────────────────────

enum _SnackType { error, success, info }

void _show(BuildContext context, {required String message, required _SnackType type}) {
  IconData icon;
  Color accent;
  Color bg;
  switch (type) {
    case _SnackType.error:
      icon = Icons.error_outline_rounded;
      accent = const Color(0xFFf87171);
      bg = const Color(0xFF2a0a0a);
    case _SnackType.success:
      icon = Icons.check_circle_outline_rounded;
      accent = const Color(0xFF4ade80);
      bg = const Color(0xFF0a2a14);
    case _SnackType.info:
      icon = Icons.info_outline_rounded;
      accent = const Color(0xFFa78bfa);
      bg = const Color(0xFF12082a);
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: accent.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.92),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
}
