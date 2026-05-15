import '../services/api_service.dart';

String buildMediaUrl(String? url, {Object? version}) {
  if (url == null || url.isEmpty) return '';
  var resolvedUrl = url;
  if (resolvedUrl.startsWith('data:')) return resolvedUrl;
  if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
    try {
      final uri = Uri.parse(resolvedUrl);
      final apiUri = Uri.parse(ApiService.baseUrl);
      final isLoopbackHost = {
        '127.0.0.1',
        'localhost',
        '0.0.0.0',
        '::1',
        '[::1]',
      }.contains(uri.host.toLowerCase());
      if (isLoopbackHost &&
          (uri.host != apiUri.host || uri.port != apiUri.port)) {
        resolvedUrl = uri
            .replace(
              scheme: apiUri.scheme,
              host: apiUri.host,
              port: apiUri.port,
            )
            .toString();
      }
    } catch (_) {}
  }
  // Resolve server-relative upload paths (e.g. /uploads/...) to full URL
  if (resolvedUrl.startsWith('/')) {
    resolvedUrl = '${ApiService.baseUrl}$resolvedUrl';
  }
  if (version == null) return resolvedUrl;

  final separator = resolvedUrl.contains('?') ? '&' : '?';
  return '$resolvedUrl${separator}v=${Uri.encodeQueryComponent(version.toString())}';
}
