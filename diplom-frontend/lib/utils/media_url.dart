String buildMediaUrl(String? url, {Object? version}) {
  if (url == null || url.isEmpty) return '';
  if (version == null) return url;

  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}v=${Uri.encodeQueryComponent(version.toString())}';
}
