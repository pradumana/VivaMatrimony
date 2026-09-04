import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShellScreen({super.key, required this.navigationShell});

  void _onTabTap(int index) {
    // goBranch keeps the branch's navigation stack alive;
    // initialLocation: true re-roots the branch if tapping the active tab.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _VivaBottomNav(
        selectedIndex: navigationShell.currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

class _VivaBottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _VivaBottomNav(
      {required this.selectedIndex, required this.onTap});

  static const _items = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    _NavItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        label: 'Search'),
    _NavItem(
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
        label: 'Interests'),
    _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Connect'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.navBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: List.generate(
              _items.length,
              (i) => Expanded(
                child: _NavTile(
                  item: _items[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile(
      {required this.item,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 22,
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w400,
              color:
                  isSelected ? AppTheme.primary : AppTheme.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
