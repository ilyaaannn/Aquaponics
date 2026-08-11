import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../page_AI/dashboard.dart';
import '../page_AI/history.dart';
import '../page_AI/ekosistem.dart';
import '../page_AI/setting.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  static final ValueNotifier<int?> requestedTabIndex = ValueNotifier<int?>(
    null,
  );

  static void goToTab(int index) {
    requestedTabIndex.value = index;
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    WaterQualityDashboard(),
    HistoryPage(),
    EkosistemPage(),
    SettingPage(),
  ];

  @override
  void initState() {
    super.initState();
    MainNavigation.requestedTabIndex.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    MainNavigation.requestedTabIndex.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final requested = MainNavigation.requestedTabIndex.value;
    if (requested != null && mounted) {
      setState(() => _currentIndex = requested);
      MainNavigation.requestedTabIndex.value = null;
    }
  }

  static const List<_NavSpec> _navSpecs = [
    _NavSpec(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavSpec(Icons.history_outlined, Icons.history_rounded, 'History'),
    _NavSpec(Icons.eco_outlined, Icons.eco_rounded, 'Ekosistem'),
    _NavSpec(Icons.settings_outlined, Icons.settings_rounded, 'Setting'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppTheme.inkDeep.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.unselectedItemColor,
            selectedLabelStyle: AppTheme.body(
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
            unselectedLabelStyle: AppTheme.body(
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: List.generate(_navSpecs.length, (i) {
              final spec = _navSpecs[i];
              return BottomNavigationBarItem(
                icon: Icon(spec.icon),
                activeIcon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(spec.activeIcon),
                ),
                label: spec.label,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavSpec(this.icon, this.activeIcon, this.label);
}
