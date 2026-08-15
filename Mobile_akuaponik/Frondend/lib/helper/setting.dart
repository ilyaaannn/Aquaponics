import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'config.dart';
import 'desktop_config.dart';
import 'realtime_sockets.dart';
import 'header.dart';
import 'guide.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // ────────────────────────────────────────────────────────────────────
  // SERVER SMARTFARM (AI) — AppConfig, REST, default port 5000
  // ────────────────────────────────────────────────────────────────────
  final TextEditingController _smartfarmIpController = TextEditingController();
  final TextEditingController _smartfarmPortController =
      TextEditingController();
  String _smartfarmStatus = 'Belum Terkonfigurasi';
  bool _smartfarmConnected = false;
  bool _smartfarmChecking = false;
  String _smartfarmModel = '';
  String _smartfarmFirebase = '';
  int _smartfarmFcmTokenCount = 0;

  // ────────────────────────────────────────────────────────────────────
  // SERVER DESKTOP (Kabel) — DesktopConfig, Socket.IO, default port 8000
  // ────────────────────────────────────────────────────────────────────
  final TextEditingController _desktopIpController = TextEditingController();
  final TextEditingController _desktopPortController = TextEditingController();
  String _desktopStatus = 'Belum Terkonfigurasi';
  bool _desktopHealthOk = false;
  bool _desktopChecking = false;
  String _desktopRedisStatus = '';
  String _desktopSerialStatus = '';

  // Kontrol aktuator (dibaca dari data live server Desktop, bukan REST lagi)
  bool isAeratorOn = false;
  bool isPompaAirOn = false;

  @override
  void initState() {
    super.initState();

    _smartfarmIpController.text = AppConfig.currentIp;
    _smartfarmPortController.text = AppConfig.currentPort.toString();
    AppConfig.apiUrlNotifier.addListener(_onSmartfarmUrlChanged);
    if (AppConfig.isConfigured) {
      _checkSmartfarmConnection(showDialog: false);
    }

    _desktopIpController.text = DesktopConfig.currentIp;
    _desktopPortController.text = DesktopConfig.currentPort.toString();
    DesktopConfig.apiUrlNotifier.addListener(_onDesktopUrlChanged);
    if (DesktopConfig.isConfigured) {
      desktopSocket.connect();
      _checkDesktopConnection(showDialog: false);
    }

    desktopSocket.latestData.addListener(_onDesktopLiveData);
    desktopSocket.isConnected.addListener(_onDesktopSocketStatusChanged);
  }

  void _onSmartfarmUrlChanged() {
    if (!mounted) return;
    final newIp = AppConfig.currentIp;
    final newPort = AppConfig.currentPort.toString();
    if (_smartfarmIpController.text != newIp)
      _smartfarmIpController.text = newIp;
    if (_smartfarmPortController.text != newPort)
      _smartfarmPortController.text = newPort;

    if (AppConfig.isConfigured) {
      _checkSmartfarmConnection(showDialog: false);
    } else {
      setState(() {
        _smartfarmConnected = false;
        _smartfarmStatus = 'Belum Terkonfigurasi';
        _smartfarmModel = '';
        _smartfarmFirebase = '';
        _smartfarmFcmTokenCount = 0;
      });
    }
  }

  void _onDesktopUrlChanged() {
    if (!mounted) return;
    final newIp = DesktopConfig.currentIp;
    final newPort = DesktopConfig.currentPort.toString();
    if (_desktopIpController.text != newIp) _desktopIpController.text = newIp;
    if (_desktopPortController.text != newPort)
      _desktopPortController.text = newPort;

    if (DesktopConfig.isConfigured) {
      desktopSocket.connect();
      _checkDesktopConnection(showDialog: false);
    } else {
      desktopSocket.disconnect();
      setState(() {
        _desktopHealthOk = false;
        _desktopStatus = 'Belum Terkonfigurasi';
        _desktopRedisStatus = '';
        _desktopSerialStatus = '';
        isAeratorOn = false;
        isPompaAirOn = false;
      });
    }
  }

  void _onDesktopLiveData() {
    if (!mounted) return;
    final data = desktopSocket.latestData.value;
    if (data == null) return;
    setState(() {
      final pump = data['pump_status'];
      final oxy = data['oxy_status'];
      isPompaAirOn = pump == 1 || pump == true;
      isAeratorOn = oxy == 1 || oxy == true;
    });
  }

  void _onDesktopSocketStatusChanged() {
    if (!mounted) return;
    setState(() {}); // refresh enable/disable switch berdasarkan koneksi socket
  }

  @override
  void dispose() {
    AppConfig.apiUrlNotifier.removeListener(_onSmartfarmUrlChanged);
    DesktopConfig.apiUrlNotifier.removeListener(_onDesktopUrlChanged);
    desktopSocket.latestData.removeListener(_onDesktopLiveData);
    desktopSocket.isConnected.removeListener(_onDesktopSocketStatusChanged);
    _smartfarmIpController.dispose();
    _smartfarmPortController.dispose();
    _desktopIpController.dispose();
    _desktopPortController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────
  // SMARTFARM — cek koneksi & hubungkan
  // ────────────────────────────────────────────────────────────────────
  Future<void> _checkSmartfarmConnection({bool showDialog = true}) async {
    if (!AppConfig.isConfigured) {
      setState(() {
        _smartfarmStatus = 'URL belum dikonfigurasi';
        _smartfarmConnected = false;
      });
      return;
    }

    setState(() {
      _smartfarmChecking = true;
      _smartfarmStatus = 'Memeriksa...';
    });

    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiUrl}/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _smartfarmConnected = true;
          _smartfarmStatus = 'Terhubung';
          _smartfarmModel = data['model'] ?? '';
          _smartfarmFirebase = data['firebase'] ?? '';
          _smartfarmFcmTokenCount = data['fcm_tokens_total'] ?? 0;
        });
        if (showDialog) {
          _showSnack(
            '✓ Berhasil terhubung ke ${AppConfig.apiUrl}',
            success: true,
          );
        }
      } else {
        setState(() {
          _smartfarmConnected = false;
          _smartfarmStatus = 'Server error ${response.statusCode}';
        });
        if (showDialog) {
          _showSnack(
            'Server merespons dengan kode ${response.statusCode}',
            success: false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _smartfarmConnected = false;
        _smartfarmStatus = 'Tidak dapat terhubung';
      });
      if (showDialog) {
        _showSnack(
          'Gagal terhubung: periksa IP, port, dan jaringan.',
          success: false,
        );
      }
    } finally {
      setState(() => _smartfarmChecking = false);
    }
  }

  Future<void> _connectToSmartfarm() async {
    final ip = _smartfarmIpController.text.trim();
    final port = int.tryParse(_smartfarmPortController.text.trim()) ?? 5000;

    if (ip.isEmpty) {
      _showSnack('Masukkan IP address server terlebih dahulu.', success: false);
      return;
    }
    if (!AppConfig.isValidIp(ip)) {
      _showSnack('Format IP tidak valid. Contoh: 192.168.1.5', success: false);
      return;
    }

    await AppConfig.setServerIp(ip, port: port);
    setState(() {
      _smartfarmConnected = false;
      _smartfarmStatus = 'Menghubungkan...';
    });
    await _checkSmartfarmConnection(showDialog: true);
  }

  Future<void> _disconnectSmartfarm() async {
    final confirm = await _confirmDisconnect(
      'Konfigurasi server Smartfarm (IP/Domain & port) akan dihapus dan aplikasi '
      'akan terputus dari server AI.',
    );
    if (confirm != true) return;

    await AppConfig.resetConfig();
    setState(() {
      _smartfarmIpController.clear();
      _smartfarmPortController.clear();
      _smartfarmConnected = false;
      _smartfarmStatus = 'Belum Terkonfigurasi';
      _smartfarmModel = '';
      _smartfarmFirebase = '';
      _smartfarmFcmTokenCount = 0;
    });
    _showSnack('Koneksi server Smartfarm telah diputuskan.', success: false);
  }

  // ────────────────────────────────────────────────────────────────────
  // DESKTOP — cek koneksi & hubungkan
  // ────────────────────────────────────────────────────────────────────
  Future<void> _checkDesktopConnection({bool showDialog = true}) async {
    if (!DesktopConfig.isConfigured) {
      setState(() {
        _desktopStatus = 'URL belum dikonfigurasi';
        _desktopHealthOk = false;
      });
      return;
    }

    setState(() {
      _desktopChecking = true;
      _desktopStatus = 'Memeriksa...';
    });

    try {
      final response = await http
          .get(Uri.parse('${DesktopConfig.apiUrl}/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _desktopHealthOk = true;
          _desktopStatus = 'Terhubung';
          _desktopRedisStatus = data['redis'] ?? '';
          _desktopSerialStatus = data['serial'] ?? '';
        });
        // Pastikan socket streaming juga aktif setelah REST health check sukses
        desktopSocket.connect();
        if (showDialog) {
          _showSnack(
            '✓ Berhasil terhubung ke ${DesktopConfig.apiUrl}',
            success: true,
          );
        }
      } else {
        setState(() {
          _desktopHealthOk = false;
          _desktopStatus = 'Server error ${response.statusCode}';
        });
        if (showDialog) {
          _showSnack(
            'Server merespons dengan kode ${response.statusCode}',
            success: false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _desktopHealthOk = false;
        _desktopStatus = 'Tidak dapat terhubung';
      });
      if (showDialog) {
        _showSnack(
          'Gagal terhubung: periksa IP, port, dan jaringan.',
          success: false,
        );
      }
    } finally {
      setState(() => _desktopChecking = false);
    }
  }

  Future<void> _connectToDesktop() async {
    final ip = _desktopIpController.text.trim();
    final port = int.tryParse(_desktopPortController.text.trim()) ?? 8000;

    if (ip.isEmpty) {
      _showSnack(
        'Masukkan IP address server desktop terlebih dahulu.',
        success: false,
      );
      return;
    }
    if (!DesktopConfig.isValidIp(ip)) {
      _showSnack('Format IP tidak valid. Contoh: 192.168.1.10', success: false);
      return;
    }

    await DesktopConfig.setServerIp(ip, port: port);
    setState(() {
      _desktopHealthOk = false;
      _desktopStatus = 'Menghubungkan...';
    });
    desktopSocket.connect();
    await _checkDesktopConnection(showDialog: true);
  }

  Future<void> _disconnectDesktop() async {
    final confirm = await _confirmDisconnect(
      'Konfigurasi server Desktop (IP/Domain & port) akan dihapus dan aplikasi '
      'akan terputus dari Raspberry Pi/PC yang menjalankan Aplikasi Desktop.',
    );
    if (confirm != true) return;

    desktopSocket.disconnect();
    await DesktopConfig.resetConfig();
    setState(() {
      _desktopIpController.clear();
      _desktopPortController.clear();
      _desktopHealthOk = false;
      _desktopStatus = 'Belum Terkonfigurasi';
      _desktopRedisStatus = '';
      _desktopSerialStatus = '';
      isAeratorOn = false;
      isPompaAirOn = false;
    });
    _showSnack('Koneksi server Desktop telah diputuskan.', success: false);
  }

  Future<bool?> _confirmDisconnect(String detail) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Putuskan Koneksi?',
          style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(detail, style: GoogleFonts.inter(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Putuskan',
              style: GoogleFonts.inter(
                color: AppTheme.statusDanger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // KONTROL AKTUATOR
  // ────────────────────────────────────────────────────────────────────
  void _sendCommand(String device, bool state) {
    if (!DesktopConfig.isConfigured || !desktopSocket.isConnected.value) {
      _showSnack(
        'Tidak terhubung ke server Desktop. Hubungkan terlebih dahulu.',
        success: false,
      );
      return;
    }

    final int stateInt = state ? 1 : 0;
    final String prefix = device == 'aerator' ? 'OKSIGEN' : 'POMPA';

    desktopSocket.emitCommand('actuator/command', {
      'command': '$prefix:$stateInt',
    });
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: success
            ? AppTheme.primaryGreen
            : AppTheme.statusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHeader() {
    return CustomAppHeader(
      title: 'PENGATURAN SISTEM',
      showStatus: false,
      trailing: IconButton(
        onPressed: () => AppGuide.showHelpDialog(context),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        tooltip: 'Bantuan',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                child: Column(
                  children: [
                    _buildSectionLabel('🧠', 'SERVER SMARTFARM'),
                    const SizedBox(height: 10),
                    _buildServerCard(
                      icon: Icons.psychology_rounded,
                      ipController: _smartfarmIpController,
                      portController: _smartfarmPortController,
                      portHint: '5000',
                      isConfigured: AppConfig.isConfigured,
                      isChecking: _smartfarmChecking,
                      isConnected: _smartfarmConnected,
                      statusLabel: _smartfarmStatus,
                      onConnect: _connectToSmartfarm,
                      onDisconnect: _disconnectSmartfarm,
                      onRetest: () =>
                          _checkSmartfarmConnection(showDialog: true),
                      extraInfo: _smartfarmConnected
                          ? 'Model: ${_smartfarmModel.isEmpty ? '-' : _smartfarmModel}  •  '
                                'Firebase: ${_smartfarmFirebase.isEmpty ? '-' : _smartfarmFirebase}  •  '
                                'FCM: $_smartfarmFcmTokenCount token'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _buildSectionLabel('🖥️', 'SERVER DESKTOP'),
                    const SizedBox(height: 10),
                    _buildServerCard(
                      icon: Icons.computer_rounded,
                      ipController: _desktopIpController,
                      portController: _desktopPortController,
                      portHint: '8000',
                      isConfigured: DesktopConfig.isConfigured,
                      isChecking: _desktopChecking,
                      isConnected: _desktopHealthOk,
                      statusLabel: _desktopStatus,
                      onConnect: _connectToDesktop,
                      onDisconnect: _disconnectDesktop,
                      onRetest: () => _checkDesktopConnection(showDialog: true),
                      extraInfo: _desktopHealthOk
                          ? 'Redis: ${_desktopRedisStatus.isEmpty ? '-' : _desktopRedisStatus}  •  '
                                'Serial: ${_desktopSerialStatus.isEmpty ? '-' : _desktopSerialStatus}  •  '
                                'Stream: ${desktopSocket.isConnected.value ? 'live' : 'menunggu...'}'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _buildSectionLabel('⚙️', 'KONTROL MANUAL'),
                    const SizedBox(height: 10),
                    _buildControlCard(),
                    const SizedBox(height: 20),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.body(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ).copyWith(letterSpacing: 1.0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: Theme.of(context).dividerColor, thickness: 1.2),
        ),
      ],
    );
  }

  /// Kartu koneksi server generik — dipakai untuk kartu Smartfarm maupun Desktop.
  Widget _buildServerCard({
    required IconData icon,
    required TextEditingController ipController,
    required TextEditingController portController,
    required String portHint,
    required bool isConfigured,
    required bool isChecking,
    required bool isConnected,
    required String statusLabel,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
    required VoidCallback onRetest,
    String? extraInfo,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Status Koneksi',
                            style: AppTheme.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      _buildStatusBadge(
                        isChecking: isChecking,
                        isConnected: isConnected,
                        isConfigured: isConfigured,
                        statusLabel: statusLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: ipController,
                    hint: '',
                    label: 'IP Address / Domain',
                    icon: Icons.dns_rounded,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: portController,
                    hint: portHint,
                    label: 'Port',
                    icon: Icons.electrical_services_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  if (extraInfo != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      extraInfo,
                      style: AppTheme.body(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isConfigured)
                    Row(
                      children: [
                        Expanded(
                          child: _buildServerActionButton(
                            label: 'Putuskan',
                            icon: Icons.link_off_rounded,
                            onPressed: isChecking ? null : onDisconnect,
                            color: AppTheme.statusDanger,
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildServerActionButton(
                            label: isChecking ? 'Memeriksa...' : 'Tes Ulang',
                            icon: Icons.refresh_rounded,
                            onPressed: isChecking ? null : onRetest,
                            color: AppTheme.primaryGreen,
                            filled: false,
                            loading: isChecking,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildServerActionButton(
                            label: 'Hubungkan',
                            icon: Icons.save_rounded,
                            onPressed: isChecking ? null : onConnect,
                            color: AppTheme.primaryGreen,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  if (!isConfigured)
                    _buildServerActionButton(
                      label: 'Hubungkan',
                      icon: Icons.save_rounded,
                      onPressed: isChecking ? null : onConnect,
                      color: AppTheme.primaryGreen,
                      filled: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerActionButton({
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    required Color color,
    required bool filled,
    bool loading = false,
  }) {
    final textStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: filled ? FontWeight.bold : FontWeight.w600,
      letterSpacing: filled ? 0.3 : 0,
    );

    final buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryGreen,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 15),
        if ((loading || icon != null)) const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );

    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    return filled
        ? ElevatedButton(
            onPressed: onPressed,
            style: style,
            child: buttonContent,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: buttonContent,
          );
  }

  Widget _buildStatusBadge({
    required bool isChecking,
    required bool isConnected,
    required bool isConfigured,
    required String statusLabel,
  }) {
    Color color;
    String label;

    if (isChecking) {
      color = AppTheme.statusNormal;
      label = 'Memeriksa...';
    } else if (isConnected) {
      color = AppTheme.primaryGreen;
      label = 'Terhubung';
    } else if (isConfigured) {
      color = AppTheme.statusDanger;
      label = 'Terputus';
    } else {
      color = Colors.grey;
      label = 'Belum Diatur';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.body(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTheme.data(
        color: AppTheme.textPrimary(context),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTheme.body(color: Colors.grey.shade500, fontSize: 12),
        labelStyle: AppTheme.body(
          color: AppTheme.textSecondary(context),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.8,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    final bool controlEnabled =
        DesktopConfig.isConfigured && desktopSocket.isConnected.value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  if (!controlEnabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.statusNormal,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sambungkan ke server Desktop terlebih dahulu untuk mengirim perintah.',
                              style: AppTheme.body(
                                fontSize: 12,
                                color: AppTheme.statusNormal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildControlItem(
                    icon: Icons.air_rounded,
                    title: 'Aerator',
                    subtitle: 'Mengatur aerator / oksigen',
                    isOn: isAeratorOn,
                    isEnabled: controlEnabled,
                    onChanged: (v) {
                      setState(() => isAeratorOn = v);
                      _sendCommand('aerator', v);
                    },
                  ),
                  _buildDividerLine(),
                  _buildControlItem(
                    icon: Icons.water_drop_rounded,
                    title: 'Pompa Air',
                    subtitle: 'Mengatur pompa sirkulasi',
                    isOn: isPompaAirOn,
                    isEnabled: controlEnabled,
                    onChanged: (v) {
                      setState(() => isPompaAirOn = v);
                      _sendCommand('pompa_air', v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerLine() =>
      Divider(height: 16, thickness: 1, color: Theme.of(context).dividerColor);

  Widget _buildControlItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isOn,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    final Color activeColor = AppTheme.primaryGreen;
    final Color inactiveColor = AppTheme.paramTemp;
    final Color currentColor = isOn ? activeColor : inactiveColor;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: currentColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: currentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isOn,
                onChanged: isEnabled ? onChanged : null,
                activeColor: Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isEnabled
                    ? inactiveColor.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 13),
            const SizedBox(width: 4),
            Text(
              'Akuaponik Monitor v1.1',
              style: AppTheme.body(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
