import 'dart:html' as html;

Future<String?> readWebToken(String key) async {
  return html.window.localStorage[key];
}

Future<void> writeWebToken(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<void> deleteWebToken(String key) async {
  html.window.localStorage.remove(key);
}
