import 'package:dio/dio.dart';

class ErrorHelper {
  static String parseError(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;

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

      switch (error.response?.statusCode) {
        case 400:
          return (data is Map ? data['detail']?.toString() : null) ?? 'Invalid request';
        case 401:
          return 'Invalid email or password';
        case 403:
          return 'Access denied';
        case 404:
          return 'Not found';
        case 422:
          return 'Please check your input';
        case 429:
          return 'Too many attempts. Please wait a minute.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
