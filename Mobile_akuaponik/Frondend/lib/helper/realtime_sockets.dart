import 'config.dart';
import 'desktop_config.dart';
import 'realtime_socket_service.dart';

final RealtimeSocketService desktopSocket = RealtimeSocketService(
  serviceName: 'Desktop',
  getBaseUrl: () => DesktopConfig.apiUrl,
  dataEvent: 'sensor/realtime',
);

final RealtimeSocketService smartfarmSocket = RealtimeSocketService(
  serviceName: 'Smartfarm',
  getBaseUrl: () => AppConfig.apiUrl,
  dataEvent: 'water_data_update',
);
