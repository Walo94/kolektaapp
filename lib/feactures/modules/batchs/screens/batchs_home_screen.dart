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
import '../../../../shared/widgets/kolekta_pagination.dart';
import '../../../../shared/widgets/kolekta_search_bar.dart';
import '../../../../shared/widgets/kolekta_search_results.dart';

class BatchsHomeScreen extends StatefulWidget {
  const BatchsHomeScreen({super.key});

  @override
  State<BatchsHomeScreen> createState() => _BatchsHomeScreenState();
}

class _BatchsHomeScreenState extends State<BatchsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Búsqueda ─────────────────────────────────────────────
  bool _searchOpen = false;

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
    final currentStatus = _getStatusFromIndex(_tabController.index);
    if (prov.statusFilter != currentStatus) {
      await prov.setStatusFilter(token, currentStatus);
    } else {
      await prov.loadBatchs(token);
    }
  }

  void _goToCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateBatchScreen()),
    );
  }

  // ── Abrir / cerrar buscador ───────────────────────────────
  void _openSearch() {
    setState(() => _searchOpen = true);
  }

  void _closeSearch() {
    setState(() => _searchOpen = false);
    context.read<BatchProvider>().clearSearch();
  }

  void _onSearch(String query) {
    final token = context.read<AuthProvider>().token ?? '';
    context.read<BatchProvider>().searchBatchs(token, query);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final batchProvider = context.watch<BatchProvider>();
    final safeArea = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: c.background,
      body: KolektaSearchBar(
        isOpen: _searchOpen,
        hintText: 'Buscar tanda o participante…',
        onSearch: _onSearch,
        onClose: _closeSearch,
        child: Column(
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
                  Row(
                    children: [
                      // ── Botón buscar ──────────────────────
                      GestureDetector(
                        onTap: _openSearch,
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(Icons.search_rounded,
                              size: 18, color: c.textSecondary),
                        ),
                      ),
                      // ── Botón crear ───────────────────────
                      FloatingActionButton(
                        heroTag: 'batch_fab',
                        onPressed: _goToCreate,
                        backgroundColor: AppColors.primary,
                        mini: true,
                        elevation: 4,
                        child:
                            const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabs (se ocultan mientras busca) ──────────
            if (!_searchOpen) ...[
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
                              _CountBadge(
                                  count: batchProvider.activeBatchsCount),
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
            ],

            // ── Contenido: búsqueda OR lista normal ────────
            if (_searchOpen)
              _buildSearchContent(batchProvider, c)
            else
              _buildNormalContent(batchProvider),
          ],
        ),
      ),
    );
  }

  // ── Vista de resultados de búsqueda ─────────────────────
  Widget _buildSearchContent(BatchProvider prov, dynamic c) {
    final token = context.read<AuthProvider>().token ?? '';

    return KolektaSearchResults<Batch>(
      query: prov.searchQuery,
      isLoading: prov.searchLoading,
      groups: [
        SearchResultGroup<Batch>(
          label: 'Activas',
          items: prov.searchActive,
          total: prov.searchTotalActive,
          hasMore: prov.searchHasMoreActive,
        ),
        SearchResultGroup<Batch>(
          label: 'Terminadas',
          items: prov.searchFinished,
          total: prov.searchTotalFinished,
          hasMore: prov.searchHasMoreFinished,
        ),
        SearchResultGroup<Batch>(
          label: 'Canceladas',
          items: prov.searchCancelled,
          total: prov.searchTotalCancelled,
          hasMore: prov.searchHasMoreCancelled,
        ),
      ],
      itemBuilder: (batch) => _BatchCard(
        batch: batch,
        canEdit: batch.status == BatchStatus.active,
        onRefresh: _load,
      ),
      onLoadMore: (groupIndex) => prov.searchLoadMore(token, groupIndex),
      emptyMessage: 'Sin resultados para',
    );
  }

  // ── Vista normal con tabs ─────────────────────────────────
  Widget _buildNormalContent(BatchProvider batchProvider) {
    return Expanded(
      child: batchProvider.loading && batchProvider.batchs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : batchProvider.errorMessage != null && batchProvider.batchs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Builder(builder: (context) {
                      final c = context.kolekta;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 48, color: c.textHint),
                          const SizedBox(height: 12),
                          Text(
                            batchProvider.errorMessage!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                )
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
                  Image.asset(
                    'assets/images/batch2.png',
                    width: 100,
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
        itemCount: batchs.length + 1,
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
// (se mantiene idéntica al original — solo se mueve aquí para completitud)

class _BatchCard extends StatefulWidget {
  const _BatchCard({
    required this.batch,
    required this.canEdit,
    required this.onRefresh,
  });

  final Batch batch;
  final bool canEdit;
  final Future<void> Function() onRefresh;

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  bool _isActionLoading = false;

  Batch get batch => widget.batch;
  bool get canEdit => widget.canEdit;
  Future<void> Function() get onRefresh => widget.onRefresh;

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

  bool get _isEditable => canEdit && batch.currentTurn == 0;

  static final String _kBaseShareUrl = '${dotenv.env['WEB_URL']}/shared/batch';
  String get _shareUrl => '$_kBaseShareUrl/${batch.publicToken}';

  Future<void> _shareBatch(BuildContext context) async {
    Navigator.pop(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = '¡Únete a la tanda "${batch.name}"!\n\n'
          '💰 Aportación: ${_formatMoney(batch.entryPrice)}\n'
          '🔄 Frecuencia: ${batch.frequency.label}\n'
          '👥 Lugares: ${batch.totalSlots}\n\n'
          'Consulta tu turno y los detalles aquí:\n$_shareUrl';
      await Share.share(text, subject: 'Tanda "${batch.name}" — Kolekta');
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
                _SheetOption(
                  icon: Icons.share_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF25D366),
                  label: 'Compartir tanda',
                  onTap: () => _shareBatch(context),
                ),
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
                if (batch.status == BatchStatus.cancelled ||
                    batch.status == BatchStatus.finished)
                  _SheetOption(
                    icon: Icons.delete_outline_rounded,
                    iconBg: AppColors.error.withOpacity(0.1),
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

  void _showEditSheet(BuildContext context) {
    // Mantén tu implementación original aquí
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final c = context.kolekta;
    final token = context.read<AuthProvider>().token ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar tanda',
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Cancelar la tanda "${batch.name}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar tanda',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await BatchService.cancelBatch(token: token, batchId: batch.id);
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Tanda cancelada'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      await onRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final c = context.kolekta;
    final token = context.read<AuthProvider>().token ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar tanda',
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Eliminar permanentemente la tanda "${batch.name}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await BatchService.deleteBatch(token: token, batchId: batch.id);
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Tanda eliminada'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      await onRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final progress =
        batch.totalSlots > 0 ? batch.currentTurn / batch.totalSlots : 0.0;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => context.push(
            AppRoutes.batchDetail.replaceFirst(':id', batch.id),
          ),
          onLongPress: () => _showContextMenu(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título + badge ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.name,
                            style: AppTextStyles.headingSmall
                                .copyWith(color: c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 11, color: c.textHint),
                              const SizedBox(width: 3),
                              Text(
                                _formatDate(batch.startDate),
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: c.textHint),
                              ),
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
                      label: batch.status == BatchStatus.active
                          ? 'Próximo'
                          : 'Fin',
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
        ),
        if (_isActionLoading)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 10),
                      Text(
                        'Procesando...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
