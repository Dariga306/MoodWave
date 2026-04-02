import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android && kDebugMode) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

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

  Future<String?> getToken() => _storage.read(key: 'access_token');
  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }
  Future<void> clearTokens() async {
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

  Future<Map<String, dynamic>> loginWithFirebasePhone(String firebaseToken) async {
    final resp = await _dio.post('/auth/firebase-phone', data: {'firebase_token': firebaseToken});
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
  Future<List<dynamic>> searchTracks(String q, {int limit = 20}) async {
    final resp = await _dio.get('/tracks/search', queryParameters: {'q': q, 'limit': limit});
    return resp.data as List;
  }

  Future<List<dynamic>> getRecommendations({String? mood, String? weather}) async {
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
  Future<Map<String, dynamic>> globalSearch(String q, {String type = 'all'}) async {
    final resp = await _dio.get('/search', queryParameters: {'q': q, 'type': type});
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
    final resp = await _dio.get('/weather/current', queryParameters: {'city': city});
    return resp.data;
  }

  Future<Map<String, dynamic>> getWeatherPlaylist(String city) async {
    final resp = await _dio.get('/weather/playlist', queryParameters: {'city': city});
    return resp.data;
  }

  // Charts
  Future<List<dynamic>> getChartsByCity(String city) async {
    final resp = await _dio.get('/charts/city', queryParameters: {'city': city});
    return resp.data as List;
  }

  // Playlists
  Future<List<dynamic>> getPlaylists() async {
    final resp = await _dio.get('/playlists/');
    return resp.data['playlists'] ?? [];
  }

  Future<Map<String, dynamic>> createPlaylist(String title, {String visibility = 'private'}) async {
    final resp = await _dio.post('/playlists/', data: {'title': title, 'visibility': visibility});
    return resp.data;
  }

  Future<Map<String, dynamic>> getPlaylist(int id) async {
    final resp = await _dio.get('/playlists/$id');
    return resp.data;
  }

  Future<void> addTrackToPlaylist(int playlistId, Map<String, dynamic> track) async {
    await _dio.post('/playlists/$playlistId/tracks', data: track);
  }

  // Match
  Future<List<dynamic>> getMatchCandidates() async {
    final resp = await _dio.get('/matches/candidates');
    return resp.data['candidates'] ?? [];
  }

  Future<Map<String, dynamic>> decideMatch(int userId, String decision) async {
    final resp = await _dio.post('/matches/decide/$userId', data: {'decision': decision});
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
    final resp = await _dio.get('/chats/$matchId/messages',
        queryParameters: {'limit': limit});
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

  Future<void> resendVerification(String email) async {
    await _dio.post('/auth/resend-verification', data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<String> verifyResetCode(String email, String code) async {
    final resp = await _dio.post('/auth/verify-reset-code',
        data: {'email': email, 'code': code});
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

  // Notifications
  Future<Map<String, dynamic>> getNotifications() async {
    final resp = await _dio.get('/notifications');
    return resp.data as Map<String, dynamic>;
  }

  // Debug (dev only)
  Future<Map<String, dynamic>> seedDemoMatch() async {
    final resp = await _dio.post('/debug/seed-demo-match');
    return resp.data as Map<String, dynamic>;
  }
}
