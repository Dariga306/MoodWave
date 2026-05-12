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
    if (defaultTargetPlatform == TargetPlatform.android) {
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
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 35),
      sendTimeout: const Duration(seconds: 30),
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
    final rawArtists = track['artists'];
    if (rawArtists is List) {
      final artists = rawArtists
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
              (item) => (item['name']?.toString().trim().isNotEmpty ?? false))
          .toList();
      if (artists.isNotEmpty) {
        track['artists'] = artists;
        track['artist'] ??=
            artists.map((item) => item['name'].toString()).join(', ');
      }
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

  Map<String, dynamic> _playlistTrackPayload(Map<String, dynamic> rawTrack) {
    final track = _normalizeTrack(rawTrack);
    final spotifyTrackId = (track['spotify_track_id'] ??
            track['spotify_id'] ??
            track['deezer_id'] ??
            track['track_id'] ??
            track['trackId'] ??
            track['id'])
        .toString();

    final durationValue =
        track['duration_ms'] ?? track['trackTimeMillis'] ?? track['duration'];

    int? durationMs;
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.round();
    } else if (durationValue != null) {
      durationMs = int.tryParse(durationValue.toString());
    }

    if (durationMs != null && durationMs > 0 && durationMs <= 9999) {
      durationMs *= 1000;
    }

    return {
      'spotify_track_id': spotifyTrackId,
      'title': (track['title'] ?? track['trackName'] ?? 'Unknown').toString(),
      'artist': (track['artist'] ?? track['artistName'] ?? '').toString(),
      'album': track['album']?.toString(),
      'genre': track['genre']?.toString(),
      'cover_url': (track['cover_url'] ?? track['artworkUrl100'])?.toString(),
      'preview_url': (track['preview_url'] ?? track['previewUrl'])?.toString(),
      if (durationMs != null) 'duration_ms': durationMs,
    };
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
        options: Options(receiveTimeout: const Duration(seconds: 40)),
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
    final data = Map<String, dynamic>.from(resp.data as Map);
    final artist = data['artist'];
    if (artist is Map) {
      data['artist'] = _normalizeArtistMap(Map<String, dynamic>.from(artist));
    }
    return data;
  }

  Map<String, dynamic> _normalizeArtistMap(Map<String, dynamic> artist) {
    final id =
        artist['id'] ?? artist['deezer_artist_id'] ?? artist['artist_id'];
    final name = (artist['name'] ??
            artist['artist_name'] ??
            artist['title'] ??
            (id == null ? 'Artist' : 'Artist $id'))
        .toString();
    final picture = (artist['picture_xl'] ??
            artist['picture_big'] ??
            artist['picture_medium'] ??
            artist['picture'] ??
            artist['image_url'] ??
            artist['photo_url'] ??
            artist['avatar_url'])
        ?.toString();
    return {
      ...artist,
      'id': id,
      'name': name,
      if (picture != null && picture.isNotEmpty) ...{
        'picture_xl': artist['picture_xl'] ?? picture,
        'picture_big': artist['picture_big'] ?? picture,
        'picture_medium': artist['picture_medium'] ?? picture,
        'picture': artist['picture'] ?? picture,
        'image_url': artist['image_url'] ?? picture,
      },
      'nb_fan': artist['nb_fan'] ?? artist['fans'] ?? artist['followers'] ?? 0,
      'nb_album': artist['nb_album'] ?? artist['album_count'] ?? 0,
    };
  }

  bool _needsArtistHydration(Map<String, dynamic> artist) {
    final name = (artist['name'] ?? '').toString();
    final picture = (artist['picture_xl'] ??
            artist['picture_big'] ??
            artist['picture_medium'] ??
            artist['picture'] ??
            artist['image_url'])
        ?.toString();
    return name.isEmpty ||
        RegExp(r'^Artist\s+\d+$').hasMatch(name) ||
        picture == null ||
        picture.isEmpty;
  }

  Future<Map<String, dynamic>> _hydrateArtist(dynamic item) async {
    if (item is num || item is String) {
      final id = item.toString();
      try {
        final profile = await getArtistProfile(id);
        final artist = profile['artist'];
        if (artist is Map) {
          return _normalizeArtistMap(Map<String, dynamic>.from(artist));
        }
      } catch (_) {}
      return {'id': item, 'name': 'Artist $item'};
    }

    if (item is! Map) return {};
    final artist = _normalizeArtistMap(Map<String, dynamic>.from(item));
    final id = artist['id'];
    if (id == null || !_needsArtistHydration(artist)) return artist;

    try {
      final profile = await getArtistProfile(id.toString());
      final resolved = profile['artist'];
      if (resolved is Map && resolved.isNotEmpty) {
        return _normalizeArtistMap(Map<String, dynamic>.from(resolved));
      }
    } catch (_) {}
    return artist;
  }

  Future<List<Map<String, dynamic>>> _hydrateArtists(List raw) async {
    final hydrated = await Future.wait(raw.map(_hydrateArtist));
    return hydrated
        .where((artist) => artist.isNotEmpty)
        .map((artist) => Map<String, dynamic>.from(artist))
        .toList();
  }

  Future<List<Map<String, dynamic>>> hydrateArtists(List raw) {
    return _hydrateArtists(raw);
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

  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final resp = await _dio.get(
        '/users/search',
        queryParameters: {
          'q': q,
          'limit': limit,
        },
      );
      final raw = (resp.data as Map<String, dynamic>)['users'] as List? ?? [];
      return raw
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
      String? coverUrl,
      int? sourcePlaylistId}) async {
    final resp = await _dio.post('/playlists/', data: {
      'title': title,
      'visibility': visibility,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (sourcePlaylistId != null) 'source_playlist_id': sourcePlaylistId,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getPlaylist(int id) async {
    final resp = await _dio.get('/playlists/$id');
    return resp.data;
  }

  Future<void> addTrackToPlaylist(
      int playlistId, Map<String, dynamic> track) async {
    await _dio.post(
      '/playlists/$playlistId/tracks',
      data: _playlistTrackPayload(track),
    );
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
    try {
      final details = await getFollowedArtistsDetails();
      if (details.isNotEmpty) {
        return details
            .whereType<Map>()
            .map((item) => item['id'])
            .where((id) => id != null)
            .toList();
      }
    } catch (_) {}
    final resp = await _dio.get('/users/me/following');
    return resp.data as List? ?? [];
  }

  Future<List<dynamic>> getFollowedArtistsDetails() async {
    try {
      final resp = await _dio.get('/users/me/following/details');
      final details = resp.data as List? ?? [];
      if (details.isNotEmpty) {
        return await _hydrateArtists(details);
      }
    } catch (_) {
      // Fall through to the id-based fallback below.
    }
    try {
      final ids = await getFollowedArtistIds();
      final profiles = await Future.wait(
        ids.map((id) async {
          try {
            return await getArtistProfile(id.toString());
          } catch (_) {
            return {
              'id': id,
              'name': 'Artist $id',
            };
          }
        }),
      );
      return profiles.map((profile) {
        final artist = profile['artist'];
        if (artist is Map) {
          return _normalizeArtistMap(Map<String, dynamic>.from(artist));
        }
        return profile;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserFollowingArtists(
    int userId, {
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final resp = await _dio.get(
        '/users/$userId/following/artists',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return await _hydrateArtists(resp.data as List? ?? const []);
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getFollowedArtistIds() async {
    final resp = await _dio.get('/users/me/following');
    return resp.data as List? ?? [];
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

  Future<Map<String, dynamic>> createListeningRoom({
    String? name,
    bool isPublic = false,
    int maxGuests = 10,
  }) async {
    final resp = await _dio.post('/rooms/create', data: {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'is_public': isPublic,
      'max_guests': maxGuests,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> sendJoinRequest(int roomId) async {
    await _dio.post('/rooms/$roomId/join-request');
  }

  Future<List<dynamic>> getRoomMessages(int roomId, {int limit = 50}) async {
    final resp = await _dio.get('/rooms/$roomId/messages', queryParameters: {'limit': limit});
    return (resp.data['messages'] as List?) ?? [];
  }

  Future<void> sendRoomMessage(int roomId, String text) async {
    await _dio.post('/rooms/$roomId/messages', data: {'text': text});
  }

  Future<List<dynamic>> getRoomQueue(int roomId) async {
    final resp = await _dio.get('/rooms/$roomId/queue');
    return (resp.data['queue'] as List?) ?? [];
  }

  Future<void> addToRoomQueue(int roomId, Map<String, dynamic> track) async {
    await _dio.post('/rooms/$roomId/queue', data: track);
  }

  Future<void> removeFromRoomQueue(int roomId, int index) async {
    await _dio.delete('/rooms/$roomId/queue/$index');
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

  Future<void> blockUser(int userId) async {
    await _dio.post('/social/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _dio.delete('/social/users/$userId/block');
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

  Future<Map<String, dynamic>> getUserProfileSummary(
    int userId, {
    int playlistLimit = 8,
    int tracksLimit = 8,
  }) async {
    final resp = await _dio.get(
      '/users/$userId/summary',
      queryParameters: {
        'playlist_limit': playlistLimit,
        'tracks_limit': tracksLimit,
      },
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> saveFavoriteArtists(List<Map<String, dynamic>> artists) async {
    final desiredIds = artists
        .map((a) => a['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final currentIds = (await getFollowedArtistIds())
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in currentIds.difference(desiredIds)) {
      await unfollowArtist(id);
    }
    for (final id in desiredIds.difference(currentIds)) {
      await followArtist(id);
    }
  }

  Future<Map<String, dynamic>> savePlaylistToLibrary(
    Map<String, dynamic> playlist,
  ) async {
    final title = (playlist['title'] ?? 'Saved Playlist').toString();
    final description = (playlist['description'] ?? '').toString();
    final coverUrl = (playlist['cover_url'] ?? '').toString();
    final detail = await getPlaylist((playlist['id'] as num).toInt());
    final sourcePlaylistId = (detail['source_playlist_id'] as num?)?.toInt() ??
        (playlist['source_playlist_id'] as num?)?.toInt() ??
        (playlist['id'] as num?)?.toInt();
    final created = await createPlaylist(
      title,
      visibility: 'saved',
      description: description.isNotEmpty ? description : null,
      coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
      sourcePlaylistId: sourcePlaylistId,
    );
    return created;
  }

  Future<List<dynamic>> getDirectChatMessages(int chatId,
      {int limit = 50}) async {
    final resp = await _dio.get(
      '/chats/thread/$chatId/messages',
      queryParameters: {'limit': limit},
    );
    return resp.data['messages'] ?? [];
  }

  Future<void> sendDirectTextMessage(int chatId, String text) async {
    await _dio.post('/chats/thread/$chatId/send-text', data: {'text': text});
  }

  Future<void> sendTrackInChat(
    int matchId, {
    required String trackId,
    required String title,
    required String artist,
    String? coverUrl,
    String? previewUrl,
    String? phrase,
    String? phraseEmoji,
    String? note,
  }) async {
    await _dio.post('/chats/$matchId/send-track', data: {
      'track_id': trackId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (previewUrl != null && previewUrl.isNotEmpty)
        'preview_url': previewUrl,
      if (phrase != null && phrase.isNotEmpty) 'phrase': phrase,
      if (phraseEmoji != null && phraseEmoji.isNotEmpty)
        'phrase_emoji': phraseEmoji,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendTrackInDirectChat(
    int chatId, {
    required String trackId,
    required String title,
    required String artist,
    String? coverUrl,
    String? previewUrl,
    String? phrase,
    String? phraseEmoji,
    String? note,
  }) async {
    await _dio.post('/chats/thread/$chatId/send-track', data: {
      'track_id': trackId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (previewUrl != null && previewUrl.isNotEmpty)
        'preview_url': previewUrl,
      if (phrase != null && phrase.isNotEmpty) 'phrase': phrase,
      if (phraseEmoji != null && phraseEmoji.isNotEmpty)
        'phrase_emoji': phraseEmoji,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendAlbumInChat(
    int matchId, {
    required String albumId,
    required String title,
    required String artist,
    String? coverUrl,
    String? note,
  }) async {
    await _dio.post('/chats/$matchId/send-album', data: {
      'album_id': albumId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendAlbumInDirectChat(
    int chatId, {
    required String albumId,
    required String title,
    required String artist,
    String? coverUrl,
    String? note,
  }) async {
    await _dio.post('/chats/thread/$chatId/send-album', data: {
      'album_id': albumId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendPlaylistInChat(
    int matchId, {
    required int playlistId,
    required String title,
    String? coverUrl,
    int trackCount = 0,
    String? note,
  }) async {
    await _dio.post('/chats/$matchId/send-playlist', data: {
      'playlist_id': playlistId,
      'title': title,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      'track_count': trackCount,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendPlaylistInDirectChat(
    int chatId, {
    required int playlistId,
    required String title,
    String? coverUrl,
    int trackCount = 0,
    String? note,
  }) async {
    await _dio.post('/chats/thread/$chatId/send-playlist', data: {
      'playlist_id': playlistId,
      'title': title,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      'track_count': trackCount,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendImageInChat(
    int matchId, {
    required String imageDataUrl,
    String? caption,
  }) async {
    await _dio.post('/chats/$matchId/send-image', data: {
      'image_data_url': imageDataUrl,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
  }

  Future<void> sendImageInDirectChat(
    int chatId, {
    required String imageDataUrl,
    String? caption,
  }) async {
    await _dio.post('/chats/thread/$chatId/send-image', data: {
      'image_data_url': imageDataUrl,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
  }

  Future<void> reactToMessage(
      int matchId, String messageId, String emoji) async {
    await _dio.post('/chats/$matchId/react', data: {
      'message_id': messageId,
      'emoji': emoji,
    });
  }

  Future<void> reactToDirectMessage(
      int chatId, String messageId, String emoji) async {
    await _dio.post('/chats/thread/$chatId/react', data: {
      'message_id': messageId,
      'emoji': emoji,
    });
  }

  Future<Map<String, dynamic>> startDirectChat(int userId) async {
    final resp = await _dio.post('/chats/direct/$userId/start');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> createGroupChat({
    required String title,
    required List<int> memberIds,
    String? avatarUrl,
  }) async {
    final resp = await _dio.post('/chats/groups', data: {
      'title': title,
      'member_ids': memberIds,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getGroupChatDetails(int groupChatId) async {
    final resp = await _dio.get('/chats/groups/$groupChatId');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<List<dynamic>> getGroupChatMessages(int groupChatId,
      {int limit = 50}) async {
    final resp = await _dio.get(
      '/chats/groups/$groupChatId/messages',
      queryParameters: {'limit': limit},
    );
    return resp.data['messages'] ?? [];
  }

  Future<void> sendGroupTextMessage(int groupChatId, String text) async {
    await _dio
        .post('/chats/groups/$groupChatId/send-text', data: {'text': text});
  }

  Future<void> sendTrackInGroupChat(
    int groupChatId, {
    required String trackId,
    required String title,
    required String artist,
    String? coverUrl,
    String? previewUrl,
    String? phrase,
    String? phraseEmoji,
    String? note,
  }) async {
    await _dio.post('/chats/groups/$groupChatId/send-track', data: {
      'track_id': trackId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (previewUrl != null && previewUrl.isNotEmpty)
        'preview_url': previewUrl,
      if (phrase != null && phrase.isNotEmpty) 'phrase': phrase,
      if (phraseEmoji != null && phraseEmoji.isNotEmpty)
        'phrase_emoji': phraseEmoji,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendAlbumInGroupChat(
    int groupChatId, {
    required String albumId,
    required String title,
    required String artist,
    String? coverUrl,
    String? note,
  }) async {
    await _dio.post('/chats/groups/$groupChatId/send-album', data: {
      'album_id': albumId,
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendPlaylistInGroupChat(
    int groupChatId, {
    required int playlistId,
    required String title,
    String? coverUrl,
    int trackCount = 0,
    String? note,
  }) async {
    await _dio.post('/chats/groups/$groupChatId/send-playlist', data: {
      'playlist_id': playlistId,
      'title': title,
      if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
      'track_count': trackCount,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> sendImageInGroupChat(
    int groupChatId, {
    required String imageDataUrl,
    String? caption,
  }) async {
    await _dio.post('/chats/groups/$groupChatId/send-image', data: {
      'image_data_url': imageDataUrl,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
  }

  Future<void> reactToGroupMessage(
      int groupChatId, String messageId, String emoji) async {
    await _dio.post('/chats/groups/$groupChatId/react', data: {
      'message_id': messageId,
      'emoji': emoji,
    });
  }

  Future<void> deleteMessage({
    int? matchId,
    int? chatId,
    int? groupChatId,
    required String messageId,
  }) async {
    if (groupChatId != null) {
      await _dio.delete('/chats/groups/$groupChatId/messages/$messageId');
    } else if (chatId != null) {
      await _dio.delete('/chats/thread/$chatId/messages/$messageId');
    } else if (matchId != null) {
      await _dio.delete('/chats/$matchId/messages/$messageId');
    }
  }

  Future<void> leaveGroupChat(int groupChatId) async {
    await _dio.delete('/chats/groups/$groupChatId/leave');
  }

  Future<void> removeGroupChatMember(int groupChatId, int userId) async {
    await _dio.delete('/chats/groups/$groupChatId/members/$userId');
  }

  Future<void> transferGroupChatOwner(int groupChatId, int newOwnerId) async {
    await _dio.post('/chats/groups/$groupChatId/transfer-owner', data: {'new_owner_id': newOwnerId});
  }

  Future<Map<String, dynamic>> updateGroupChat(int groupChatId, {String? title, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    final resp = await _dio.patch('/chats/groups/$groupChatId', data: data);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> makeGroupChatAdmin(int groupChatId, int userId) async {
    await _dio.post('/chats/groups/$groupChatId/members/$userId/make-admin');
  }

  Future<void> revokeGroupChatAdmin(int groupChatId, int userId) async {
    await _dio.delete('/chats/groups/$groupChatId/members/$userId/admin');
  }

  Future<Map<String, dynamic>?> getUserNowPlaying(int userId) async {
    try {
      final resp = await _dio.get('/users/$userId/now-playing');
      return Map<String, dynamic>.from(resp.data as Map);
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
