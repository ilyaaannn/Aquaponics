// navbar.dart
import 'package:flutter/material.dart';
import '../helper/app_theme.dart';
import '../page_AI/AI_home.dart';
import 'setting.dart';
import '../page_dekstop/dekstop_home.dart';

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
    AIHomePage(),
    DesktopDataPage(),
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
    _NavSpec(
      Icons.psychology_outlined,
      Icons.psychology_rounded,
      'SmartFarm',
      0,
    ),
    _NavSpec(Icons.computer_outlined, Icons.computer_rounded, 'Desktop', 1),
    _NavSpec(Icons.settings_outlined, Icons.settings_rounded, 'Setting', 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navSpecs.length, (index) {
                final spec = _navSpecs[index];
                final isSelected = _currentIndex == spec.pageIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = spec.pageIndex);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isSelected ? spec.activeIcon : spec.icon,
                              size: 28,
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).bottomNavigationBarTheme.selectedItemColor
                                  : Theme.of(context)
                                        .bottomNavigationBarTheme
                                        .unselectedItemColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spec.label,
                            style: isSelected
                                ? AppTheme.body(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                    color: Theme.of(context)
                                        .bottomNavigationBarTheme
                                        .selectedItemColor,
                                  )
                                : AppTheme.body(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.5,
                                    color: Theme.of(context)
                                        .bottomNavigationBarTheme
                                        .unselectedItemColor,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
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
  final int pageIndex;
  const _NavSpec(this.icon, this.activeIcon, this.label, this.pageIndex);
}
