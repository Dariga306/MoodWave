import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/app_navigator.dart';
import 'widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase not configured — phone auth will be unavailable
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF08080f),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const MoodWaveApp(),
    ),
  );
}

class MoodWaveApp extends StatelessWidget {
  const MoodWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'MoodWave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFa855f7),
          surface: const Color(0xFF1a1a2e),
          background: const Color(0xFF08080f),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF08080f),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      home: const SplashScreen(),
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const _PersistentPlaybackHost(),
          const GlobalBottomNavOverlay(),
          const GlobalMiniPlayerOverlay(),
        ],
      ),
    );
  }
}

class _PersistentPlaybackHost extends StatelessWidget {
  const _PersistentPlaybackHost();

  @override
  Widget build(BuildContext context) {
    final controller =
        context.select<PlayerProvider, yt.YoutubePlayerController?>(
      (player) => player.youtubeController,
    );

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: -500,
      top: -500,
      width: 320,
      height: 180,
      child: IgnorePointer(
        ignoring: true,
        child: yt.YoutubePlayer(controller: controller),
      ),
    );
  }
}
