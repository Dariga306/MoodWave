/// Non-web stub — Spotify Web Playback SDK is only available in browsers.
class SpotifyPlayerService {
  static bool get sdkLoaded => false;
  static bool get isReady => false;

  static Future<void> init(String token) async {}
  static Future<bool> playByQuery(String query, String token) async => false;
  static Future<bool> playUri(String uri, String token) async => false;
  static void pause() {}
  static void resume() {}
  static void seek(int positionMs) {}
  static void setVolume(double vol) {}
  static Map<String, dynamic>? getState() => null;
  static void openUrl(String url) {}
  static bool wasJustConnected() => false;
  static void nextTrack() {}
  static void previousTrack() {}
}
