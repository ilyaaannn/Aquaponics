import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _fallbackIp = '';
  static const int _fallbackPort = 5000;
  static String? _baseUrl;
  static String? _savedIp;
  static int _savedPort = _fallbackPort;

  // ── Notifier agar seluruh UI bisa rebuild saat IP berubah ────────────────
  static final ValueNotifier<String> apiUrlNotifier = ValueNotifier<String>('');

  /// URL dasar yang digunakan untuk request API
  static String get apiUrl => _baseUrl ?? '';

  /// IP/host aktif yang tersimpan
  static String get currentIp => _savedIp ?? '';

  /// Port aktif yang tersimpan
  static int get currentPort => _savedPort;

  /// true jika konfigurasi sudah diatur oleh pengguna, false jika belum
  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip') ?? _fallbackIp;
    final savedPort = prefs.getInt('server_port') ?? _fallbackPort;

    if (savedIp.isNotEmpty) {
      _savedIp = savedIp;
      _savedPort = savedPort;
      _baseUrl = 'http://$savedIp:$savedPort';
    } else {
      _savedIp = null;
      _savedPort = _fallbackPort;
      _baseUrl = '';
    }
    apiUrlNotifier.value = _baseUrl ?? '';
    debugPrint('[AppConfig] Loaded — URL: $_baseUrl');
  }

  static Future<void> setServerIp(String ip, {int port = _fallbackPort}) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanIp = ip.trim();

    if (cleanIp.isNotEmpty) {
      await prefs.setString('server_ip', cleanIp);
      await prefs.setInt('server_port', port);
      _savedIp = cleanIp;
      _savedPort = port;
      _baseUrl = 'http://$cleanIp:$port';
    } else {
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
      _savedIp = null;
      _savedPort = _fallbackPort;
      _baseUrl = '';
    }
    apiUrlNotifier.value = _baseUrl ?? '';
    debugPrint('[AppConfig] Updated — URL: $_baseUrl');
  }

  static Future<void> resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
    await prefs.remove('server_port');
    _savedIp = null;
    _savedPort = _fallbackPort;
    _baseUrl = '';
    apiUrlNotifier.value = '';
  }

  static String endpoint(String path) {
    if (_baseUrl == null || _baseUrl!.isEmpty) return '';
    return '$_baseUrl$path';
  }

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
