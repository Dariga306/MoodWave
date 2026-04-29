import 'dart:typed_data';

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
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 8),
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

  Map<String, dynamic> _normalizeTrack(Map raw) {
    final track = Map<String, dynamic>.from(raw);
    final resolvedId = track['spotify_id'] ??
        track['deezer_id'] ??
        track['track_id'] ??
        track['trackId'];

    if (resolvedId != null && resolvedId.toString().isNotEmpty) {
      track['spotify_id'] ??= resolvedId.toString();
      track['track_id'] ??= resolvedId.toString();
    }
    if ((track['title'] == null || track['title'].toString().isEmpty) &&
        track['trackName'] != null) {
      track['title'] = track['trackName'].toString();
    }
    if ((track['artist'] == null || track['artist'].toString().isEmpty) &&
        track['artistName'] != null) {
      track['artist'] = track['artistName'].toString();
    }
    if ((track['cover_url'] == null || track['cover_url'].toString().isEmpty) &&
        track['artworkUrl100'] != null) {
      track['cover_url'] = track['artworkUrl100'].toString();
    }
    if ((track['preview_url'] == null ||
            track['preview_url'].toString().isEmpty) &&
        track['previewUrl'] != null) {
      track['preview_url'] = track['previewUrl'].toString();
    }
    return track;
  }

  List<Map<String, dynamic>> _normalizeTrackList(List<dynamic> items) {
    return items.whereType<Map>().map(_normalizeTrack).toList();
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), ' ')
        .trim();
  }

  int _scoreTrackCandidate(
    Map<String, dynamic> track,
    String title,
    String artist, {
    String? trackId,
  }) {
    final normalizedTitle = _normalizeText(title);
    final normalizedArtist = _normalizeText(artist);
    final candidateTitle = _normalizeText(track['title']?.toString() ?? '');
    final candidateArtist = _normalizeText(track['artist']?.toString() ?? '');
    final candidateId =
        (track['spotify_id'] ?? track['track_id'] ?? '').toString();

    var score = 0;
    if (trackId != null && trackId.isNotEmpty && candidateId == trackId) {
      score += 100;
    }
    if (normalizedTitle.isNotEmpty && candidateTitle == normalizedTitle) {
      score += 60;
    } else if (normalizedTitle.isNotEmpty &&
        (candidateTitle.contains(normalizedTitle) ||
            normalizedTitle.contains(candidateTitle))) {
      score += 30;
    }
    if (normalizedArtist.isNotEmpty && candidateArtist == normalizedArtist) {
      score += 40;
    } else if (normalizedArtist.isNotEmpty &&
        (candidateArtist.contains(normalizedArtist) ||
            normalizedArtist.contains(candidateArtist))) {
      score += 20;
    }
    if ((track['preview_url']?.toString().isNotEmpty ?? false)) {
      score += 10;
    }
    if ((track['cover_url']?.toString().isNotEmpty ?? false)) {
      score += 5;
    }
    return score;
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

  Future<Map<String, dynamic>> updateMe(
    Map<String, dynamic> data, {
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
    String avatarFileName = 'avatar.jpg',
    String bannerFileName = 'banner.jpg',
  }) async {
    final hasUploads = avatarBytes != null || bannerBytes != null;
    late final Response resp;

    if (hasUploads) {
      final formMap = <String, dynamic>{...data};
      if (avatarBytes != null) {
        formMap['avatar'] = MultipartFile.fromBytes(
          avatarBytes,
          filename: avatarFileName,
        );
      }
      if (bannerBytes != null) {
        formMap['banner'] = MultipartFile.fromBytes(
          bannerBytes,
          filename: bannerFileName,
        );
      }

      resp = await _dio.put(
        '/users/me',
        data: FormData.fromMap(formMap),
        options: Options(contentType: 'multipart/form-data'),
      );
    } else {
      resp = await _dio.put('/users/me', data: data);
    }

    return Map<String, dynamic>.from(resp.data as Map);
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
        '/tracks/${Uri.encodeComponent(trackId)}/youtube',
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

  Future<List<Map<String, dynamic>>> searchTracksWithFallback(
    String q, {
    int limit = 20,
  }) async {
    try {
      final primary = _normalizeTrackList(await searchTracks(q, limit: limit));
      if (primary.isNotEmpty) {
        return primary;
      }
    } catch (_) {}

    try {
      final fallback = await globalSearch(q, type: 'tracks');
      final tracks =
          _normalizeTrackList((fallback['tracks'] as List?) ?? const []);
      if (tracks.isNotEmpty) {
        return tracks.take(limit).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<Map<String, dynamic>?> resolveTrack({
    required String title,
    required String artist,
    String? trackId,
  }) async {
    final queries = <String>[
      if (artist.trim().isNotEmpty && title.trim().isNotEmpty)
        '${artist.trim()} ${title.trim()}',
      if (title.trim().isNotEmpty) title.trim(),
      if (artist.trim().isNotEmpty) artist.trim(),
    ];
    final seenQueries = <String>{};

    Map<String, dynamic>? bestMatch;
    var bestScore = -1;

    for (final query in queries) {
      if (!seenQueries.add(query.toLowerCase())) {
        continue;
      }
      final candidates = await searchTracksWithFallback(query, limit: 10);
      for (final candidate in candidates) {
        final score = _scoreTrackCandidate(
          candidate,
          title,
          artist,
          trackId: trackId,
        );
        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidate;
        }
      }
      if (bestScore >= 100) {
        break;
      }
    }

    if (bestScore < 100 && artist.trim().isNotEmpty) {
      try {
        final artistResult = await searchArtist(artist.trim());
        final artistData = artistResult['artist'] as Map<String, dynamic>?;
        final artistId = artistData?['id']?.toString();
        if (artistId != null && artistId.isNotEmpty) {
          final profile = await getArtistProfile(artistId);
          final topTracks =
              _normalizeTrackList((profile['top_tracks'] as List?) ?? const []);
          for (final candidate in topTracks) {
            final score = _scoreTrackCandidate(
              candidate,
              title,
              artist,
              trackId: trackId,
            );
            if (score > bestScore) {
              bestScore = score;
              bestMatch = candidate;
            }
          }
        }
      } catch (_) {}
    }

    return bestScore > 0 ? bestMatch : null;
  }

  Future<Map<String, dynamic>> searchArtist(String q) async {
    final resp = await _dio.get('/artists/search', queryParameters: {'q': q});
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<List<Map<String, dynamic>>> searchArtistsList(
    String q, {
    int limit = 10,
  }) async {
    try {
      final resp = await _dio.get(
        '/artists/search/list',
        queryParameters: {'q': q, 'limit': limit},
      );
      return (resp.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchAlbums(
    String q, {
    int limit = 10,
  }) async {
    try {
      final resp = await _dio.get(
        '/albums/search',
        queryParameters: {'q': q, 'limit': limit},
      );
      return (resp.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getArtistProfile(String artistId) async {
    final resp = await _dio.get('/artists/$artistId/profile');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getArtistDiscography(String artistId) async {
    final resp = await _dio.get('/artists/$artistId/discography');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getAlbumDetail(int albumId) async {
    final resp = await _dio.get('/albums/$albumId');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<List<dynamic>> getRecentlyPlayed({int limit = 10}) async {
    try {
      final resp = await _dio
          .get('/tracks/me/recent', queryParameters: {'limit': limit});
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getListeningHistory({int limit = 150}) async {
    try {
      final resp = await _dio
          .get('/tracks/me/history', queryParameters: {'limit': limit});
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

  Future<List<dynamic>> getMoodTracks(String moodKey) async {
    try {
      final resp =
          await _dio.get('/moods/${Uri.encodeComponent(moodKey)}/tracks');
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getLikedTracks({int limit = 100}) async {
    try {
      final resp =
          await _dio.get('/tracks/me/liked', queryParameters: {'limit': limit});
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getOnRepeat({int limit = 20}) async {
    try {
      final resp = await _dio
          .get('/tracks/me/on-repeat', queryParameters: {'limit': limit});
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getFlashbacks({int limit = 20}) async {
    try {
      final resp = await _dio
          .get('/tracks/me/flashbacks', queryParameters: {'limit': limit});
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> playTrack(
    String spotifyId, {
    double completionPct = 0,
    String? mood,
    String? title,
    String? artist,
    String? genre,
    String? coverUrl,
  }) async {
    await _dio.post('/tracks/${Uri.encodeComponent(spotifyId)}/play', data: {
      'completion_pct': completionPct,
      if (mood != null) 'mood': mood,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (genre != null) 'genre': genre,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
  }

  Future<void> likeTrack(
    String spotifyId, {
    String action = 'liked',
    String? title,
    String? artist,
    String? genre,
  }) async {
    await _dio.post('/tracks/${Uri.encodeComponent(spotifyId)}/like', data: {
      'action': action,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (genre != null) 'genre': genre,
    });
  }

  Future<void> unlikeTrack(String spotifyId) async {
    await _dio.post('/tracks/${Uri.encodeComponent(spotifyId)}/like',
        data: {'action': 'disliked'});
  }

  Future<List<Map<String, dynamic>>> getLikedAlbums() async {
    try {
      final resp = await _dio.get('/albums/liked');
      return (resp.data as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> likeAlbum({
    required String albumId,
    required String albumName,
    String artistName = '',
    String? coverUrl,
  }) async {
    final resp = await _dio.post('/albums/$albumId/like', data: {
      'album_id': albumId,
      'album_name': albumName,
      'artist_name': artistName,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
    return resp.data['liked'] as bool? ?? true;
  }

  Future<bool> unlikeAlbum(String albumId) async {
    final resp = await _dio.delete('/albums/$albumId/like');
    return resp.data['liked'] as bool? ?? false;
  }

  Future<bool> getAlbumLikedStatus(String albumId) async {
    try {
      final resp = await _dio.get('/albums/$albumId/liked-status');
      return resp.data['liked'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> skipTrack(
    String spotifyId, {
    int timeListenedMs = 0,
    String? title,
    String? artist,
  }) async {
    await _dio.post('/tracks/${Uri.encodeComponent(spotifyId)}/skip', data: {
      'time_listened_ms': timeListenedMs,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
    });
  }

  // Search
  Future<Map<String, dynamic>> globalSearch(String q,
      {String type = 'all'}) async {
    final resp =
        await _dio.get('/search', queryParameters: {'q': q, 'type': type});
    return resp.data;
  }

  Future<List<Map<String, dynamic>>> searchPlaylists(String q,
      {int limit = 10}) async {
    try {
      final resp = await _dio
          .get('/playlists/search', queryParameters: {'q': q, 'limit': limit});
      final raw = resp.data;
      final list =
          raw is Map ? (raw['playlists'] as List?) ?? [] : raw as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getTrending() async {
    final resp = await _dio.get('/search/trending');
    return resp.data as List? ?? [];
  }

  Future<List<String>> getSearchSuggestions(String q) async {
    try {
      final resp = await _dio
          .get('/search/suggestions', queryParameters: {'q': q, 'limit': 8});
      return (resp.data as List? ?? []).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSearchHistory({int limit = 20}) async {
    try {
      final resp =
          await _dio.get('/search/history', queryParameters: {'limit': limit});
      return (resp.data as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSearchHistory({
    required String query,
    required String resultType,
    String? resultId,
    String? resultTitle,
    String? resultCover,
  }) async {
    await _dio.post('/search/history', data: {
      'query': query,
      'result_type': resultType,
      if (resultId != null) 'result_id': resultId,
      if (resultTitle != null) 'result_title': resultTitle,
      if (resultCover != null) 'result_cover': resultCover,
    });
  }

  Future<void> deleteSearchHistoryItem(int id) async {
    await _dio.delete('/search/history/$id');
  }

  Future<void> clearSearchHistory() async {
    await _dio.delete('/search/history');
  }

  Future<Map<String, dynamic>> getUserStats(
      {String period = 'all_time'}) async {
    final resp =
        await _dio.get('/users/me/stats', queryParameters: {'period': period});
    return resp.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getWeeklyStatsRecaps(
      {int weeks = 6}) async {
    final resp = await _dio.get(
      '/users/me/stats/weekly-recaps',
      queryParameters: {'weeks': weeks},
    );
    final raw =
        (resp.data as Map<String, dynamic>)['weeks'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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

  Future<List<dynamic>> getCharts({String genre = '', int limit = 20}) async {
    try {
      final resp = await _dio.get('/tracks/charts', queryParameters: {
        if (genre.isNotEmpty) 'genre': genre,
        'limit': limit
      });
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  // Playlists
  Future<List<dynamic>> getPlaylists() async {
    final resp = await _dio.get('/playlists/');
    return resp.data['playlists'] ?? [];
  }

  Future<Map<String, dynamic>> createPlaylist(String title,
      {String visibility = 'private',
      String? description,
      String? coverUrl}) async {
    final resp = await _dio.post('/playlists/', data: {
      'title': title,
      'visibility': visibility,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
    });
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

  Future<void> updatePlaylist(int playlistId,
      {String? title,
      String? description,
      String? visibility,
      String? coverUrl}) async {
    await _dio.put('/playlists/$playlistId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (visibility != null) 'visibility': visibility,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _dio.delete('/playlists/$playlistId');
  }

  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async {
    await _dio.delete('/playlists/$playlistId/tracks/$trackId');
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

  Future<List<dynamic>> getFollowedArtistsDetails() async {
    try {
      final resp = await _dio.get('/users/me/following/details');
      return resp.data as List? ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getActiveRooms({int limit = 5}) async {
    try {
      final resp =
          await _dio.get('/rooms/active', queryParameters: {'limit': limit});
      final data = resp.data;
      if (data is Map) return (data['rooms'] as List?) ?? [];
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getRoomDetails(int roomId) async {
    final resp = await _dio.get('/rooms/$roomId');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> sendJoinRequest(int roomId) async {
    await _dio.post('/rooms/$roomId/join-request');
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

  Future<Map<String, dynamic>> getPrivacySettings() async {
    final resp = await _dio.get('/users/me/privacy-settings');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> updatePrivacySettings(
      Map<String, dynamic> data) async {
    final resp = await _dio.put('/users/me/privacy-settings', data: data);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getNotificationSettings() async {
    final resp = await _dio.get('/users/me/notification-settings');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> updateNotificationSettings(
      Map<String, dynamic> data) async {
    final resp = await _dio.put('/users/me/notification-settings', data: data);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> clearUserCache() async {
    await _dio.post('/users/me/cache-clear');
  }

  Future<void> followUser(int userId) async {
    await _dio.post('/users/$userId/follow');
  }

  Future<void> unfollowUser(int userId) async {
    await _dio.delete('/users/$userId/follow');
  }

  Future<List<Map<String, dynamic>>> getUserFollowers(
    int userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '/users/$userId/followers',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (resp.data as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getUserFollowing(
    int userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '/users/$userId/following',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (resp.data as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getGenreMixes({
    int limit = 6,
    int tracksPerMix = 12,
  }) async {
    try {
      final resp = await _dio.get(
        '/tracks/me/genre-mixes',
        queryParameters: {'limit': limit, 'tracks_per_mix': tracksPerMix},
      );
      return (resp.data as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Debug (dev only)
  Future<Map<String, dynamic>> seedDemoMatch() async {
    final resp = await _dio.post('/debug/seed-demo-match');
    return resp.data as Map<String, dynamic>;
  }

  // ─── Home feed ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHomeFeed() async {
    try {
      final resp = await _dio.get('/trending/feed');
      return Map<String, dynamic>.from(resp.data as Map);
    } catch (_) {
      return {};
    }
  }

  // ─── Trending / Hot ───────────────────────────────────────────────────────

  Future<List<dynamic>> getTrendingTracks(
      {String? city, int limit = 20}) async {
    try {
      final resp = await _dio.get(
        '/trending/tracks',
        queryParameters: {
          if (city != null) 'city': city,
          'limit': limit,
        },
      );
      return (resp.data['tracks'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  // ─── Radio ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getRadioStations() async {
    try {
      final resp = await _dio.get('/radio/stations');
      return (resp.data['stations'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getRadioTracks(String stationId) async {
    try {
      final resp = await _dio.get('/radio/$stationId/tracks');
      return (resp.data['tracks'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRadioNext(
      String stationId, String currentTrackId) async {
    try {
      final resp = await _dio.post(
        '/radio/$stationId/next',
        data: {'current_track_id': currentTrackId},
      );
      final t = resp.data['track'];
      return t != null ? Map<String, dynamic>.from(t as Map) : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Progress heartbeat ───────────────────────────────────────────────────

  Future<void> updateTrackProgress(
      String trackId, int progressMs, bool completed) async {
    try {
      await _dio.post(
        '/tracks/$trackId/progress',
        data: {'progress_ms': progressMs, 'completed': completed},
      );
    } catch (_) {}
  }
}
