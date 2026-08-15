import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helper/app_theme.dart';
import '../helper/desktop_config.dart';
import '../helper/realtime_sockets.dart';
import '../helper/navbar.dart';
import '../model/model_desktop.dart';

class DesktopDashboardTab extends StatefulWidget {
  final Function(bool)? onOnlineStatusChanged;

  const DesktopDashboardTab({Key? key, this.onOnlineStatusChanged})
    : super(key: key);

  @override
  State<DesktopDashboardTab> createState() => _DesktopDashboardTabState();
}

class _DesktopDashboardTabState extends State<DesktopDashboardTab> {
  final List<Map<String, dynamic>> _logs = [];
  static const int _maxLogs = 50;

  bool _isLoading = true;
  bool _isOnline = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    DesktopConfig.apiUrlNotifier.addListener(_onConfigChanged);
    desktopSocket.latestData.addListener(_onLiveData);
    desktopSocket.isConnected.addListener(_onSocketStatus);

    _bootstrap();
  }

  @override
  void dispose() {
    DesktopConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    desktopSocket.latestData.removeListener(_onLiveData);
    desktopSocket.isConnected.removeListener(_onSocketStatus);
    super.dispose();
  }

  void _bootstrap() {
    if (!DesktopConfig.isConfigured) {
      setState(() {
        _isLoading = false;
        _isOnline = false;
        _errorMessage =
            'Buka tab Setting dan masukkan IP server Desktop\nuntuk koneksi ke perangkat';
      });
      _notifyStatus(false);
      return;
    }

    setState(() {
      _isLoading = _logs.isEmpty;
      _errorMessage = '';
    });
    desktopSocket.connect();

    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (!desktopSocket.isConnected.value && _logs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Server tidak merespons.\nPastikan HP dan komputer desktop di jaringan yang sama.\n'
              'Server: ${DesktopConfig.apiUrl}';
        });
      }
    });
  }

  void _onConfigChanged() {
    if (!mounted) return;
    setState(() {
      _logs.clear();
      _isLoading = true;
      _errorMessage = '';
      _isOnline = false;
    });
    _notifyStatus(false);
    _bootstrap();
  }

  void _onSocketStatus() {
    if (!mounted) return;
    final connected = desktopSocket.isConnected.value;
    setState(() => _isOnline = connected);
    _notifyStatus(connected);
    if (connected) {
      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });
    }
  }

  void _onLiveData() {
    if (!mounted) return;
    final data = desktopSocket.latestData.value;
    if (data == null) return;
    setState(() {
      _logs.insert(0, data);
      if (_logs.length > _maxLogs) _logs.removeLast();
      _isLoading = false;
      _isOnline = true;
      _errorMessage = '';
    });
    _notifyStatus(true);
  }

  void _notifyStatus(bool online) {
    widget.onOnlineStatusChanged?.call(online);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty && _logs.isEmpty) {
      return _buildErrorState();
    }
    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [const SizedBox(height: 12), _buildParameterGrid()],
      ),
    );
  }

  Widget _buildErrorState() {
    final isNotConfigured = !DesktopConfig.isConfigured;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNotConfigured ? Icons.settings_ethernet : Icons.cloud_off,
              size: 56,
              color: AppTheme.aquaBlueSoft,
            ),
            const SizedBox(height: 14),
            Text(
              isNotConfigured
                  ? 'Server Desktop Belum Dikonfigurasi'
                  : 'Koneksi Gagal',
              style: AppTheme.display(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (isNotConfigured)
              ElevatedButton.icon(
                onPressed: () {
                  MainNavigation.goToTab(2);
                },
                icon: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                label: Text(
                  'Buka Setting',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _bootstrap();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off_rounded,
              size: 48,
              color: AppTheme.textSecondary(context).withOpacity(0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada data sensor',
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Data akan muncul begitu perangkat desktop mengirim pembacaan sensor.',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterGrid() {
    final latest = _logs.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.containerBg(context),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            AppTheme.currentLine(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '11 Parameter Sensor  •  Live',
                          style: AppTheme.display(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.5,
                    children: kDesktopParams
                        .map(
                          (p) => _paramTile(p, numFromLog(latest, p.jsonKey)),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paramTile(DesktopParam p, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.color.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: p.color.withOpacity(0.35), width: 1.2),
            ),
            child: Icon(p.icon, color: p.color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.format(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.data(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
