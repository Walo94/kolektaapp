import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/theme_provider.dart';
import 'feactures/modules/batchs/screens/create_batch_screen.dart';
import 'feactures/modules/batchs/screens/batch_detail_screen.dart';
import 'feactures/admin/providers/auth_provider.dart';
import 'feactures/admin/screens/login_screen.dart';
import 'feactures/admin/screens/forgot_password_screen.dart';
import 'feactures/admin/screens/register_screen.dart';
import 'shared/widgets/main_shell.dart';
import 'feactures/modules/catalogs/screens/catalogs_home_screen.dart';
import 'feactures/modules/catalogs/screens/create_sale_screen.dart';
import 'feactures/modules/catalogs/screens/sale_detail_screen.dart';
import 'feactures/modules/catalogs/screens/products_home_screen.dart';
import 'feactures/modules/catalogs/screens/product_form_screen.dart';
import 'feactures/modules/batchs/screens/batchs_home_screen.dart';
import 'feactures/home/screens/home_screen.dart';
import 'feactures/activity/screens/activity_screen.dart';
import 'feactures/profile/screens/security_screen.dart';
import 'feactures/modules/giveaways/screens/giveaways_home_screen.dart';
import 'feactures/modules/giveaways/screens/create_giveaway_screen.dart';
import 'feactures/modules/giveaways/screens/giveaway_detail_screen.dart';

import 'feactures/profile/screens/profile_screen.dart';
import 'feactures/profile/screens/personal_info_screen.dart';
import 'feactures/profile/screens/help_screen.dart';
import 'feactures/profile/screens/privacy_screen.dart';
import 'feactures/profile/screens/conditions_screen.dart';
import 'feactures/profile/screens/notifications_screen.dart';
import 'feactures/profile/screens/notification_preferences_screen.dart';
import 'feactures/profile/services/push_notification_handler.dart';
// ──────────────────────────────────────────────────────────────────────────────

CustomTransitionPage<void> _slideUpPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fadeOut = Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

      return FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(position: slideIn, child: child));
    },
  );
}

class KolektaApp extends StatefulWidget {
  const KolektaApp({super.key});

  @override
  State<KolektaApp> createState() => _KolektaAppState();
}

class _KolektaAppState extends State<KolektaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();

    _router = GoRouter(
      initialLocation: AppRoutes.login,
      // ── NUEVO: navigatorKey para deep-link desde push ─────────────────────
      navigatorKey: PushNotificationHandler.navigatorKey,
      // ─────────────────────────────────────────────────────────────────────
      refreshListenable: auth,
      redirect: (context, state) {
        final isAuth = auth.isAuthenticated;
        final loc = state.matchedLocation;

        final isPublicRoute = loc == AppRoutes.login ||
            loc == AppRoutes.register ||
            loc == AppRoutes.forgotPassword;

        if (!isAuth && !isPublicRoute) return AppRoutes.login;

        if (isAuth && (loc == AppRoutes.login || loc == AppRoutes.register)) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        // ── Auth ──────────────────────────────────────────
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => LoginScreen(
            onLogin: () => context.go(AppRoutes.home),
            onRegister: () => context.push(AppRoutes.register),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => RegisterScreen(
            onRegister: () => context.go(AppRoutes.login),
            onLogin: () => context.pop(),
          ),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (context, state) =>
              ForgotPasswordScreen(onBack: () => context.pop()),
        ),

        // ── Shell con bottom nav ───────────────────────────
        ShellRoute(
          builder: (context, state, child) => MainShell(
            onLogout: () => context.go(AppRoutes.login),
            child: child,
          ),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) =>
                  HomeScreen(onNavigate: (route) => context.push(route)),
            ),
            GoRoute(
              path: AppRoutes.activity,
              builder: (context, state) => const ActivityScreen(),
            ),
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: AppRoutes.security,
              builder: (context, state) => const SecurityScreen(),
            ),
            GoRoute(
              path: AppRoutes.personalInfo,
              builder: (context, state) => const PersonalInfoScreen(),
            ),
            GoRoute(
              path: AppRoutes.help,
              builder: (context, state) => const HelpScreen(),
            ),
            GoRoute(
              path: AppRoutes.privacy,
              builder: (context, state) => const PrivacyScreen(),
            ),
            GoRoute(
              path: AppRoutes.conditions,
              builder: (context, state) => const ConditionsScreen(),
            ),

            // ── Notificaciones ─────────────────────────────────────
            GoRoute(
              path: AppRoutes.notifications,
              builder: (context, state) => const NotificationsScreen(),
            ),
            GoRoute(
              path: AppRoutes.notificationPreferences,
              builder: (context, state) =>
                  const NotificationPreferencesScreen(),
            ),
            // ─────────────────────────────────────────────────────────────

            // ── Tandas ────────────────────────────────────────
            GoRoute(
              path: AppRoutes.batchs,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const BatchsHomeScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.createBatch,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const CreateBatchScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.batchDetail,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return BatchDetailScreen(batchId: id);
              },
            ),

            // ── Catálogos ──────────────────────────────────────
            GoRoute(
              path: AppRoutes.catalogs,
              builder: (context, state) => const CatalogsHomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.createSale,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const CreateSaleScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.saleDetail,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return SaleDetailScreen(saleId: id);
              },
            ),
            GoRoute(
              path: AppRoutes.products,
              builder: (context, state) => const ProductsHomeScreen(),
            ),

            GoRoute(
              path: AppRoutes.productForm,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const ProductFormScreen(),
              ),
            ),

            // ── Rifas ──────────────────────────────────────────
            GoRoute(
              path: AppRoutes.giveaways,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const GiveawaysHomeScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.createGiveaway,
              pageBuilder: (context, state) => _slideUpPage(
                context: context,
                state: state,
                child: const CreateGiveawayScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.giveawayDetail,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return GiveawayDetailScreen(giveawayId: id);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'Kolekta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
    );
  }
}
