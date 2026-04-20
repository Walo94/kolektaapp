import 'package:flutter/material.dart';
import 'package:kolekta/feactures/modules/batchs/screens/create_batch_screen.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/batch_provider.dart';
import '../../services/batch_service.dart';
import '../../../profile/providers/subscription_provider.dart';
import '../../../../shared/widgets/kolekta_pagination.dart';

class BatchsHomeScreen extends StatefulWidget {
  const BatchsHomeScreen({super.key});

  @override
  State<BatchsHomeScreen> createState() => _BatchsHomeScreenState();
}

class _BatchsHomeScreenState extends State<BatchsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final token = context.read<AuthProvider>().token ?? '';
    final status = _getStatusFromIndex(_tabController.index);
    context.read<BatchProvider>().setStatusFilter(token, status);
  }

  BatchStatus? _getStatusFromIndex(int index) {
    switch (index) {
      case 0:
        return BatchStatus.active;
      case 1:
        return BatchStatus.finished;
      case 2:
        return BatchStatus.cancelled;
      default:
        return BatchStatus.active;
    }
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final prov = context.read<BatchProvider>();
    if (prov.statusFilter != BatchStatus.active) {
      await prov.setStatusFilter(token, BatchStatus.active);
    } else {
      await prov.loadBatchs(token);
    }
  }

  void _goToCreate() {
    final sub = context.read<SubscriptionProvider>();

    // Nueva validación basada en Stripe
    final bool hasActiveSubscription = sub.hasActiveSubscription;
    final int currentBatchsCount = _getOpenBatchsCount();

    if (!hasActiveSubscription && currentBatchsCount >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Has alcanzado el límite de tandas activas de tu plan. '
            'Actualiza a Premium para crear más.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateBatchScreen()),
    );

  }

  int _getOpenBatchsCount() {
    final prov = context.read<BatchProvider>();
    return prov.batchs.where((g) => g.status == BatchStatus.active).length;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final batchProvider = context.watch<BatchProvider>();
    final safeArea = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          SizedBox(height: safeArea.top + 16),

          // ── Header ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tandas',
                        style: AppTextStyles.displayMedium
                            .copyWith(color: c.textPrimary)),
                    Text('Gestiona turnos y aportaciones',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary)),
                  ],
                ),
                FloatingActionButton(
                  heroTag: 'batch_fab',
                  onPressed: _goToCreate,
                  backgroundColor: AppColors.primary,
                  mini: true,
                  elevation: 4,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tabs ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: c.textSecondary,
                labelStyle: AppTextStyles.labelMedium,
                unselectedLabelStyle: AppTextStyles.labelMedium,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Activas'),
                        if (batchProvider.activeBatchsCount > 0) ...[
                          const SizedBox(width: 4),
                          _CountBadge(count: batchProvider.activeBatchsCount),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Terminadas'),
                  const Tab(text: 'Canceladas'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Contenido ─────────────────────────────────
          Expanded(
            child: batchProvider.loading && batchProvider.batchs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _BatchList(
                        batchs: batchProvider.batchs,
                        emptyMessage: 'No tienes tandas activas',
                        emptyIcon: Icons.sync_alt_rounded,
                        onRefresh: _load,
                        canEdit: true,
                        total: batchProvider.total,
                      ),
                      _BatchList(
                        batchs: batchProvider.batchs,
                        emptyMessage: 'No tienes tandas terminadas',
                        emptyIcon: Icons.check_circle_outline_rounded,
                        onRefresh: _load,
                        canEdit: false,
                        total: batchProvider.total,
                      ),
                      _BatchList(
                        batchs: batchProvider.batchs,
                        emptyMessage: 'No tienes tandas canceladas',
                        emptyIcon: Icons.cancel_outlined,
                        onRefresh: _load,
                        canEdit: false,
                        total: batchProvider.total,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de tandas ───────────────────────────────────────

class _BatchList extends StatelessWidget {
  const _BatchList({
    required this.batchs,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
    required this.canEdit,
    required this.total,
  });

  final List<Batch> batchs;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final bool canEdit;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
   if (batchs.isEmpty) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              // ← Cambiado: Usamos Image.asset en lugar del icono circular
              Image.asset(
                'assets/images/batch2.png',
                width: 100,           // Ajusta el tamaño según se vea mejor
                height: 100,
              ),
              const SizedBox(height: 24),
              Text(emptyMessage,
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ],
    ),
  );
}

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: batchs.length + 1, // +1 siempre para el widget de paginación
        itemBuilder: (context, i) {
          if (i < batchs.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BatchCard(
                batch: batchs[i],
                canEdit: canEdit,
                onRefresh: onRefresh,
              ),
            );
          }
          return KolektaPagination(
            loaded: batchs.length,
            total: total,
            hasMore: false,
            onLoadMore: () {},
          );
        },
      ),
    );
  }
}

// ── Tarjeta de tanda ──────────────────────────────────────

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.canEdit,
    required this.onRefresh,
  });

  final Batch batch;
  final bool canEdit;
  final Future<void> Function() onRefresh;

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('d MMM yyyy', 'es').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatMoney(double amount) {
    return '\$${NumberFormat('#,##0', 'es').format(amount)}';
  }

  /// La tanda es editable si está activa Y no se ha entregado ningún turno.
  bool get _isEditable => canEdit && batch.currentTurn == 0;

  // ── URL pública de la tanda ───────────────────────────
  // En desarrollo apunta al servidor local; en producción a kolekta.gamezdev.com.mx
  // Cambia _kBaseShareUrl según el entorno antes de publicar.
  static final String _kBaseShareUrl =
      '${dotenv.env['WEB_URL']}/shared/batch';
  // static const String _kBaseShareUrl =
  //     'https://kolekta.gamezdev.com.mx/shared/batch';

  String get _shareUrl => '$_kBaseShareUrl/${batch.publicToken}';

  // ── Compartir tanda ───────────────────────────────────
  Future<void> _shareBatch(BuildContext context) async {
    Navigator.pop(context); // Cierra el bottom sheet

    // Muestra un indicador mientras se prepara el mensaje
    final messenger = ScaffoldMessenger.of(context);

    try {
      final text = '¡Únete a la tanda "${batch.name}"!\n\n'
          '💰 Aportación: ${_formatMoney(batch.entryPrice)}\n'
          '🔄 Frecuencia: ${batch.frequency.label}\n'
          '👥 Lugares: ${batch.totalSlots}\n\n'
          'Consulta tu turno y los detalles aquí:\n$_shareUrl';

      await Share.share(
        text,
        subject: 'Tanda "${batch.name}" — Kolekta',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el menú de compartir')),
      );
    }
  }

  void _showContextMenu(BuildContext context) {
    final c = context.kolekta;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // isScrollControlled permite que el sheet crezca más allá del 50% de pantalla
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  batch.name,
                  style:
                      AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditable
                      ? 'Sin entregas registradas — puede editarse'
                      : 'Turno ${batch.currentTurn}/${batch.totalSlots} — solo lectura',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 16),

                // ── Ver detalle ─────────────────────────
                _SheetOption(
                  icon: Icons.visibility_outlined,
                  iconBg: AppColors.primarySurface,
                  iconColor: AppColors.primary,
                  label: 'Ver detalle',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      AppRoutes.batchDetail.replaceFirst(':id', batch.id),
                    );
                  },
                ),

                // ── Compartir tanda ─────────────────────
                _SheetOption(
                  icon: Icons.share_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF25D366),
                  label: 'Compartir tanda',
                  onTap: () => _shareBatch(context),
                ),

                // ── Editar (solo si no ha iniciado) ─────
                if (_isEditable)
                  _SheetOption(
                    icon: Icons.edit_outlined,
                    iconBg: c.purpleLight,
                    iconColor: AppColors.purple,
                    label: 'Editar tanda',
                    onTap: () {
                      Navigator.pop(context);
                      _showEditSheet(context);
                    },
                  ),

                const Divider(height: 24),

                // ── Cancelar tanda ──────────────────────
                if (batch.status == BatchStatus.active)
                  _SheetOption(
                    icon: Icons.cancel_outlined,
                    iconBg: AppColors.statusPending,
                    iconColor: AppColors.statusPendingText,
                    label: 'Cancelar tanda',
                    labelColor: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmCancel(context);
                    },
                  ),

                // ── Eliminar tanda ──────────────────────
                _SheetOption(
                  icon: Icons.delete_outline_rounded,
                  iconBg: AppColors.statusPending,
                  iconColor: AppColors.error,
                  label: 'Eliminar tanda',
                  labelColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sheet de edición rápida: solo nombre y notas (la imagen se edita en detalle)
  void _showEditSheet(BuildContext context) {
    final c = context.kolekta;
    final nameCtrl = TextEditingController(text: batch.name);
    final notesCtrl = TextEditingController(text: batch.notes ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 16),
            Text('Editar tanda',
                style:
                    AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Nombre',
                prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.notes_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final token = ctx.read<AuthProvider>().token ?? '';
                  final provider = ctx.read<BatchProvider>();
                  Navigator.pop(ctx);
                  await provider.updateBatch(
                    token: token,
                    batchId: batch.id,
                    name: nameCtrl.text.trim().isNotEmpty
                        ? nameCtrl.text.trim()
                        : null,
                    notes: notesCtrl.text.trim(),
                  );
                  await onRefresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Guardar cambios',
                    style: AppTextStyles.buttonMedium
                        .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final c = context.kolekta;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancelar tanda',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Seguro que deseas cancelar "${batch.name}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No, volver',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final token = context.read<AuthProvider>().token ?? '';
              await context
                  .read<BatchProvider>()
                  .cancelBatch(token: token, batchId: batch.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sí, cancelar',
                style:
                    AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final c = context.kolekta;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar tanda',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Seguro que deseas eliminar "${batch.name}"? Se borrarán todos los participantes y no se puede deshacer.',
          style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No, volver',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final token = context.read<AuthProvider>().token ?? '';
              await context
                  .read<BatchProvider>()
                  .deleteBatch(token: token, batchId: batch.id);
              await onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sí, eliminar',
                style:
                    AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final progress =
        batch.totalSlots > 0 ? (batch.currentTurn / batch.totalSlots) : 0.0;

    return GestureDetector(
      // Tap normal → ir al detalle
      onTap: () => context.push(
        AppRoutes.batchDetail.replaceFirst(':id', batch.id),
      ),
      // Long press → menú contextual
      onLongPress: () => _showContextMenu(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            // ── Fila superior ──────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.purpleLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sync_alt_rounded,
                      color: AppColors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.name,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: c.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Icon(Icons.people_alt_outlined,
                              size: 13, color: c.textHint),
                          const SizedBox(width: 3),
                          Text('${batch.totalSlots} integrantes',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: c.textHint)),
                          const SizedBox(width: 8),
                          Icon(Icons.repeat_rounded,
                              size: 13, color: c.textHint),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              batch.frequency.label,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: c.textHint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Badge de estado
                _StatusBadge(status: batch.status),
              ],
            ),

            const SizedBox(height: 14),

            // ── Stats ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat(
                  label: 'Aportación',
                  value: _formatMoney(batch.entryPrice),
                  valueColor: AppColors.primary,
                ),
                _Stat(
                  label: 'Turno',
                  value: '${batch.currentTurn}/${batch.totalSlots}',
                ),
                _Stat(
                  label: batch.status == BatchStatus.active ? 'Próximo' : 'Fin',
                  value: batch.status == BatchStatus.active
                      ? _formatDate(batch.nextDeliveryDate)
                      : _formatDate(batch.startDate),
                ),
                _Stat(
                  label: 'Pago',
                  value: _formatMoney(batch.payoutAmount),
                  valueColor: AppColors.success,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Barra de progreso ──────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: c.divider,
                color: batch.status == BatchStatus.finished
                    ? AppColors.success
                    : AppColors.primary,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Opción de sheet contextual ────────────────────────────

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label,
          style: AppTextStyles.labelLarge
              .copyWith(color: labelColor ?? c.textPrimary)),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final BatchStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    Color bg;
    Color textColor;
    String label;

    switch (status) {
      case BatchStatus.active:
        bg = c.successLight;
        textColor = AppColors.success;
        label = 'Activa';
        break;
      case BatchStatus.finished:
        bg = c.statusCompleted;
        textColor = c.statusCompletedText;
        label = 'Completada';
        break;
      case BatchStatus.cancelled:
        bg = AppColors.statusPending;
        textColor = AppColors.statusPendingText;
        label = 'Cancelada';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(color: c.textHint)),
        Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor ?? c.textPrimary,
            )),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
