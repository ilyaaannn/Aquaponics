// dekstop_home.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helper/app_theme.dart';
import '../helper/desktop_config.dart';
import '../helper/header.dart';
import 'dekstop_dashboard.dart';
import 'dekstop_history.dart';

class DesktopDataPage extends StatefulWidget {
  const DesktopDataPage({Key? key}) : super(key: key);

  @override
  State<DesktopDataPage> createState() => _DesktopDataPageState();
}

class _DesktopDataPageState extends State<DesktopDataPage> {
  int _tabIndex = 0;
  bool _isEditingConnection = false;
  bool _isSaving = false;

  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  final List<TabItem> _tabs = const [
    TabItem(
      label: 'Dashboard',
      icon: Icons.speed_rounded,
      page: DesktopDashboardTab(),
    ),
    TabItem(
      label: 'Riwayat',
      icon: Icons.history_rounded,
      page: DesktopHistoryTab(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ipController.text = DesktopConfig.currentIp;
    _portController.text = DesktopConfig.currentPort.toString();
    DesktopConfig.apiUrlNotifier.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    DesktopConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    setState(() {
      _ipController.text = DesktopConfig.currentIp;
      _portController.text = DesktopConfig.currentPort.toString();
    });
  }

  Future<void> _saveConnection() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;

    if (ip.isEmpty) {
      _showSnack('Masukkan IP address server desktop terlebih dahulu.');
      return;
    }
    if (!DesktopConfig.isValidIp(ip)) {
      _showSnack('Format IP tidak valid. Contoh: 192.168.1.10');
      return;
    }

    setState(() => _isSaving = true);
    await DesktopConfig.setServerIp(ip, port: port);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditingConnection = false;
    });
    _showSnack('Terhubung ke ${DesktopConfig.apiUrl}', success: true);
  }

  Future<void> _disconnect() async {
    await DesktopConfig.resetConfig();
    if (!mounted) return;
    setState(() {
      _ipController.clear();
      _portController.text = '8080';
    });
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
        ),
        backgroundColor: success
            ? AppTheme.primaryGreen
            : AppTheme.statusDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = DesktopConfig.isConfigured;
    final showConnectionForm = _isEditingConnection || !configured;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppTheme.scaffoldBg(context),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildHeader(configured),
            ),
            if (showConnectionForm)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: _buildConnectionCard(configured),
              ),
            if (configured && !showConnectionForm) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabSwitcher(
                  currentIndex: _tabIndex,
                  onTabChanged: (index) {
                    setState(() {
                      _tabIndex = index;
                    });
                  },
                  tabs: _tabs,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: _tabs.map((tab) => tab.page).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool configured) {
    return CustomAppHeader(
      title: 'DESKTOP AKUAPONIK',
      subtitle: configured ? DesktopConfig.currentIp : 'Belum terhubung',
      statusColor: configured ? AppTheme.secondaryGreen : Colors.redAccent,
      showStatus: true,
      trailing: GestureDetector(
        onTap: () =>
            setState(() => _isEditingConnection = !_isEditingConnection),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            configured ? Icons.settings_ethernet_rounded : Icons.link_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(bool configured) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koneksi Server Desktop',
                    style: AppTheme.body(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masukkan IP komputer yang menjalankan Aplikasi Desktop '
                    '(pastikan HP & komputer di jaringan yang sama).',
                    style: AppTheme.body(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _ipController,
                    label: 'IP Address / Domain',
                    hint: '192.168.1.10',
                    icon: Icons.dns_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _portController,
                    label: 'Port',
                    hint: '8080',
                    icon: Icons.electrical_services_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (configured) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _disconnect,
                            icon: const Icon(Icons.link_off_rounded, size: 15),
                            label: const Text('Putuskan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.statusDanger,
                              side: BorderSide(
                                color: AppTheme.statusDanger.withOpacity(0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _isEditingConnection = false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              side: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveConnection,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                          label: Text(
                            'Hubungkan',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
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
}
