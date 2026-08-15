import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class RealtimeSocketService {
  /// Nama service, hanya untuk keperluan log (mis. "Desktop", "Smartfarm").
  final String serviceName;

  /// Pengambil base URL saat ini, mis. () => DesktopConfig.apiUrl
  final String Function() getBaseUrl;

  /// Nama event yang membawa data sensor dari server, mis. 'sensor/realtime'.
  final String dataEvent;

  IO.Socket? _socket;
  String? _connectedUrl;

  /// True jika socket sedang terhubung ke server.
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  /// Payload terakhir yang diterima dari [dataEvent]. Null jika belum ada data.
  final ValueNotifier<Map<String, dynamic>?> latestData =
      ValueNotifier<Map<String, dynamic>?>(null);

  RealtimeSocketService({
    required this.serviceName,
    required this.getBaseUrl,
    required this.dataEvent,
  });

  void connect() {
    final url = getBaseUrl();

    if (url.isEmpty) {
      disconnect();
      return;
    }

    if (_socket != null && _connectedUrl == url) {
      if (_socket!.disconnected) _socket!.connect();
      return;
    }

    // URL berubah (mis. user ganti IP/domain di Setting) → buat koneksi baru
    disconnect();
    _connectedUrl = url;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('[$serviceName Socket] Terhubung ke $url');
        isConnected.value = true;
      })
      ..onDisconnect((_) {
        debugPrint('[$serviceName Socket] Terputus');
        isConnected.value = false;
      })
      ..onConnectError((err) {
        debugPrint('[$serviceName Socket] Connect error: $err');
        isConnected.value = false;
      })
      ..onError((err) {
        debugPrint('[$serviceName Socket] Error: $err');
      })
      ..on(dataEvent, (payload) {
        if (payload is Map) {
          latestData.value = Map<String, dynamic>.from(payload);
        }
      });
  }

  void emitCommand(String event, Map<String, dynamic> payload) {
    if (_socket == null || _socket!.disconnected) {
      debugPrint(
        '[$serviceName Socket] Tidak bisa emit "$event" — socket belum terhubung',
      );
      return;
    }
    _socket!.emit(event, payload);
  }

  void disconnect() {
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
    _connectedUrl = null;
    isConnected.value = false;
  }
}
