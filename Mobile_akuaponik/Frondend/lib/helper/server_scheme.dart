/// Skema koneksi yang didukung untuk server Smartfarm maupun server Desktop.
/// - [http]  : akses langsung via IP lokal/publik + port
/// - [https] : akses via domain terenkripsi
enum ServerScheme {
  http,
  https;

  String get label => this == ServerScheme.https ? 'https' : 'http';

  static ServerScheme fromString(String? value) {
    return value == 'https' ? ServerScheme.https : ServerScheme.http;
  }
}

/// Bangun base URL dari host, port opsional, dan skema.
String buildServerUrl(String host, int port, ServerScheme scheme) {
  final isDefaultPort =
      (scheme == ServerScheme.https && port == 443) ||
      (scheme == ServerScheme.http && port == 80);
  if (port <= 0 || isDefaultPort) {
    return '${scheme.label}://$host';
  }
  return '${scheme.label}://$host:$port';
}
