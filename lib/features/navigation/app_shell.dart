import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/ascend_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  static const _destinations = <_Destination>[
    _Destination(label: 'Coach', icon: Icons.auto_awesome_outlined, route: '/coach'),
    _Destination(label: 'Scan', icon: Icons.face_retouching_natural, route: '/scan'),
    _Destination(label: 'Plan', icon: Icons.calendar_month_outlined, route: '/plan'),
    _Destination(label: 'Progress', icon: Icons.insights_outlined, route: '/progress'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.route == currentPath,
    );

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
        onDestinationSelected: (index) {
          context.go(_destinations[index].route);
        },
      ),
      backgroundColor: AscendColors.background,
    );
  }
}

class _Destination {
  const _Destination({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}
