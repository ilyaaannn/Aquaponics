import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../helper/app_theme.dart';
import '../helper/desktop_config.dart';
import '../model/model_desktop.dart';

class DesktopDashboardTab extends StatefulWidget {
  const DesktopDashboardTab({Key? key}) : super(key: key);

  @override
  State<DesktopDashboardTab> createState() => _DesktopDashboardTabState();
}

class _DesktopDashboardTabState extends State<DesktopDashboardTab> {
  Timer? _timer;
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    DesktopConfig.apiUrlNotifier.addListener(_onConfigChanged);
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    DesktopConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _logs = [];
      _isOnline = false;
    });
    _timer?.cancel();
    _startPolling();
  }

  void _startPolling() {
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchData());
  }

  Future<void> fetchData() async {
    if (!DesktopConfig.isConfigured) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOnline = false;
        });
      }
      return;
    }

    try {
      final uri = Uri.parse(
        '${DesktopConfig.apiUrl}/api/history',
      ).replace(queryParameters: {'limit': '25'});
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'] ?? [];
        if (mounted) {
          setState(() {
            _logs = data;
            _isLoading = false;
            _isOnline = true;
            _errorMessage = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Server error (${response.statusCode}).';
            _isLoading = false;
            _isOnline = false;
          });
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Server tidak merespons.\nPeriksa IP: ${DesktopConfig.apiUrl}';
          _isLoading = false;
          _isOnline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Koneksi gagal.\nPastikan HP dan komputer desktop berada di '
              'jaringan yang sama.\nServer: ${DesktopConfig.apiUrl}';
          _isLoading = false;
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }
    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [const SizedBox(height: 12), _buildParameterGrid()],
        ),
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
                  ? 'Server Desktop Belum Terhubung'
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
              _errorMessage.isEmpty
                  ? 'Hubungkan ke server Aplikasi Desktop melalui ikon di pojok kanan atas.'
                  : _errorMessage,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (!isNotConfigured)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  fetchData();
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
    final latest = _logs.first as Map<String, dynamic>;
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
                          '11 Parameter Sensor',
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
