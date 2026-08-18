import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_scheme.dart';

class AppConfig {
  static const String _fallbackIp = '';
  static const int _fallbackPort = 5000;
  static const ServerScheme _fallbackScheme = ServerScheme.http;

  static String? _baseUrl;
  static String? _savedIp;
  static int _savedPort = _fallbackPort;
  static ServerScheme _savedScheme = _fallbackScheme;

  // ── Notifier agar seluruh UI bisa rebuild saat IP/domain berubah ────────
  static final ValueNotifier<String> apiUrlNotifier = ValueNotifier<String>('');

  /// URL dasar yang digunakan untuk request API.
  /// Contoh lokal/VPS: http://203.0.113.10:5000
  /// Contoh domain+HTTPS (mis. lewat Nginx/reverse proxy): https://api.namadomain.com
  static String get apiUrl => _baseUrl ?? '';

  /// IP/host aktif yang tersimpan.
  static String get currentIp => _savedIp ?? '';

  /// Port aktif yang tersimpan. 0 berarti tidak ditulis eksplisit di URL
  /// (memakai port standar skema — 80 untuk http, 443 untuk https).
  static int get currentPort => _savedPort;

  /// Skema koneksi aktif (http/https).
  static ServerScheme get currentScheme => _savedScheme;

  /// True jika skema yang tersimpan adalah HTTPS.
  static bool get isHttps => _savedScheme == ServerScheme.https;

  /// true jika konfigurasi sudah diatur oleh pengguna, false jika belum
  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip') ?? _fallbackIp;
    final savedPort = prefs.getInt('server_port') ?? _fallbackPort;
    final savedScheme = ServerScheme.fromString(
      prefs.getString('server_scheme'),
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
    debugPrint('[AppConfig] Loaded — URL: $_baseUrl');
  }

  /// Simpan konfigurasi server SmartFarm.
  static Future<void> setServerIp(
    String ip, {
    int port = _fallbackPort,
    ServerScheme scheme = ServerScheme.http,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanIp = ip.trim();

    if (cleanIp.isNotEmpty) {
      await prefs.setString('server_ip', cleanIp);
      await prefs.setInt('server_port', port);
      await prefs.setString('server_scheme', scheme.label);
      _savedIp = cleanIp;
      _savedPort = port;
      _savedScheme = scheme;
      _baseUrl = buildServerUrl(cleanIp, port, scheme);
    } else {
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
      await prefs.remove('server_scheme');
      _savedIp = null;
      _savedPort = _fallbackPort;
      _savedScheme = _fallbackScheme;
      _baseUrl = '';
    }
    apiUrlNotifier.value = _baseUrl ?? '';
    debugPrint('[AppConfig] Updated — URL: $_baseUrl');
  }

  static Future<void> resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
    await prefs.remove('server_port');
    await prefs.remove('server_scheme');
    _savedIp = null;
    _savedPort = _fallbackPort;
    _savedScheme = _fallbackScheme;
    _baseUrl = '';
    apiUrlNotifier.value = '';
  }

  static String endpoint(String path) {
    if (_baseUrl == null || _baseUrl!.isEmpty) return '';
    return '$_baseUrl$path';
  }

  /// Terima alamat IPv4 maupun nama domain/hostname (termasuk subdomain)
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
