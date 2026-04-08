import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'web_token_store_stub.dart'
    if (dart.library.html) 'web_token_store_web.dart';

class ApiService {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      const localApi = 'http://127.0.0.1:8000';
      final isLoopback = host.isEmpty ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '0.0.0.0' ||
          host == '::1' ||
          host == '[::1]';
      if (isLoopback) {
        return localApi;
      }

      final isPrivateLan = RegExp(
        r'^(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)$',
      ).hasMatch(host);
      if (isPrivateLan) {
        return 'http://$host:8000';
      }

      return localApi;
    }
    if (defaultTargetPlatform == TargetPlatform.android && kDebugMode) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  String? _cachedToken; // in-memory cache to avoid web storage race conditions

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiService.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    if (kIsWeb) {
      final webToken = await readWebToken('access_token');
      if (webToken != null && webToken.isNotEmpty) {
        _cachedToken = webToken;
        return webToken;
      }
    }
    final stored = await _storage.read(key: 'access_token');
    _cachedToken = stored;
    return stored;
  }

  Future<void> saveTokens(String access, String refresh) async {
    _cachedToken = access;
    if (kIsWeb) {
      await writeWebToken('access_token', access);
      await writeWebToken('refresh_token', refresh);
    }
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    _cachedToken = null;
    if (kIsWeb) {
      await deleteWebToken('access_token');
      await deleteWebToken('refresh_token');
    }
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    final resp = await _dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
      if (displayName != null) 'display_name': displayName,
    });
    await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final resp = await _dio.post('/auth/google', data: {'id_token': idToken});
    await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get('/users/me');
    return resp.data;
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    await _dio.put('/users/me', data: data);
  }

  Future<void> saveGenres(List<Map<String, dynamic>> genres) async {
    await _dio.post('/users/me/genres', data: {'genres': genres});
  }

  Future<void> saveMoods(List<Map<String, dynamic>> moods) async {
    await _dio.post('/users/me/moods', data: {'moods': moods});
  }

  // Music
  Future<String?> getYouTubeId({
    required String trackId,
    required String title,
    required String artist,
  }) async {
    try {
      final resp = await _dio.get(
        '/tracks/$trackId/youtube',
        queryParameters: {'title': title, 'artist': artist},
      );
      return resp.data['video_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> searchTracks(String q, {int limit = 20}) async {
    final resp = await _dio
        .get('/tracks/search', queryParameters: {'q': q, 'limit': limit});
    return resp.data as List;
  }

  Future<Map<String, dynamic>> searchArtist(String q) async {
    final resp = await _dio.get('/artists/search', queryParameters: {'q': q});
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getArtistProfile(String artistId) async {
    final resp = await _dio.get('/artists/$artistId/profile');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getAlbumDetail(int albumId) async {
    final resp = await _dio.get('/albums/$albumId');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<List<dynamic>> getRecentlyPlayed({int limit = 10}) async {
    try {
      final resp = await _dio.get('/tracks/me/recent', queryParameters: {'limit': limit});
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getRecommendations(
      {String? mood, String? weather}) async {
    final resp = await _dio.get('/tracks/recommendations', queryParameters: {
      if (mood != null) 'mood': mood,
      if (weather != null) 'weather': weather,
    });
    return resp.data as List;
  }

  Future<void> playTrack(String spotifyId) async {
    await _dio.post('/tracks/$spotifyId/play');
  }

  Future<void> likeTrack(String spotifyId) async {
    await _dio.post('/tracks/$spotifyId/like');
  }

  Future<void> skipTrack(String spotifyId) async {
    await _dio.post('/tracks/$spotifyId/skip');
  }

  // Search
  Future<Map<String, dynamic>> globalSearch(String q,
      {String type = 'all'}) async {
    final resp =
        await _dio.get('/search', queryParameters: {'q': q, 'type': type});
    return resp.data;
  }

  Future<List<dynamic>> getTrending() async {
    final resp = await _dio.get('/search/trending');
    return resp.data as List? ?? [];
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final resp = await _dio.get('/users/me/stats');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTasteVector() async {
    final resp = await _dio.get('/taste-vector/me');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFriendsActivity() async {
    final resp = await _dio.get('/friends/activity');
    return resp.data as Map<String, dynamic>;
  }

  // Weather
  Future<Map<String, dynamic>> getWeather(String city) async {
    final resp =
        await _dio.get('/weather/current', queryParameters: {'city': city});
    return resp.data;
  }

  Future<Map<String, dynamic>> getWeatherPlaylist(String city) async {
    final resp =
        await _dio.get('/weather/playlist', queryParameters: {'city': city});
    return resp.data;
  }

  Future<List<String>> searchCities(String q) async {
    final resp = await _dio.get(
      '/weather/cities/search',
      queryParameters: {'q': q},
    );
    final raw = (resp.data as Map<String, dynamic>)['cities'] as List? ?? [];
    return raw.map((item) => item.toString()).toList();
  }

  // Charts
  Future<List<dynamic>> getChartsByCity(String city) async {
    final resp =
        await _dio.get('/charts/city', queryParameters: {'city': city});
    return resp.data as List;
  }

  // Playlists
  Future<List<dynamic>> getPlaylists() async {
    final resp = await _dio.get('/playlists/');
    return resp.data['playlists'] ?? [];
  }

  Future<Map<String, dynamic>> createPlaylist(String title,
      {String visibility = 'private'}) async {
    final resp = await _dio
        .post('/playlists/', data: {'title': title, 'visibility': visibility});
    return resp.data;
  }

  Future<Map<String, dynamic>> getPlaylist(int id) async {
    final resp = await _dio.get('/playlists/$id');
    return resp.data;
  }

  Future<void> addTrackToPlaylist(
      int playlistId, Map<String, dynamic> track) async {
    await _dio.post('/playlists/$playlistId/tracks', data: track);
  }

  // Match
  Future<List<dynamic>> getMatchCandidates() async {
    final resp = await _dio.get('/matches/candidates');
    return resp.data['candidates'] ?? [];
  }

  Future<Map<String, dynamic>> decideMatch(int userId, String decision) async {
    final resp = await _dio
        .post('/matches/decide/$userId', data: {'decision': decision});
    return resp.data;
  }

  Future<List<dynamic>> getMyMatches() async {
    final resp = await _dio.get('/matches/confirmed');
    return resp.data['matches'] ?? [];
  }

  // Chat
  Future<List<dynamic>> getChats() async {
    final resp = await _dio.get('/chats/');
    final data = resp.data;
    if (data is List) return data;
    return (data as Map<String, dynamic>?)?['chats'] as List? ?? [];
  }

  Future<List<dynamic>> getChatMessages(int matchId, {int limit = 50}) async {
    final resp = await _dio
        .get('/chats/$matchId/messages', queryParameters: {'limit': limit});
    return resp.data['messages'] ?? [];
  }

  Future<void> sendTextMessage(int matchId, String text) async {
    await _dio.post('/chats/$matchId/send-text', data: {'text': text});
  }

  // Auth — password management
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> verifyEmail(String email, String code) async {
    await _dio.post('/auth/verify-email', data: {'email': email, 'code': code});
  }

  Future<String?> resendVerification(String email) async {
    final resp =
        await _dio.post('/auth/resend-verification', data: {'email': email});
    return resp.data['dev_code'] as String?;
  }

  Future<String?> forgotPassword(String email) async {
    final resp =
        await _dio.post('/auth/forgot-password', data: {'email': email});
    return resp.data['dev_code'] as String?;
  }

  Future<String> verifyResetCode(String email, String code) async {
    final resp = await _dio
        .post('/auth/verify-reset-code', data: {'email': email, 'code': code});
    return resp.data['reset_token'] as String;
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    await _dio.post('/auth/reset-password', data: {
      'reset_token': resetToken,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> deactivateAccount() async {
    final resp = await _dio.post('/users/me/deactivate');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/users/me');
    await clearTokens();
  }

  // Social
  Future<List<dynamic>> getFriends() async {
    final resp = await _dio.get('/friends');
    return resp.data['friends'] ?? [];
  }

  Future<void> acceptFriendRequest(int userId) async {
    await _dio.post('/friends/$userId/accept');
  }

  Future<void> declineFriendRequest(int userId) async {
    await _dio.delete('/friends/$userId');
  }

  Future<void> sendFriendRequest(int userId) async {
    await _dio.post('/friends/$userId/request');
  }

  Future<void> followArtist(String artistId) async {
    await _dio.post('/users/me/following/$artistId');
  }

  Future<void> unfollowArtist(String artistId) async {
    await _dio.delete('/users/me/following/$artistId');
  }

  Future<List> getFollowedArtists() async {
    final resp = await _dio.get('/users/me/following');
    return resp.data as List? ?? [];
  }

  // Notifications
  Future<Map<String, dynamic>> getNotifications() async {
    final resp = await _dio.get('/notifications');
    return resp.data as Map<String, dynamic>;
  }

  // Spotify
  Future<String?> getSpotifyAuthUrl() async {
    try {
      final resp = await _dio.get('/auth/spotify');
      return resp.data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSpotifyToken() async {
    try {
      final resp = await _dio.get('/spotify/token');
      return resp.data['access_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnectSpotify() async {
    await _dio.delete('/spotify/disconnect');
  }

  // Debug (dev only)
  Future<Map<String, dynamic>> seedDemoMatch() async {
    final resp = await _dio.post('/debug/seed-demo-match');
    return resp.data as Map<String, dynamic>;
  }
}
