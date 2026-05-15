import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int socialBadge;

  const BottomNavBar({super.key, required this.currentIndex, required this.onTap, this.socialBadge = 0});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xF208080f),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded,    label: 'Home',    active: currentIndex == 0, onTap: () => onTap(0)),
                _NavItem(icon: Icons.search_rounded,  label: 'Search',  active: currentIndex == 1, onTap: () => onTap(1)),
                _NavItem(icon: Icons.people_rounded,  label: 'Social',  active: currentIndex == 2, onTap: () => onTap(2), badge: socialBadge),
                _NavItem(icon: Icons.library_music_rounded, label: 'Library', active: currentIndex == 3, onTap: () => onTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: active ? AppColors.purpleLight : AppColors.text2),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7c3aed), Color(0xFFec4899)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xEB130025), width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: active ? AppColors.purpleLight : AppColors.text2,
                    letterSpacing: 0.04)),
            if (active) ...[
              const SizedBox(height: 2),
              Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                    color: AppColors.purple, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
