import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'config.dart';
import 'header.dart';
import 'guide.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  bool isAeratorOn = false;
  bool isPompaAirOn = false;
  String connectionStatus = 'Belum Terkonfigurasi';
  bool isConnected = false;
  bool isChecking = false;
  String serverVersion = '';
  String firebaseStatus = '';
  int fcmTokenCount = 0;

  @override
  void initState() {
    super.initState();
    ipController.text = AppConfig.currentIp;
    portController.text = AppConfig.currentPort.toString();
    AppConfig.apiUrlNotifier.addListener(_onApiUrlChanged);
    if (AppConfig.isConfigured) {
      _checkConnection(showDialog: false);
    }
  }

  void _onApiUrlChanged() {
    if (!mounted) return;
    final newIp = AppConfig.currentIp;
    final newPort = AppConfig.currentPort.toString();
    if (ipController.text != newIp) ipController.text = newIp;
    if (portController.text != newPort) portController.text = newPort;

    if (AppConfig.isConfigured) {
      _checkConnection(showDialog: false);
    } else {
      setState(() {
        isConnected = false;
        connectionStatus = 'Belum Terkonfigurasi';
        serverVersion = '';
        firebaseStatus = '';
        fcmTokenCount = 0;
      });
    }
  }

  @override
  void dispose() {
    AppConfig.apiUrlNotifier.removeListener(_onApiUrlChanged);
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection({bool showDialog = true}) async {
    if (!AppConfig.isConfigured) {
      setState(() {
        connectionStatus = 'URL belum dikonfigurasi';
        isConnected = false;
      });
      return;
    }

    setState(() {
      isChecking = true;
      connectionStatus = 'Memeriksa...';
    });

    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiUrl}/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isConnected = true;
          connectionStatus = 'Terhubung';
          serverVersion = data['model'] ?? '';
          firebaseStatus = data['firebase'] ?? '';
          fcmTokenCount = data['fcm_tokens_total'] ?? 0;
        });

        await _fetchControlStatus();

        if (showDialog)
          _showSnack(
            '✓ Berhasil terhubung ke ${AppConfig.apiUrl}',
            success: true,
          );
      } else {
        setState(() {
          isConnected = false;
          connectionStatus = 'Server error ${response.statusCode}';
        });
        if (showDialog)
          _showSnack(
            'Server merespons dengan kode ${response.statusCode}',
            success: false,
          );
      }
    } catch (e) {
      setState(() {
        isConnected = false;
        connectionStatus = 'Tidak dapat terhubung';
      });
      if (showDialog)
        _showSnack(
          'Gagal terhubung: periksa IP, port, dan jaringan.',
          success: false,
        );
    } finally {
      setState(() => isChecking = false);
    }
  }

  Future<void> _connectToServer() async {
    final ip = ipController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 5000;

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
      isConnected = false;
      connectionStatus = 'Menghubungkan...';
    });

    await _checkConnection(showDialog: true);
  }

  Future<void> _disconnectFromServer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Putuskan Koneksi?',
          style: AppTheme.display(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Konfigurasi server (IP & port) akan dihapus dan aplikasi akan terputus dari Raspberry Pi.',
          style: GoogleFonts.inter(fontSize: 12),
        ),
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

    if (confirm != true) return;
    await AppConfig.resetConfig();

    setState(() {
      ipController.clear();
      portController.clear();
      isConnected = false;
      connectionStatus = 'Belum Terkonfigurasi';
      serverVersion = '';
      firebaseStatus = '';
      fcmTokenCount = 0;
    });

    _showSnack('Koneksi server telah diputuskan.', success: false);
  }

  Future<void> _sendCommand(String device, bool state) async {
    // Cek koneksi sebelum mengirim perintah
    if (!AppConfig.isConfigured || !isConnected) {
      _showSnack(
        'Tidak terhubung ke server. Hubungkan terlebih dahulu.',
        success: false,
      );
      await _fetchControlStatus();
      return;
    }

    // Konversi boolean ke int (1/0) sebelum dikirim
    final int stateInt = state ? 1 : 0;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'device': device, 'state': stateInt}),
      );

      if (response.statusCode != 200) {
        _showSnack('Gagal mengubah status $device', success: false);
        await _fetchControlStatus();
      }
    } catch (e) {
      debugPrint('[Setting] Gagal mengirim perintah $device: $e');
      _showSnack(
        'Gagal mengirim perintah: periksa koneksi server',
        success: false,
      );
      await _fetchControlStatus();
    }
  }

  Future<void> _fetchControlStatus() async {
    if (!isConnected) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/api/control/status'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> status = json.decode(response.body);
        setState(() {
          isAeratorOn = status['aerator'] ?? false;
          isPompaAirOn = status['pompa_air'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('[Setting] Gagal mengambil status kontrol: $e');
    }
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
            size: 18,
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
                    _buildSectionLabel('🌐', 'KONEKSI SERVER'),
                    const SizedBox(height: 10),
                    _buildServerCard(),
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

  Widget _buildServerCard() {
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
                      Text(
                        'Status Koneksi',
                        style: AppTheme.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: ipController,
                    hint: '',
                    label: 'IP Address / Domain',
                    icon: Icons.dns_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: portController,
                    hint: '5000',
                    label: 'Port',
                    icon: Icons.electrical_services_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  if (AppConfig.isConfigured)
                    Row(
                      children: [
                        Expanded(
                          child: _buildServerActionButton(
                            label: 'Putuskan',
                            icon: Icons.link_off_rounded,
                            onPressed: isChecking
                                ? null
                                : _disconnectFromServer,
                            color: AppTheme.statusDanger,
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildServerActionButton(
                            label: isChecking ? 'Memeriksa...' : 'Tes Ulang',
                            icon: Icons.refresh_rounded,
                            onPressed: isChecking
                                ? null
                                : () => _checkConnection(showDialog: true),
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
                            onPressed: isChecking ? null : _connectToServer,
                            color: AppTheme.primaryGreen,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  if (!AppConfig.isConfigured)
                    _buildServerActionButton(
                      label: 'Hubungkan',
                      icon: Icons.save_rounded,
                      onPressed: isChecking ? null : _connectToServer,
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

  Widget _buildStatusBadge() {
    Color color;
    String label;

    if (isChecking) {
      color = AppTheme.statusNormal;
      label = 'Memeriksa...';
    } else if (isConnected) {
      color = AppTheme.primaryGreen;
      label = 'Terhubung';
    } else if (AppConfig.isConfigured) {
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
        fontSize: 13,
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
                  if (!isConnected)
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
                              'Sambungkan ke server terlebih dahulu untuk mengirim perintah.',
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
                    isEnabled: isConnected,
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
                    isEnabled: isConnected,
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
