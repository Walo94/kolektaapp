import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/theme_provider.dart';
import '../../modules/providers/batch_provider.dart';
import '../../modules/providers/catalog_provider.dart';
import '../../modules/providers/giveaway_provider.dart';
import '../../admin/providers/auth_provider.dart';

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

    // Cargar conteos de los tres módulos en paralelo
    await Future.wait([
      context.read<BatchProvider>().loadActiveBatchsCount(token),
      context.read<CatalogProvider>().loadSales(token, silent: true),
      context.read<GiveawayProvider>().loadOpenCount(token),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    final activeBatchsCount = context.watch<BatchProvider>().activeBatchsCount;
    final pendingCount      = context.watch<CatalogProvider>().pendingCount;
    final openGiveawayCount = context.watch<GiveawayProvider>().openCount;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _HomeHeader(),
              const SizedBox(height: 20),
              Text('Acciones rápidas',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),
              _QuickActions(),
              const SizedBox(height: 24),
              Text('Tus herramientas',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.sync_alt_rounded,
                iconBgColor: c.purpleLight,
                iconColor: AppColors.purple,
                title: 'Tandas',
                subtitle:
                    'Gestiona turnos y aportaciones grupales con facilidad',
                badgeText: _activeBatchBadge(activeBatchsCount),
                badgeColor: AppColors.purple,
                buttonLabel: 'Gestionar',
                buttonColor: AppColors.primary,
                onTap: () => widget.onNavigate?.call(AppRoutes.batchs),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.shopping_bag_outlined,
                iconBgColor: c.greenLight,
                iconColor: AppColors.green,
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
                icon: Icons.help_outline_rounded,
                iconBgColor: c.pinkLight,
                iconColor: AppColors.pink,
                title: 'Rifas',
                subtitle:
                    'Administra números, sorteos y ganadores fácilmente',
                badgeText: _openGiveawayBadge(openGiveawayCount),
                badgeColor: AppColors.pink,
                buttonLabel: 'Gestionar',
                buttonColor: AppColors.pink,
                onTap: () => widget.onNavigate?.call(AppRoutes.giveaways),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateSheet(onNavigate: widget.onNavigate),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final firstName = context
        .watch<AuthProvider>()
        .displayName
        .split(' ')
        .first;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, $firstName',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text('¿Qué quieres gestionar hoy?',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => themeProvider.toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                isDark
                    ? 'assets/images/light_off.png'
                    : 'assets/images/light_turn.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quick actions ───────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final actions = [
      (icon: Icons.add_circle_outline_rounded, label: 'Crear',     color: c.primarySurface, iconColor: AppColors.primary),
      (icon: Icons.send_rounded,               label: 'Enviar',    color: c.greenLight,     iconColor: AppColors.green),
      (icon: Icons.download_rounded,           label: 'Recibir',   color: c.pinkLight,      iconColor: AppColors.pink),
      (icon: Icons.history_rounded,            label: 'Historial', color: c.orangeLight,    iconColor: AppColors.orange),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        return Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: a.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(a.icon, color: a.iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(a.label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: c.textSecondary)),
          ],
        );
      }).toList(),
    );
  }
}

// ── Tool card ───────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              style: AppTextStyles.headingSmall
                  .copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
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

// ── Create sheet ────────────────────────────────────────────────────────────────

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({this.onNavigate});

  final void Function(String route)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final options = [
      (
        icon: Icons.sync_alt_rounded,
        color: AppColors.purple,
        bg: c.purpleLight,
        label: 'Nueva Tanda',
        route: AppRoutes.createBatch,
      ),
      (
        icon: Icons.shopping_bag_outlined,
        color: AppColors.green,
        bg: c.greenLight,
        label: 'Nueva Venta',           // ← antes: "Nuevo Catálogo"
        route: AppRoutes.createSale,    // ← ruta correcta para crear venta
      ),
      (
        icon: Icons.help_outline_rounded,
        color: AppColors.pink,
        bg: c.pinkLight,
        label: 'Nueva Rifa',
        route: AppRoutes.createGiveaway, // ← antes: '/rifas' (incorrecto)
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('¿Qué deseas crear?',
              style: AppTextStyles.headingMedium
                  .copyWith(color: c.textPrimary)),
          const SizedBox(height: 16),
          ...options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: o.bg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(o.icon, color: o.color),
                  ),
                  title: Text(o.label,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textPrimary)),
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
    );
  }
}