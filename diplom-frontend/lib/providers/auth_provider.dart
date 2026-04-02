import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  String? _error;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  Future<void> checkAuth() async {
    final token = await _api.getToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await _api.getMe();
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _api.clearTokens();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final data = await _api.login(email: email, password: password);
      _user = data['user'];
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    _error = null;
    try {
      final data = await _api.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
      );
      _user = data['user'];
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    _error = null;
    try {
      final data = await _api.loginWithGoogle(idToken);
      _user = data['user'];
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithFirebasePhone(String firebaseToken) async {
    _error = null;
    try {
      final data = await _api.loginWithFirebasePhone(firebaseToken);
      _user = data['user'];
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> data) {
    _user = {...?_user, ...data};
    notifyListeners();
  }

  String _parseError(Exception e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail[0];
          if (first is Map && first['msg'] != null) {
            String msg = first['msg'].toString();
            msg = msg.replaceAll('Value error, ', '');
            msg = msg.replaceAll('value_error: ', '');
            return msg;
          }
        }
      }
      if (e.response?.statusCode == 400) return (data is Map ? data['detail']?.toString() : null) ?? 'Invalid data. Check your inputs.';
      if (e.response?.statusCode == 401) return 'Wrong email or password.';
      if (e.response?.statusCode == 409) return 'Email already registered.';
      if (e.response?.statusCode == 422) return 'Please check your input.';
      if (e.response?.statusCode == 429) return 'Too many attempts. Please wait a minute.';
      return 'Server error. Try again.';
    }
    return e.toString();
  }
}
