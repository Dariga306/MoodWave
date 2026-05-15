import 'package:flutter/material.dart';

import 'favorite_artists_screen.dart';

class MoodSelectScreen extends StatelessWidget {
  final List<String> selectedGenres;

  const MoodSelectScreen({
    super.key,
    this.selectedGenres = const [],
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteArtistsScreen(selectedGenres: selectedGenres);
  }
}
