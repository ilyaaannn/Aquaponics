import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_scheme.dart';

class DesktopConfig {
  static const int _fallbackPort = 8000;
  static const ServerScheme _fallbackScheme = ServerScheme.http;

  static String? _baseUrl;
  static String? _savedIp;
  static int _savedPort = _fallbackPort;
  static ServerScheme _savedScheme = _fallbackScheme;

  /// Notifier agar seluruh UI di halaman Data Desktop bisa rebuild begitu
  /// IP/domain/port server berubah.
  static final ValueNotifier<String> apiUrlNotifier = ValueNotifier<String>('');

  /// URL dasar. Contoh jaringan lokal: http://192.168.1.10:8000
  /// Contoh akses jarak jauh (mis. lewat Cloudflare Tunnel): https://desktop.namadomain.com
  static String get apiUrl => _baseUrl ?? '';

  /// IP/host aktif yang tersimpan.
  static String get currentIp => _savedIp ?? '';

  /// Port aktif yang tersimpan. 0 berarti tidak ditulis eksplisit di URL.
  static int get currentPort => _savedPort;

  /// Skema koneksi aktif (http/https).
  static ServerScheme get currentScheme => _savedScheme;

  /// True jika skema yang tersimpan adalah HTTPS.
  static bool get isHttps => _savedScheme == ServerScheme.https;

  /// True jika IP server desktop sudah dikonfigurasi oleh pengguna.
  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('desktop_server_ip') ?? '';
    final savedPort = prefs.getInt('desktop_server_port') ?? _fallbackPort;
    final savedScheme = ServerScheme.fromString(
      prefs.getString('desktop_server_scheme'),
    );

    if (savedIp.isNotEmpty) {
      _savedIp = savedIp;
      _savedPort = savedPort;
      _savedScheme = savedScheme;
      _baseUrl = buildServerUrl(savedIp, savedPort, savedScheme);
    } else {
      _savedIp = null;
      _savedPort = _fallbackPort;
      _savedScheme = _fallbackScheme;
      _baseUrl = '';
    }
    apiUrlNotifier.value = _baseUrl ?? '';
    debugPrint('[DesktopConfig] Loaded — URL: $_baseUrl');
  }

  /// Simpan konfigurasi server Desktop.
  static Future<void> setServerIp(
    String ip, {
    int port = _fallbackPort,
    ServerScheme scheme = ServerScheme.http,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanIp = ip.trim();

    if (cleanIp.isNotEmpty) {
      await prefs.setString('desktop_server_ip', cleanIp);
      await prefs.setInt('desktop_server_port', port);
      await prefs.setString('desktop_server_scheme', scheme.label);
      _savedIp = cleanIp;
      _savedPort = port;
      _savedScheme = scheme;
      _baseUrl = buildServerUrl(cleanIp, port, scheme);
    } else {
      await prefs.remove('desktop_server_ip');
      await prefs.remove('desktop_server_port');
      await prefs.remove('desktop_server_scheme');
      _savedIp = null;
      _savedPort = _fallbackPort;
      _savedScheme = _fallbackScheme;
      _baseUrl = '';
    }
    apiUrlNotifier.value = _baseUrl ?? '';
    debugPrint('[DesktopConfig] Updated — URL: $_baseUrl');
  }

  static Future<void> resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('desktop_server_ip');
    await prefs.remove('desktop_server_port');
    await prefs.remove('desktop_server_scheme');
    _savedIp = null;
    _savedPort = _fallbackPort;
    _savedScheme = _fallbackScheme;
    _baseUrl = '';
    apiUrlNotifier.value = '';
  }

  /// Terima alamat IPv4 maupun nama domain/hostname.
  static bool isValidIp(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;

    final ipv4 = RegExp(
      r'^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$',
    );
    if (ipv4.hasMatch(trimmed)) return true;

    final hostname = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]{0,253}[a-zA-Z0-9]$');
    if (hostname.hasMatch(trimmed)) return true;

    if (trimmed == 'localhost') return true;

    return false;
  }
}
