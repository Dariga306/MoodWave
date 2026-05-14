import '../services/api_service.dart';

String buildMediaUrl(String? url, {Object? version}) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('data:')) return url;
  // Resolve server-relative upload paths (e.g. /uploads/...) to full URL
  if (url.startsWith('/')) {
    url = '${ApiService.baseUrl}$url';
  }
  if (version == null) return url;

  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}v=${Uri.encodeQueryComponent(version.toString())}';
}
