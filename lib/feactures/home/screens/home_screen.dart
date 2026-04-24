import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../../core/utils/theme_provider.dart';
import '../../admin/providers/auth_provider.dart';
import '../../modules/providers/batch_provider.dart';
import '../../modules/providers/catalog_provider.dart';
import '../../modules/providers/giveaway_provider.dart';
import '../../profile/providers/notification_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigate});

  final void Function(String route)? onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    await Future.wait([
      context.read<BatchProvider>().loadActiveBatchsCount(token),
      context.read<CatalogProvider>().loadSales(token, silent: true),
      context.read<GiveawayProvider>().loadOpenCount(token),
      context.read<NotificationProvider>().refreshUnreadCount(token),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    final activeBatchsCount = context.watch<BatchProvider>().activeBatchsCount;
    final pendingCount = context.watch<CatalogProvider>().pendingCount;
    final openGiveawayCount = context.watch<GiveawayProvider>().openCount;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadStats,
          // ── CustomScrollView permite mezclar slivers normales
          //    con un SliverPersistentHeader (sticky) ──────────
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Header con saludo — hace scroll y desaparece ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const _HomeHeader(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── 2. "Acciones rápidas" — se queda fija al llegar al top ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _QuickActionsHeaderDelegate(
                  backgroundColor: c.background,
                  onCreatePressed: () => _showCreateSheet(context),
                  onDonatePressed: () => _showDonateDialog(context),
                ),
              ),

              // ── 3. Resto del contenido — pasa por debajo del sticky ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 32),
                    Text(
                      'Tus herramientas',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _ToolCard(
                      iconPath: 'assets/images/batch.png',
                      title: 'Tandas',
                      subtitle:
                          'Gestiona turnos y aportaciones grupales con facilidad',
                      badgeText: _activeBatchBadge(activeBatchsCount),
                      badgeColor: AppColors.primaryLight,
                      buttonLabel: 'Gestionar',
                      buttonColor: AppColors.primary,
                      onTap: () => widget.onNavigate?.call(AppRoutes.batchs),
                    ),
                    const SizedBox(height: 12),
                    _ToolCard(
                      iconPath: 'assets/images/catalog.png',
                      title: 'Catálogo',
                      subtitle: 'Controla pedidos grupales y pagos pendientes',
                      badgeText: _pendingCatalogBadge(pendingCount),
                      badgeColor: AppColors.green,
                      buttonLabel: 'Gestionar',
                      buttonColor: AppColors.green,
                      onTap: () => widget.onNavigate?.call(AppRoutes.catalogs),
                    ),
                    const SizedBox(height: 12),
                    _ToolCard(
                      iconPath: 'assets/images/giveaway.png',
                      title: 'Rifas',
                      subtitle:
                          'Administra números, sorteos y ganadores fácilmente',
                      badgeText: _openGiveawayBadge(openGiveawayCount),
                      badgeColor: AppColors.pink,
                      buttonLabel: 'Gestionar',
                      buttonColor: AppColors.pink,
                      onTap: () => widget.onNavigate?.call(AppRoutes.giveaways),
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Badge helpers ──────────────────────────────────────────────────────────
  String _activeBatchBadge(int count) {
    if (count == 0) return 'Sin tandas activas';
    if (count == 1) return '1 activa';
    return '$count activas';
  }

  String _pendingCatalogBadge(int count) {
    if (count == 0) return 'Sin pedidos pendientes';
    if (count == 1) return '1 pedido pendiente';
    return '$count pedidos pendientes';
  }

  String _openGiveawayBadge(int count) {
    if (count == 0) return 'Sin rifas activas';
    if (count == 1) return '1 activa';
    return '$count activas';
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.kolekta.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateSheet(onNavigate: widget.onNavigate),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.kolekta.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _DonateSheet(),
    );
  }
}

// ── Delegate para el sticky header de Acciones rápidas ──────────────────────
//
//  • minExtent == maxExtent → el bloque no colapsa (tamaño fijo).
//  • pinned: true en SliverPersistentHeader → se queda fijo en el top
//    una vez que el scroll lo alcanza; el contenido pasa por debajo.
//  • El fondo coincide con c.background para que "tape" lo que queda atrás.

class _QuickActionsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _QuickActionsHeaderDelegate({
    required this.backgroundColor,
    required this.onCreatePressed,
    required this.onDonatePressed,
  });

  final Color backgroundColor;
  final VoidCallback onCreatePressed;
  final VoidCallback onDonatePressed;

  // 12 (top gap) + 23 (título) + 16 (gap) + 80 (íconos+label) + 16 (bottom padding) = 147
  static const double _height = 147.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_QuickActionsHeaderDelegate oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final c = context.kolekta;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: overlapsContent
            ? Border(bottom: BorderSide(color: c.border, width: 1))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'Acciones rápidas',
            style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          _QuickActions(
            onCreatePressed: onCreatePressed,
            onDonatePressed: onDonatePressed,
          ),
        ],
      ),
    );
  }
}

// ── Header Centrado ─────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final firstName =
        context.watch<AuthProvider>().displayName.split(' ').first;

    return Center(
      child: Column(
        children: [
          Text(
            'Hola, $firstName',
            style: AppTextStyles.displayMedium.copyWith(color: c.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '¿Qué quieres gestionar hoy?',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onCreatePressed;
  final VoidCallback onDonatePressed;

  const _QuickActions({
    required this.onCreatePressed,
    required this.onDonatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Donar — PayPal (primero)
        _QuickActionItem(
          iconPath: 'assets/images/paypal.png',
          label: 'Donar',
          color: const Color(0xFFE8F0FB),
          onTap: onDonatePressed,
        ),
        // Crear
        _QuickActionItem(
          iconPath: 'assets/images/add.png',
          label: 'Crear',
          color: c.primarySurface,
          onTap: onCreatePressed,
        ),
        // Tema
        _QuickActionItem(
          iconPath: isDark
              ? 'assets/images/light_off.png'
              : 'assets/images/light_turn.png',
          label: 'Tema',
          color: c.orangeLight,
          onTap: themeProvider.toggle,
        ),
        // Notificaciones
        Consumer<NotificationProvider>(
          builder: (context, notifProvider, _) {
            return _QuickActionItem(
              iconPath: 'assets/images/bell.png',
              label: 'Notificaciones',
              color: c.pinkLight,
              onTap: () => context.push(AppRoutes.notifications),
              badge: notifProvider.unreadCount,
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _QuickActionItem({
    required this.iconPath,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(iconPath, fit: BoxFit.contain),
                ),
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        badge! > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Donate Sheet ─────────────────────────────────────────────────────────────

class _DonateSheet extends StatefulWidget {
  const _DonateSheet();

  @override
  State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet> {
  static const _webUrl = 'https://www.paypal.com/ncp/payment/XWEFC5NQBQT54';
  static const _appUrl = 'https://www.paypal.me/kolektaapp';
  static const _paypalPackage = 'com.paypal.android.p2pmobile';

  bool _isLoading = false;

  Future<bool> _isPayPalInstalled() async {
    try {
      return await canLaunchUrl(
        Uri.parse('android-app://$_paypalPackage'),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _launchWithChoice() async {
    final webUri = Uri.parse(_webUrl);
    final appUri = Uri.parse(_appUrl);

    final hasApp = await _isPayPalInstalled();

    if (!mounted) return;

    if (hasApp) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('¿Cómo deseas donar?'),
          content: const Text(
            'Detectamos que tienes PayPal instalado. ¿Prefieres abrir la app o el navegador?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await launchUrl(appUri,
                    mode: LaunchMode.externalNonBrowserApplication);
              },
              child: const Text('Abrir app'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await launchUrl(webUri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Abrir navegador',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      setState(() => _isLoading = true);
      try {
        final launched =
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir PayPal. Intenta más tarde.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/images/paypal.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Apóyanos con una donación',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Kolekta es 100% gratis. Si te es útil, una donación voluntaria nos ayuda a seguir mejorando y pagar los servidores. ¡Gracias! 💙',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _launchWithChoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF003087).withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/paypal.png',
                          width: 22,
                          height: 22,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Donar con PayPal',
                          style: AppTextStyles.buttonMedium
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pago seguro · 100% voluntario · Nunca obligatorio',
            style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Tool Card ───────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    Color backgroundColor;
    if (iconPath.contains('batch')) {
      backgroundColor = c.purpleLight;
    } else if (iconPath.contains('catalog')) {
      backgroundColor = c.greenLight;
    } else {
      backgroundColor = c.pinkLight;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Image.asset(
                    iconPath,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title,
              style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(buttonLabel,
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: Colors.white)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Sheet ────────────────────────────────────────────────────────────

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({this.onNavigate});

  final void Function(String route)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    final options = [
      (
        iconPath: 'assets/images/batch.png',
        color: AppColors.purple,
        label: 'Nueva Tanda',
        route: AppRoutes.createBatch,
      ),
      (
        iconPath: 'assets/images/catalog.png',
        color: AppColors.green,
        label: 'Nueva Venta',
        route: AppRoutes.createSale,
      ),
      (
        iconPath: 'assets/images/giveaway.png',
        color: AppColors.pink,
        label: 'Nueva Rifa',
        route: AppRoutes.createGiveaway,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¿Qué deseas crear?',
              style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: o.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Image.asset(
                          o.iconPath,
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    title: Text(
                      o.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    trailing:
                        Icon(Icons.chevron_right_rounded, color: c.textHint),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: c.surfaceVariant,
                    onTap: () {
                      Navigator.of(context).pop();
                      onNavigate?.call(o.route);
                    },
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
