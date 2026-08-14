import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../helper/config.dart';
import '../helper/header.dart';
import 'AI_dashboard.dart';
import 'AI_ekosistem.dart';
import 'AI_history.dart';

class AIHomePage extends StatefulWidget {
  const AIHomePage({Key? key}) : super(key: key);

  @override
  State<AIHomePage> createState() => _AIHomePageState();
}

class _AIHomePageState extends State<AIHomePage> {
  int _currentTabIndex = 0;
  bool _isOnline = false;
  String _statusText = 'Offline';

  final List<TabItem> _tabs = const [
    TabItem(
      label: 'Dashboard',
      icon: Icons.speed_rounded,
      page: WaterQualityDashboard(),
    ),
    TabItem(label: 'Riwayat', icon: Icons.history_rounded, page: HistoryPage()),
    TabItem(label: 'Ekosistem', icon: Icons.eco_rounded, page: EkosistemPage()),
  ];

  late List<TabItem> _tabsWithCallback;

  @override
  void initState() {
    super.initState();
    _tabsWithCallback = [
      TabItem(
        label: 'Dashboard',
        icon: Icons.speed_rounded,
        page: WaterQualityDashboard(
          onOnlineStatusChanged: _handleOnlineStatusChanged,
        ),
      ),
      const TabItem(
        label: 'Ekosistem',
        icon: Icons.eco_rounded,
        page: EkosistemPage(),
      ),
      const TabItem(
        label: 'Riwayat',
        icon: Icons.history_rounded,
        page: HistoryPage(),
      ),
    ];

    // Initial status check
    _updateStatusFromConfig();
    AppConfig.apiUrlNotifier.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    AppConfig.apiUrlNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    _updateStatusFromConfig();
  }

  void _updateStatusFromConfig() {
    setState(() {
      if (!AppConfig.isConfigured) {
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
          ? (AppConfig.isConfigured ? AppConfig.currentIp : 'Online')
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
                currentIndex: _currentTabIndex,
                onTabChanged: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                tabs: _tabsWithCallback,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: _tabsWithCallback.map((tab) => tab.page).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return CustomAppHeader(
      title: 'AI AKUAPONIK',
      subtitle: _statusText,
      statusColor: _isOnline ? AppTheme.secondaryGreen : Colors.redAccent,
      showStatus: true, // ← UBAH KE TRUE!
    );
  }
}
