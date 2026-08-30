import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';

class MainShellScreen extends StatelessWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});

  static const _routes = [
    AppRoutes.home,
    AppRoutes.search,
    AppRoutes.interests,
    AppRoutes.connections,
    AppRoutes.myProfile,
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _routes.indexOf(location);
    return idx < 0 ? 0 : idx;
  }

  void _onTabTap(BuildContext context, int index) =>
      context.go(_routes[index]);

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: _VivaBottomNav(
        selectedIndex: selectedIndex,
        onTap: (i) => _onTabTap(context, i),
      ),
    );
  }
}

class _VivaBottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _VivaBottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Search', index: 1, selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.favorite_border, activeIcon: Icons.favorite, label: 'Interests', index: 2, selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Connections', index: 3, selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 4, selectedIndex: selectedIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int selectedIndex;
  final void Function(int) onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.selectedIndex, required this.onTap});

  bool get isSelected => index == selectedIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon,
                size: 22, color: isSelected ? AppTheme.primary : AppTheme.textTertiary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
            )),
          ],
        ),
      ),
    );
  }
}
