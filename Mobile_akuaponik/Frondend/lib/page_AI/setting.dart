import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../helper/app_theme.dart';
import '../helper/config.dart';
import '../helper/header.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController();

  // State kontrol perangkat
  bool isAeratorOn = false;
  bool isPompaAirOn = false;
  bool isRandenAirOn = false;

  // Status koneksi
  String connectionStatus = 'Belum Terkonfigurasi';
  bool isConnected = false;
  bool isChecking = false;

  // Info server
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Putuskan Koneksi?',
          style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Konfigurasi server (IP & port) akan dihapus dan aplikasi akan terputus dari Raspberry Pi.',
          style: GoogleFonts.inter(fontSize: 13),
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
    if (!AppConfig.isConfigured) {
      _showSnack('Konfigurasi server terlebih dahulu.', success: false);
      return;
    }

    // Konversi boolean ke int (1/0) sebelum dikirim
    final int stateInt = state ? 1 : 0;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device': device,
          'state': stateInt,
        }), // Kirim 1 atau 0
      );

      if (response.statusCode != 200) {
        _showSnack('Gagal mengubah status $device', success: false);
      }
    } catch (e) {
      debugPrint('[Setting] Gagal mengirim perintah $device: $e');
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
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: success
            ? AppTheme.primaryGreen
            : AppTheme.statusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHeader() {
    return CustomAppHeader(
      title: 'PENGATURAN SISTEM',
      showStatus: false,
      trailing: IconButton(
        onPressed: _showHelpSheet,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          padding: const EdgeInsets.all(8),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _buildHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                child: Column(
                  children: [
                    _buildSectionLabel('🌐', 'KONEKSI SERVER'),
                    const SizedBox(height: 10),
                    _buildServerCard(),
                    const SizedBox(height: 16),
                    _buildSectionLabel('⚙️', 'KONTROL MANUAL'),
                    const SizedBox(height: 10),
                    _buildControlCard(),
                    const SizedBox(height: 24),
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

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final item in _helpItems) {
          final sec = item['section'] as String;
          grouped.putIfAbsent(sec, () => []).add(item);
        }
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.60,
              minChildSize: 0.4,
              maxChildSize: 0.90,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.containerBg(context),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary(
                              context,
                            ).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Panduan Penggunaan Aplikasi',
                            style: AppTheme.display(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...grouped.entries.map(
                        (entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: AppTheme.display(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...entry.value.map(
                              (item) => _buildHelpItem(
                                icon: item['icon'] as IconData,
                                color: item['color'] as Color,
                                title: item['title'] as String,
                                desc: item['desc'] as String,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static const List<Map<String, dynamic>> _helpItems = [
    // ===================== DASHBOARD =====================
    {
      'section': 'Dashboard',
      'icon': Icons.dashboard_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Monitoring Real-Time',
      'desc':
          'Tampilan utama Menunjukkan status kualitas air terkini (Ideal / Normal / Bahaya) '
          'berdasarkan sensor pH, Suhu, TDS dan DO yang diperbarui setiap 5 detik secara otomatis '
          'sesuai dengan preset ekosistem yang aktif.',
    },
    {
      'section': 'Dashboard',
      'icon': Icons.show_chart_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Grafik Parameter',
      'desc':
          'untuk melihat tren historis pH, Suhu, TDS dan DO '
          'dalam bentuk line chart dari waktu ke waktu.',
    },
    {
      'section': 'Dashboard',
      'icon': Icons.warning_amber_rounded,
      'color': AppTheme.statusWarning,
      'title': 'Indikator Status Bahaya',
      'desc':
          'kartu status akan berubah warna dan menampilkan label "Bahaya" bila parameter keluar dari rentang ideal. '
          'cek Notifikasi di halaman Riwayat untuk melihat detail parameter yang bermasalah.',
    },

    // ===================== RIWAYAT =====================
    {
      'section': 'Riwayat',
      'icon': Icons.notifications_active_rounded,
      'color': AppTheme.statusDanger,
      'title': 'Tab Notifikasi',
      'desc':
          'Menyimpan daftar peringatan otomatis saat parameter berada di batas bahaya. '
          'Setiap catatan berisi informasi detail parameter yang bermasalah dan notifikasi dihapus otomatis setelah 7 hari',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.sensors_rounded,
      'color': AppTheme.tdsColor,
      'title': 'Tab Data Sensor',
      'desc':
          'Tabel lengkap semua pembacaan sensor (waktu, pH, Suhu, TDS, DO serta status). '
          'Berdasarkan data real-time dari Redis (cache 1 jam) serta dukungan unduh CSV untuk laporan lengkap.',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.calendar_today_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Filter Tanggal',
      'desc':
          'Ketuk tombol "Filter" untuk menyaring data berdasarkan tanggal tertentu, '
          'memudahkan pengecekan riwayat pada hari spesifik tanpa harus menggulir seluruh data. ',
    },
    {
      'section': 'Riwayat',
      'icon': Icons.download_rounded,
      'color': AppTheme.doColor,
      'title': 'Unduh CSV (Data Lengkap)',
      'desc':
          'Di tab "Data Sensor", ketuk tombol ↓ (pojok kanan bawah) untuk mengunduh '
          'seluruh riwayat sensor dari database. File CSV dapat dibuka di Excel / Google Sheets '
          'untuk analisis lebih lanjut.',
    },

    // ===================== EKOSISTEM =====================
    {
      'section': 'Ekosistem',
      'icon': Icons.eco_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Konfigurasi Ekosistem',
      'desc':
          'pilih preset ekosistem yang sesuai dengan jenis ikan dan tanaman pada sistem akuaponik Anda. '
          'Setiap preset menampilkan rentang ideal untuk pH, Suhu, TDS dan DO yang akan digunakan sebagai acuan status kualitas air di Dashboard.',
    },
    {
      'section': 'Ekosistem',
      'icon': Icons.tune_rounded,
      'color': AppTheme.tdsColor,
      'title': 'Tabel Batas Parameter Ideal',
      'desc':
          'Menampilkan rentang ideal gabungan untuk pH, Suhu, TDS dan DO berdasarkan preset ekosistem yang aktif',
    },

    // ===================== PENGATURAN =====================
    {
      'section': 'Pengaturan',
      'icon': Icons.wifi_rounded,
      'color': AppTheme.primaryGreen,
      'title': 'Konfigurasi Server',
      'desc':
          'Masukkan IP address dan port Raspberry Pi, lalu ketuk "Simpan & Hubungkan". '
          'Pastikan ponsel dan Raspberry Pi berada di jaringan yang sama. '
          'Status koneksi akan ditampilkan setelah aplikasi berhasil terhubung ke server.',
    },
    {
      'section': 'Pengaturan',
      'icon': Icons.air_rounded,
      'color': Color(0xFF3B82F6),
      'title': 'Kontrol Manual Perangkat',
      'desc':
          'Nyalakan / matikan Kontrol Aerator, Pompa Air, dan Randen Air langsung dari aplikasi. '
          'Perangkat harus terhubung ke server terlebih dahulu sebelum mengirim perintah dan '
          'setiap perubahan status akan langsung tercermin pada tampilan kontrol.',
    },
  ];

  Widget _buildHelpItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.body(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ).copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(color: Theme.of(context).dividerColor, thickness: 1.2),
        ),
      ],
    );
  }

  Widget _buildServerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status Koneksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: ipController,
                    hint: '',
                    label: 'IP Address / Domain',
                    icon: Icons.dns_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: portController,
                    hint: '5000',
                    label: 'Port',
                    icon: Icons.electrical_services_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  if (AppConfig.isConfigured)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isChecking
                                ? null
                                : _disconnectFromServer,
                            icon: const Icon(Icons.link_off_rounded, size: 16),
                            label: Text(
                              'Putuskan',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.statusDanger,
                              side: const BorderSide(
                                color: AppTheme.statusDanger,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isChecking
                                ? null
                                : () => _checkConnection(showDialog: true),
                            icon: isChecking
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              isChecking ? 'Memeriksa...' : 'Tes Ulang',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(
                                color: AppTheme.primaryGreen,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (AppConfig.isConfigured) const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isChecking ? null : _connectToServer,
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: Text(
                        'Simpan & Hubungkan',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
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
      style: TextStyle(
        color: AppTheme.textPrimary(context),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        labelStyle: TextStyle(
          color: AppTheme.textSecondary(context),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.8,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (!isConnected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.statusNormal,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
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
                    onChanged: (v) {
                      setState(() => isPompaAirOn = v);
                      _sendCommand('pompa_air', v);
                    },
                  ),
                  _buildDividerLine(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerLine() =>
      Divider(height: 20, thickness: 1, color: Theme.of(context).dividerColor);

  Widget _buildControlItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isOn,
    required ValueChanged<bool> onChanged,
  }) {
    final Color activeColor = AppTheme.primaryGreen;
    final Color inactiveColor = AppTheme.paramTemp;
    final Color currentColor = isOn ? activeColor : inactiveColor;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: currentColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: currentColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: currentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  color: currentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: isOn,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: inactiveColor.withOpacity(0.6),
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 14),
            const SizedBox(width: 6),
            Text(
              'Akuaponik Monitor v1.0',
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
