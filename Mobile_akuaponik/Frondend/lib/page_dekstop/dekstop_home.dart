import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../helper/desktop_config.dart';
import '../helper/realtime_sockets.dart';
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
  bool _isOnline = false;
  String _statusText = 'Offline';

  late final List<TabItem> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      TabItem(
        label: 'Dashboard',
        icon: Icons.speed_rounded,
        page: DesktopDashboardTab(
          onOnlineStatusChanged: _handleOnlineStatusChanged,
        ),
      ),
      const TabItem(
        label: 'Riwayat',
        icon: Icons.history_rounded,
        page: DesktopHistoryTab(),
      ),
    ];

    _updateStatusFromConfig();
    DesktopConfig.apiUrlNotifier.addListener(_onConfigChanged);
    // Sambungkan stream real-time (2 detik) begitu halaman ini dibuka
    if (DesktopConfig.isConfigured) {
      desktopSocket.connect();
    }
  }

  @override
  void dispose() {
    DesktopConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    _updateStatusFromConfig();
    if (DesktopConfig.isConfigured) {
      desktopSocket.connect();
    }
  }

  void _updateStatusFromConfig() {
    setState(() {
      if (!DesktopConfig.isConfigured) {
        _isOnline = false;
        _statusText = 'Belum terkonfigurasi';
      } else {
        _isOnline = false;
        _statusText = 'Menghubungkan...';
      }
    });
  }

  void _handleOnlineStatusChanged(bool isOnline) {
    if (!mounted) return;
    setState(() {
      _isOnline = isOnline;
      _statusText = isOnline
          ? (DesktopConfig.isConfigured ? DesktopConfig.currentIp : 'Online')
          : 'Offline';
    });
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return CustomAppHeader(
      title: 'DESKTOP AKUAPONIK',
      subtitle: _statusText,
      statusColor: _isOnline ? AppTheme.secondaryGreen : Colors.redAccent,
      showStatus: true,
    );
  }
}
