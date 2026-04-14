// lib/feactures/profile/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<NotificationProvider>().loadNotifications(token);
  }

  Future<void> _markAllRead() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<NotificationProvider>().markAllAsRead(token);
  }

  Future<void> _deleteAll() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final c = context.kolekta;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar todo',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        content: Text(
            '¿Eliminar todas las notificaciones? Esta acción no se puede deshacer.',
            style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Eliminar',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<NotificationProvider>().deleteAll(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notificaciones',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        centerTitle: false,
        actions: [
          // Botón ajustes de preferencias
          IconButton(
            icon: Icon(Icons.tune_rounded, color: c.textSecondary, size: 22),
            tooltip: 'Preferencias',
            onPressed: () => context.push(AppRoutes.notificationPreferences),
          ),
          // Menú contextual
          if (provider.notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: c.textSecondary),
              color: c.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'read_all') _markAllRead();
                if (v == 'delete_all') _deleteAll();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text('Marcar todo como leído',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: c.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Text('Eliminar todo',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: provider.loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : provider.notifications.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: provider.notifications.length,
                    itemBuilder: (_, i) {
                      final notif = provider.notifications[i];
                      return _NotificationTile(
                        notification: notif,
                        onTap: () => _handleTap(notif),
                        onDismiss: () => _handleDismiss(notif),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _handleTap(NotificationModel notif) async {
    final token = context.read<AuthProvider>().token;
    if (token != null && !notif.isRead) {
      await context.read<NotificationProvider>().markAsRead(token, notif.id);
    }
    if (!mounted) return;

    // Navegar a la pantalla correspondiente según el tipo
    final data = notif.data;
    switch (notif.type) {
      case NotificationType.giveawayTicketReserved:
      case NotificationType.giveawayAutoDrawDone:
      case NotificationType.giveawayDrawReminder:
        final id = data?['giveawayId'] as String?;
        if (id != null) {
          context.push(AppRoutes.giveawayDetail.replaceFirst(':id', id));
        }
        break;
      case NotificationType.batchDeliveryReminder:
        final id = data?['batchId'] as String?;
        if (id != null) {
          context.push(AppRoutes.batchDetail.replaceFirst(':id', id));
        }
        break;
      case null:
        break;
    }
  }

  Future<void> _handleDismiss(NotificationModel notif) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<NotificationProvider>().delete(token, notif.id);
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.orangeLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: AppColors.orange, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Sin notificaciones',
              style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Aquí aparecerán tus alertas\nde rifas, tandas y más.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Tile individual ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  // Colores e iconos según tipo
  static _TypeStyle _styleFor(NotificationType? type, KolektaColors c) {
    switch (type) {
      case NotificationType.giveawayTicketReserved:
        return _TypeStyle(
          icon: Icons.confirmation_num_outlined,
          iconBg: c.pinkLight,
          iconColor: AppColors.pink,
          dot: AppColors.pink,
        );
      case NotificationType.giveawayAutoDrawDone:
        return _TypeStyle(
          icon: Icons.emoji_events_outlined,
          iconBg: c.orangeLight,
          iconColor: AppColors.orange,
          dot: AppColors.orange,
        );
      case NotificationType.giveawayDrawReminder:
        return _TypeStyle(
          icon: Icons.timer_outlined,
          iconBg: c.orangeLight,
          iconColor: AppColors.orange,
          dot: AppColors.orange,
        );
      case NotificationType.batchDeliveryReminder:
        return _TypeStyle(
          icon: Icons.sync_alt_rounded,
          iconBg: c.purpleLight,
          iconColor: AppColors.purple,
          dot: AppColors.purple,
        );
      case null:
        return _TypeStyle(
          icon: Icons.notifications_none_rounded,
          iconBg: c.primarySurface,
          iconColor: AppColors.primary,
          dot: AppColors.primary,
        );
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('d MMM', 'es').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final style = _styleFor(notification.type, c);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 22),
      ),
      confirmDismiss: (_) async {
        onDismiss();
        return false; // Lo removemos manualmente desde el provider
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread ? AppColors.primary.withOpacity(0.04) : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread ? AppColors.primary.withOpacity(0.15) : c.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono del tipo
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.iconBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(style.icon, color: style.iconColor, size: 22),
                  ),
                  // Punto de no leído
                  if (isUnread)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: style.dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: c.textPrimary,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(notification.createdAt),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: c.textHint),
                        ),
                      ],
                    ),
                    if (notification.body != null &&
                        notification.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Chip de tipo
                    const SizedBox(height: 8),
                    _TypeChip(type: notification.type, c: c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeStyle {
  final IconData icon;
  final Color iconBg, iconColor, dot;
  const _TypeStyle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.dot,
  });
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.c});
  final NotificationType? type;
  final KolektaColors c;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (type) {
      case NotificationType.giveawayTicketReserved:
        label = 'Rifa · Boleto';
        color = AppColors.pink;
        break;
      case NotificationType.giveawayAutoDrawDone:
        label = 'Rifa · Sorteo';
        color = AppColors.orange;
        break;
      case NotificationType.giveawayDrawReminder:
        label = 'Rifa · Recordatorio';
        color = AppColors.orange;
        break;
      case NotificationType.batchDeliveryReminder:
        label = 'Tanda · Entrega';
        color = AppColors.purple;
        break;
      case null:
        label = 'Sistema';
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
