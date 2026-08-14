// header.dart
import 'package:flutter/material.dart';
import '../helper/app_theme.dart';

class CustomAppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color statusColor;
  final Widget? trailing;
  final bool showStatus;

  const CustomAppHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.statusColor = AppTheme.secondaryGreen,
    this.trailing,
    this.showStatus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(gradient: AppTheme.panelGradient),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/logo_apps.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.display(
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (showStatus && subtitle != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subtitle!,
                            style: AppTheme.data(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class TabSwitcher extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<TabItem> tabs;

  const TabSwitcher({
    Key? key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.tabs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.containerBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.rowShadow],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          return Expanded(
            child: _TabButton(
              label: tabs[index].label,
              icon: tabs[index].icon,
              isSelected: currentIndex == index,
              onTap: () => onTabChanged(index),
            ),
          );
        }),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.body(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabItem {
  final String label;
  final IconData icon;
  final Widget page;

  const TabItem({required this.label, required this.icon, required this.page});
}
