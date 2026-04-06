import 'package:flutter/material.dart';
import 'main/profile_tab.dart';

/// Wraps ProfileTab as a standalone pushable route (used from Library avatar)
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ProfileTab(),
    );
  }
}
