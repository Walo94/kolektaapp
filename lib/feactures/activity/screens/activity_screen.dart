import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';
import '../models/activity_model.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData({bool silent = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context
        .read<ActivityProvider>()
        .loadActivities(token, silent: silent);
  }

  // ── Menú contextual (botón "..." en el AppBar) ────────────────────────────

  void _showOptionsMenu(BuildContext context) {
    final provider = context.read<ActivityProvider>();
    final token = context.read<AuthProvider>().token ?? '';
    final c = context.kolekta;

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Borrar por módulo (solo si hay filtro activo)
              if (provider.moduleFilter != null) ...[
                _BottomSheetOption(
                  icon: Icons.filter_list_off_rounded,
                  label:
                      'Borrar solo ${_moduleLabel(provider.moduleFilter!)}',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmClearAll(
                      context,
                      token: token,
                      module: provider.moduleFilter,
                    );
                  },
                ),
                Divider(height: 1, indent: 20, endIndent: 20, color: c.divider),
              ],

              // Borrar todo el historial
              _BottomSheetOption(
                icon: Icons.delete_sweep_rounded,
                label: 'Borrar todo el historial',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearAll(context, token: token);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Diálogo de confirmación para borrar ───────────────────────────────────

  Future<void> _confirmClearAll(
    BuildContext context, {
    required String token,
    ActivityModule? module,
  }) async {
    final c = context.kolekta;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          module != null
              ? 'Borrar ${_moduleLabel(module)}'
              : 'Borrar historial completo',
          style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary),
        ),
        content: Text(
          module != null
              ? '¿Eliminar todos los registros de ${_moduleLabel(module)}? Esta acción no se puede deshacer.'
              : '¿Eliminar todo tu historial de actividad? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ActivityProvider>();
    final ok = await provider.clearAll(token, module: module);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Historial eliminado' : (provider.errorMessage ?? 'Error')),
        backgroundColor: ok ? AppColors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Confirmación para borrar un solo registro ─────────────────────────────

  Future<void> _confirmDeleteOne(
    BuildContext context,
    ActivityModel item,
  ) async {
    final token = context.read<AuthProvider>().token ?? '';
    final provider = context.read<ActivityProvider>();

    final ok = await provider.deleteOne(token, item.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Actividad eliminada' : (provider.errorMessage ?? 'Error')),
        backgroundColor: ok ? AppColors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Consumer2<ActivityProvider, AuthProvider>(
      builder: (context, activityProv, authProv, _) {
        final token = authProv.token ?? '';

        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Actividad',
                              style: AppTextStyles.displayMedium
                                  .copyWith(color: c.textPrimary),
                            ),
                            Text(
                              activityProv.total > 0
                                  ? '${activityProv.total} movimiento${activityProv.total == 1 ? '' : 's'}'
                                  : 'Todos tus movimientos',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Menú "..." solo cuando hay datos
                      if (!activityProv.loading)
                        IconButton(
                          onPressed: activityProv.deleting
                              ? null
                              : () => _showOptionsMenu(context),
                          icon: activityProv.deleting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.textSecondary,
                                  ),
                                )
                              : Icon(Icons.more_vert_rounded,
                                  color: c.textSecondary),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Filtros de módulo ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          isSelected: activityProv.moduleFilter == null,
                          color: AppColors.primary,
                          onTap: () =>
                              activityProv.setModuleFilter(token, null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Tandas',
                          isSelected: activityProv.moduleFilter ==
                              ActivityModule.batch,
                          color: AppColors.purple,
                          onTap: () => activityProv.setModuleFilter(
                              token, ActivityModule.batch),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Catálogo',
                          isSelected: activityProv.moduleFilter ==
                              ActivityModule.catalog,
                          color: AppColors.green,
                          onTap: () => activityProv.setModuleFilter(
                              token, ActivityModule.catalog),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Rifas',
                          isSelected: activityProv.moduleFilter ==
                              ActivityModule.giveaway,
                          color: AppColors.pink,
                          onTap: () => activityProv.setModuleFilter(
                              token, ActivityModule.giveaway),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Cuerpo principal ──────────────────────────────────────
                Expanded(
                  child: _buildBody(context, activityProv, token, c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActivityProvider provider,
    String token,
    KolektaColors c,
  ) {
    // Estado de carga inicial
    if (provider.loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Estado de error
    if (provider.errorMessage != null && provider.activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                style:
                    AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _loadData(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Estado vacío
    if (provider.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 56, color: c.textHint),
                    const SizedBox(height: 12),
                    Text(
                      'Sin actividad aún',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tus movimientos aparecerán aquí',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: c.textHint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Lista principal con pull-to-refresh
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: provider.activities.length + 1,
        separatorBuilder: (_, i) => i == 0
            ? const SizedBox(height: 4)
            : Divider(height: 1, indent: 68, color: c.divider),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _periodLabel(provider.period),
                style: AppTextStyles.labelMedium
                    .copyWith(color: c.textSecondary),
              ),
            );
          }
          final item = provider.activities[i - 1];
          return _ActivityTile(
            item: item,
            onDelete: () => _confirmDeleteOne(context, item),
          );
        },
      ),
    );
  }

  String _periodLabel(ActivityPeriod period) {
    switch (period) {
      case ActivityPeriod.week:
        return 'Esta semana';
      case ActivityPeriod.month:
        return 'Este mes';
      case ActivityPeriod.all:
        return 'Todos los movimientos';
    }
  }

  String _moduleLabel(ActivityModule module) {
    switch (module) {
      case ActivityModule.batch:
        return 'Tandas';
      case ActivityModule.giveaway:
        return 'Rifas';
      case ActivityModule.catalog:
        return 'Catálogo';
    }
  }
}

// ─── _FilterChip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── _ActivityTile ────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.item,
    required this.onDelete,
  });

  final ActivityModel item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    final (iconData, bgColor, iconColor, chipLabel) =
        switch (item.module) {
      ActivityModule.batch => (
          Icons.sync_alt_rounded,
          c.purpleLight,
          AppColors.purple,
          'Tandas',
        ),
      ActivityModule.catalog => (
          Icons.shopping_bag_outlined,
          c.greenLight,
          AppColors.green,
          'Catálogo',
        ),
      ActivityModule.giveaway => (
          Icons.confirmation_num_outlined,
          c.pinkLight,
          AppColors.pink,
          'Rifas',
        ),
    };

    return GestureDetector(
      // Long press para mostrar opciones del ítem
      onLongPress: () => _showItemMenu(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Ícono del módulo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chipLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(item.createdAt),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: c.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Monto
            if (item.formattedAmount.isNotEmpty)
              Text(
                item.formattedAmount,
                style: item.isPositive
                    ? AppTextStyles.amountPositive
                    : AppTextStyles.amountNegative,
              ),
          ],
        ),
      ),
    );
  }

  void _showItemMenu(BuildContext context, KolektaColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textSecondary),
                  ),
                ),
              ),
              Divider(height: 1, color: c.divider),
              _BottomSheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar este registro',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Hace $h hora${h == 1 ? '' : 's'}';
    }
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── _BottomSheetOption ───────────────────────────────────────────────────────

class _BottomSheetOption extends StatelessWidget {
  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }
}