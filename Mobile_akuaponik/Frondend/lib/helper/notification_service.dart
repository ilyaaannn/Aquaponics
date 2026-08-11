import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

// Top-level handler: menangani notifikasi saat app TERMINATED
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '[FCM-BG] diterima background: ${DateTime.now()} ${message.messageId}',
  );
  // pesan FCM dikirim sebagai data-only (foreground, background, terminated).
  await NotificationService.showFromRemoteMessage(message);
}

// Channel Android untuk notifikasi lokal
const AndroidNotificationChannel _alertChannel = AndroidNotificationChannel(
  'akuaponik_alert_channel', // id
  'Peringatan Kualitas Air', // name
  description: 'Notifikasi bahaya parameter akuaponik (pH, Suhu, TDS, DO)',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static String? _fcmToken;

  // INISIALISASI — panggil sekali di main() setelah Firebase.initializeApp()
  static Future<void> initialize() async {
    // ── Minta izin notifikasi (iOS & Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] Status izin: ${settings.authorizationStatus}');

    // ── Inisialisasi plugin notifikasi lokal
    const androidInit = AndroidInitializationSettings('logo_apps');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTap(response);
      },
    );

    // ── Buat channel Android untuk notifikasi bahaya
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_alertChannel);

    // ── Background handler (top-level function)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── Foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        '[FCM-FG] diterima foreground: ${DateTime.now()} ${message.messageId}',
      );
      await showFromRemoteMessage(message);
    });

    // Terminated — app dibuka dari notifikasi setelah force-close
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('[FCM] Diterima terminated: ${DateTime.now()}');
      }
    });

    // ── Saat app dibuka dari notifikasi (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] App dibuka dari notifikasi: ${DateTime.now()} ${message.data}',
      );
      _handleNotificationNavigation(message.data);
    });

    // ── Cek apakah app dibuka dari terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCM] App dibuka dari terminated via notifikasi: ${DateTime.now()} ${initialMessage.data}',
      );
      _handleNotificationNavigation(initialMessage.data);
    }

    // ── Dapatkan & daftarkan FCM token
    await _refreshAndRegisterToken();

    // ── Refresh token otomatis jika berubah
    _fcm.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveTokenLocally(newToken);
      await _registerTokenToServer(newToken);
      debugPrint('[FCM] Token diperbarui: $newToken');
    });

    debugPrint('[FCM] NotificationService berhasil diinisialisasi.');
  }

  // AMBIL & DAFTARKAN TOKEN
  static Future<void> _refreshAndRegisterToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        debugPrint('[FCM] Token: $_fcmToken');
        await _saveTokenLocally(_fcmToken!);
        await _registerTokenToServer(_fcmToken!);
      }
    } catch (e) {
      debugPrint('[FCM] Gagal mendapatkan token: $e');
    }
  }

  /// Simpan token ke SharedPreferences
  static Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Kirim token ke backend Flask agar bisa digunakan untuk push
  static Future<void> _registerTokenToServer(String token) async {
    final baseUrl = AppConfig.apiUrl;
    if (baseUrl.isEmpty) {
      debugPrint(
        '[FCM] apiUrl belum dikonfigurasi — token tidak dikirim ke server.',
      );
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/fcm/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'platform': Platform.isAndroid ? 'android' : 'ios',
              'registered_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('[FCM] Registrasi token: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Gagal mengirim token ke server: $e');
    }
  }

  // TAMPILKAN NOTIFIKASI LOKAL
  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final data = message.data;

    // Inisialisasi ulang plugin & channel
    const androidInit = AndroidInitializationSettings('logo_apps');
    const iosInit = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_alertChannel);

    final title = data['title'] ?? 'Peringatan Akuaponik';
    final body = data['body'] ?? 'Ada parameter di luar batas aman.';

    // Warna berdasarkan status
    final status = (data['status'] ?? '').toLowerCase();
    final color = status == 'bahaya' ? 0xFFDC2626 : 0xFFD97706;

    final androidDetails = AndroidNotificationDetails(
      _alertChannel.id,
      _alertChannel.name,
      channelDescription: _alertChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      color: Color(color),
      icon: 'logo_apps',
      largeIcon: null,
      styleInformation: BigTextStyleInformation(body),
      ticker: title,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final id =
        message.messageId?.hashCode ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    await _localNotif.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  // NAVIGASI SAAT NOTIFIKASI DI-TAP
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationNavigation(data);
      } catch (_) {}
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    debugPrint('[FCM-NAV] Data notifikasi: $data');
  }

  // UTILITAS PUBLIK Kembalikan FCM token saat ini (bisa null jika belum siap)
  static String? get currentToken => _fcmToken;

  /// Hapus token dari server & local (logout / ganti akun)
  static Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      _fcmToken = null;
      debugPrint('[FCM] Token dihapus.');
    } catch (e) {
      debugPrint('[FCM] Gagal menghapus token: $e');
    }
  }

  /// Subscribe ke topik FCM (misalnya 'bahaya_alerts')
  static Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('[FCM] Berlangganan topik: $topic');
  }

  /// Unsubscribe dari topik FCM
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Berhenti berlangganan topik: $topic');
  }

  /// Perbarui badge count (iOS)
  static Future<void> setBadgeCount(int count) async {
    await _localNotif
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(badge: true);
    await _localNotif.cancelAll();
  }
}
