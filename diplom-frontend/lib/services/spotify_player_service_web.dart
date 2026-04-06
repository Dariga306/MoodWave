// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// Wraps the `window.spotifyBridge` JS object created in index.html.
class SpotifyPlayerService {
  static js.JsObject? get _bridge {
    final b = js.context['spotifyBridge'];
    return b as js.JsObject?;
  }

  static bool get sdkLoaded =>
      js.context['spotifySDKLoaded'] == true;

  static bool get isReady {
    final b = _bridge;
    if (b == null) return false;
    return js_util.getProperty<bool>(b, 'ready') == true;
  }

  /// Initialise the Spotify Web Playback SDK with an access token.
  /// Waits up to 8 s for the player device to become ready.
  static Future<void> init(String token) async {
    final b = _bridge;
    if (b == null) return;
    b.callMethod('init', [token]);
    for (int i = 0; i < 16; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (isReady) return;
    }
  }

  /// Search Spotify by title+artist query and start playback.
  static Future<bool> playByQuery(String query, String token) async {
    final b = _bridge;
    if (b == null || !isReady) return false;
    final promise = b.callMethod('playByQuery', [query, token]);
    try {
      return await js_util.promiseToFuture<bool>(promise);
    } catch (_) {
      return false;
    }
  }

  /// Play a track by its Spotify URI (e.g. `spotify:track:...`).
  static Future<bool> playUri(String uri, String token) async {
    final b = _bridge;
    if (b == null || !isReady) return false;
    final promise = b.callMethod('playUri', [uri, token]);
    try {
      return await js_util.promiseToFuture<bool>(promise);
    } catch (_) {
      return false;
    }
  }

  static void pause() => _bridge?.callMethod('pause', []);
  static void resume() => _bridge?.callMethod('resume', []);
  static void seek(int positionMs) => _bridge?.callMethod('seek', [positionMs]);
  static void setVolume(double vol) => _bridge?.callMethod('setVolume', [vol]);

  /// Open a URL in a new browser tab (used for Spotify OAuth).
  static void openUrl(String url) {
    js.context.callMethod('open', [url, '_blank']);
  }

  /// Returns true if the app was just redirected back from Spotify OAuth.
  /// Clears the ?spotify=connected query param from the URL on first call.
  static bool wasJustConnected() {
    try {
      final href = js.context['location']['href'] as String;
      final uri = Uri.parse(href);
      if (uri.queryParameters['spotify'] == 'connected') {
        js.context['history'].callMethod('replaceState', [null, '', '/']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static void nextTrack() => _bridge?.callMethod('nextTrack', []);
  static void previousTrack() => _bridge?.callMethod('previousTrack', []);

  /// Returns `{paused, position, duration}` or null if no state yet.
  static Map<String, dynamic>? getState() {
    final b = _bridge;
    if (b == null) return null;
    final state = b.callMethod('getState', []);
    if (state == null) return null;
    try {
      return {
        'paused': js_util.getProperty<bool>(state as Object, 'paused') ?? true,
        'position': (js_util.getProperty<num>(state, 'position') ?? 0).toInt(),
        'duration': (js_util.getProperty<num>(state, 'duration') ?? 0).toInt(),
      };
    } catch (_) {
      return null;
    }
  }
}
