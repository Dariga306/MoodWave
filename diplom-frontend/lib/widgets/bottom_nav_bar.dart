import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF08080F).withOpacity(0.92),
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', active: currentIndex == 0, onTap: () => onTap(0)),
                _NavItem(icon: Icons.search_rounded, label: 'Search', active: currentIndex == 1, onTap: () => onTap(1)),
                _NavItem(icon: Icons.favorite_rounded, label: 'Match', active: currentIndex == 2, onTap: () => onTap(2)),
                _NavItem(icon: Icons.people_rounded, label: 'Friends', active: currentIndex == 3, onTap: () => onTap(3)),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', active: currentIndex == 4, onTap: () => onTap(4)),
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

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? AppColors.purpleLight : AppColors.text3),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: active ? AppColors.purpleLight : AppColors.text3,
                    letterSpacing: 0.04)),
            if (active) ...[
              const SizedBox(height: 2),
              Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.purple,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
