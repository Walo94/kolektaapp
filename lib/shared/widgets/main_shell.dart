import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.child,
    this.onLogout,
  });

  final Widget child;
  final VoidCallback? onLogout;

  // Mapeo de índice → ruta
  static const _routes = [
    AppRoutes.home,
    AppRoutes.activity,
    AppRoutes.profile,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.activity)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: KolektaBottomNavBar(
        currentIndex: _currentIndex(context),
        onTap: (i) => context.go(_routes[i]),
      ),
    );
  }
}