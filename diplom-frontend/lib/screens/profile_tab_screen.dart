import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'main/profile_tab.dart';

/// Wraps ProfileTab as a standalone pushable route (used from Library avatar)
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080f),
      bottomNavigationBar: const PersistentBottomNavBar(),
      body: Stack(
        children: [
          const ProfileTab(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
