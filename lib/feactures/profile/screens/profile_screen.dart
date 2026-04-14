import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';
import '../../modules/providers/batch_provider.dart';
import '../../modules/providers/catalog_provider.dart';
import '../../modules/providers/giveaway_provider.dart';
import '../providers/notification_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStats();

      final token = context.read<AuthProvider>().token;

      if (token != null) {
        context.read<NotificationProvider>().refreshUnreadCount(token);
      }
    });
  }

  Future<void> _loadStats() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    // Los providers ya pueden tener datos del home; cargamos en silent para
    // no mostrar spinners y actualizar en segundo plano si algo cambió.
    await Future.wait([
      context.read<BatchProvider>().loadActiveBatchsCount(token),
      context.read<CatalogProvider>().loadSales(token, silent: true),
      context.read<GiveawayProvider>().loadOpenCount(token),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(),
            _StatsRow(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi cuenta',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      iconBg: c.primarySurface,
                      iconColor: AppColors.primary,
                      title: 'Información personal',
                      subtitle: 'Nombre, email, teléfono',
                      onTap: () => context.push(AppRoutes.personalInfo),
                    ),
                    _SettingsItem(
                      icon: Icons.credit_card_rounded,
                      iconBg: c.greenLight,
                      iconColor: AppColors.green,
                      title: 'Suscripciones',
                      subtitle: 'Gestiona tu plan y pagos',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_none_rounded,
                      iconBg: c.orangeLight,
                      iconColor: AppColors.orange,
                      title: 'Notificaciones',
                      subtitle: 'Alertas y recordatorios',
                      onTap: () => context.push(AppRoutes.notifications),
                      trailing: Consumer<NotificationProvider>(
                        builder: (_, notifProvider, __) {
                          if (!notifProvider.hasUnread)
                            return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              notifProvider.unreadCount > 99
                                  ? '99+'
                                  : '${notifProvider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text('Privacidad y seguridad',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.shield_outlined,
                      iconBg: c.pinkLight,
                      iconColor: AppColors.pink,
                      title: 'Seguridad',
                      subtitle: 'Contraseña y autenticación',
                      onTap: () => context.push(AppRoutes.security),
                    ),
                    _SettingsItem(
                      icon: Icons.lock_outline_rounded,
                      iconBg: c.purpleLight,
                      iconColor: AppColors.purple,
                      title: 'Privacidad',
                      subtitle: 'Datos y permisos',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text('Soporte',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      iconBg: c.orangeLight,
                      iconColor: AppColors.orange,
                      title: 'Centro de ayuda',
                      subtitle: null,
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconBg: c.greenLight,
                      iconColor: AppColors.green,
                      title: 'Contactar soporte',
                      subtitle: null,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Cerrar sesión ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.error),
                      label: Text('Cerrar sesión',
                          style: AppTextStyles.buttonMedium
                              .copyWith(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: AppColors.error.withOpacity(0.3)),
                        backgroundColor: AppColors.error.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('Kolekta v1.0.0',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: c.textHint)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final c = context.kolekta;
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cerrar sesión',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        content: Text('¿Estás seguro de que deseas salir?',
            style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              authProvider.logout();
            },
            child: Text('Salir',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 28,
      ),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(auth.displayInitial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 32)),
            ),
          ),
          const SizedBox(height: 12),
          Text(auth.displayName,
              style: AppTextStyles.headingLarge.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(auth.displayEmail,
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white.withOpacity(0.75))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  auth.user?.userAccount == 'premium'
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.orange,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  auth.user?.userAccount == 'premium'
                      ? 'Miembro Premium'
                      : 'Plan Gratuito',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de estadísticas con datos reales de los tres providers.
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    // Datos reales desde los providers (los mismos que usa HomeScreen)
    final activeBatchs = context.watch<BatchProvider>().activeBatchsCount;
    final pendingOrders = context.watch<CatalogProvider>().pendingCount;
    final openGiveaways = context.watch<GiveawayProvider>().openCount;

    // ¿Alguno de los providers está cargando por primera vez?
    final loading = context.watch<BatchProvider>().loading ||
        context.watch<CatalogProvider>().loading ||
        context.watch<GiveawayProvider>().loading;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)
        ],
      ),
      child: loading
          // Skeleton suave mientras llegan los datos
          ? const SizedBox(
              height: 72,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          : Row(
              children: [
                _StatItem(
                  count: activeBatchs.toString(),
                  label: 'Tandas',
                  iconBg: c.purpleLight,
                  iconColor: AppColors.purple,
                  icon: Icons.sync_alt_rounded,
                ),
                _Separator(),
                _StatItem(
                  count: pendingOrders.toString(),
                  label: 'Pendientes',
                  iconBg: c.greenLight,
                  iconColor: AppColors.green,
                  icon: Icons.shopping_bag_outlined,
                ),
                _Separator(),
                _StatItem(
                  count: openGiveaways.toString(),
                  label: 'Rifas',
                  iconBg: c.pinkLight,
                  iconColor: AppColors.pink,
                  icon: Icons.help_outline_rounded,
                ),
              ],
            ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: context.kolekta.divider);
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
  });

  final String count, label;
  final Color iconBg, iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 6),
          Text(count,
              style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(color: c.textHint)),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        children: List.generate(
          items.length,
          (i) => Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 60, endIndent: 16, color: c.divider),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg, iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right_rounded, color: c.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
