import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_pagination.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/giveaway_provider.dart';
import '../../services/giveaway_service.dart';
import '../../../../shared/widgets/kolekta_search_bar.dart';
import '../../../../shared/widgets/kolekta_search_results.dart';
import 'create_giveaway_screen.dart';
import 'giveaway_detail_screen.dart';
import '../../../profile/providers/subscription_provider.dart';

class GiveawaysHomeScreen extends StatefulWidget {
  const GiveawaysHomeScreen({super.key});

  @override
  State<GiveawaysHomeScreen> createState() => _GiveawaysHomeScreenState();
}

class _GiveawaysHomeScreenState extends State<GiveawaysHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isActionLoading = false;
  bool _searchOpen = false;

  static const _tabs = [
    (label: 'Abiertas', status: GiveawayStatus.open),
    (label: 'Finalizadas', status: GiveawayStatus.finished),
    (label: 'Canceladas', status: GiveawayStatus.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
    final status = _tabs[_tabController.index].status;
    context.read<GiveawayProvider>().setStatusFilter(token, status);
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final prov = context.read<GiveawayProvider>();
    final currentStatus = _tabs[_tabController.index].status;
    if (prov.statusFilter != currentStatus) {
      await prov.setStatusFilter(token, currentStatus);
    } else {
      await prov.loadGiveaways(token);
    }
  }

  void _goToCreate() {
    final sub = context.read<SubscriptionProvider>();

    final bool hasActiveSubscription = sub.hasActiveSubscription;
    final int currentGiveawaysCount = _getOpenGiveawaysCount();

    if (!hasActiveSubscription && currentGiveawaysCount >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Has alcanzado el límite de rifas activas en tu plan. Suscríbete a Premium para crear más.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateGiveawayScreen()),
    );
  }

  int _getOpenGiveawaysCount() {
    final prov = context.read<GiveawayProvider>();
    return prov.giveaways.where((g) => g.status == GiveawayStatus.open).length;
  }

  void _goToDetail(Giveaway g) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GiveawayDetailScreen(giveawayId: g.id)),
    );
  }

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    setState(() => _searchOpen = false);
    context.read<GiveawayProvider>().clearSearch();
  }

  void _onSearch(String query) {
    final token = context.read<AuthProvider>().token ?? '';
    context.read<GiveawayProvider>().searchGiveaways(token, query);
  }

  void _showContextMenu(BuildContext ctx, Giveaway g, String token) {
    final c = ctx.kolekta;
    final prov = ctx.read<GiveawayProvider>();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(g.title,
                  style:
                      AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
              const SizedBox(height: 16),
              if (g.status == GiveawayStatus.open) ...[
                _SheetOption(
                  icon: Icons.edit_outlined,
                  iconBg: c.primarySurface,
                  iconColor: AppColors.primary,
                  label: 'Editar rifa',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => CreateGiveawayScreen(giveawayToEdit: g),
                    ));
                  },
                ),
                _SheetOption(
                  icon: Icons.cancel_outlined,
                  iconBg: AppColors.orangeLight,
                  iconColor: AppColors.orange,
                  label: 'Cancelar rifa',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDialog(
                      ctx,
                      title: 'Cancelar rifa',
                      content:
                          '¿Cancelar "${g.title}"? Todos los boletos vendidos quedarán liberados.',
                      confirmLabel: 'Cancelar rifa',
                      confirmColor: AppColors.orange,
                    );
                    if (confirmed != true || !mounted) return;
                    setState(() => _isActionLoading = true);
                    final ok = await prov.cancelGiveaway(token, g.id);
                    if (mounted) setState(() => _isActionLoading = false);
                    _showSnack(
                        ok ? 'Rifa cancelada' : prov.errorMessage ?? 'Error',
                        ok);
                  },
                ),
              ],
              _SheetOption(
                icon: Icons.delete_outline_rounded,
                iconBg: AppColors.statusPending,
                iconColor: AppColors.error,
                label: 'Eliminar rifa',
                labelColor: AppColors.error,
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await _confirmDialog(
                    ctx,
                    title: 'Eliminar rifa',
                    content:
                        '¿Eliminar permanentemente "${g.title}"? Esta acción no se puede deshacer.',
                    confirmLabel: 'Eliminar',
                    confirmColor: AppColors.error,
                  );
                  if (confirmed != true || !mounted) return;
                  setState(() => _isActionLoading = true);
                  final ok = await prov.deleteGiveaway(token, g.id);
                  if (mounted) setState(() => _isActionLoading = false);
                  _showSnack(
                      ok ? 'Rifa eliminada' : prov.errorMessage ?? 'Error', ok);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDialog(
    BuildContext ctx, {
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    final c = ctx.kolekta;
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(content,
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, bool isOk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isOk ? AppColors.pink : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final safeArea = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: c.background,
      body: KolektaSearchBar(
        isOpen: _searchOpen,
        hintText: 'Buscar rifa o participante…',
        onSearch: _onSearch,
        onClose: _closeSearch,
        child: Column(
          children: [
            SizedBox(height: safeArea.top + 16),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rifas',
                          style: AppTextStyles.displayMedium
                              .copyWith(color: c.textPrimary)),
                      Text('Gestiona sorteos y ganadores',
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
                        heroTag: 'giveaway_fab',
                        onPressed: _goToCreate,
                        backgroundColor: AppColors.pink,
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

            // ── Tarjeta resumen (solo cuando NO está en búsqueda) ──────
            if (!_searchOpen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Consumer<GiveawayProvider>(
                    builder: (context, prov, _) => Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Potencial total',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: Colors.white70)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _formatMoney(_potentialTotal(prov)),
                                  style: AppTextStyles.displayMedium.copyWith(
                                      color: Colors.white, fontSize: 28),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${prov.giveaways.where((g) => g.status == GiveawayStatus.open).length} rifa(s) abierta(s)',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_totalSoldTickets(prov)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800),
                              ),
                              const Text(
                                'Vendidos',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Tabs (se ocultan mientras busca) ───────────────────────
            if (!_searchOpen)
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
                      color: AppColors.pink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    labelColor: Colors.white,
                    unselectedLabelColor: c.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                    dividerColor: Colors.transparent,
                    tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── Contenido: búsqueda OR lista normal ────────────────────
            if (_searchOpen) _buildSearchContent() else _buildNormalContent(),
          ],
        ),
      ),
    );
  }

  // ── Vista de resultados de búsqueda ─────────────────────────────
  Widget _buildSearchContent() {
    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.watch<GiveawayProvider>();

    return KolektaSearchResults<Giveaway>(
      query: prov.searchQuery,
      isLoading: prov.searchLoading,
      groups: [
        SearchResultGroup<Giveaway>(
          label: 'Abiertas',
          items: prov.searchOpen,
          total: prov.searchTotalOpen,
          hasMore: prov.searchHasMoreOpen,
        ),
        SearchResultGroup<Giveaway>(
          label: 'Finalizadas',
          items: prov.searchFinished,
          total: prov.searchTotalFinished,
          hasMore: prov.searchHasMoreFinished,
        ),
        SearchResultGroup<Giveaway>(
          label: 'Canceladas',
          items: prov.searchCancelled,
          total: prov.searchTotalCancelled,
          hasMore: prov.searchHasMoreCancelled,
        ),
      ],
      itemBuilder: (giveaway) => _GiveawayCard(
        giveaway: giveaway,
        onTap: () => _goToDetail(giveaway),
        onLongPress: () => _showContextMenu(context, giveaway, token),
      ),
      onLoadMore: (groupIndex) => prov.searchLoadMore(token, groupIndex),
      emptyMessage: 'Sin resultados para',
    );
  }

  // ── Vista normal con tabs ──────────────────────────────────────
  Widget _buildNormalContent() {
    final prov = context.watch<GiveawayProvider>();
    final token =
        context.read<AuthProvider>().token ?? ''; // ← Agrega esta línea

    return Expanded(
      child: prov.loading && prov.giveaways.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pink))
          : prov.errorMessage != null && prov.giveaways.isEmpty
              ? _ErrorState(
                  message: prov.errorMessage!,
                  onRetry: _load,
                )
              : prov.isEmpty
                  ? _EmptyState(onRefresh: _load)
                  : RefreshIndicator(
                      color: AppColors.pink,
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        itemCount: prov.giveaways.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i < prov.giveaways.length) {
                            final g = prov.giveaways[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _GiveawayCard(
                                giveaway: g,
                                onTap: () => _goToDetail(g),
                                onLongPress: () => _showContextMenu(
                                    context, g, token), // ← Usa token
                              ),
                            );
                          }
                          return KolektaPagination(
                            loaded: prov.giveaways.length,
                            total: prov.total,
                            hasMore: false,
                            onLoadMore: () {},
                          );
                        },
                      ),
                    ),
    );
  }

  double _potentialTotal(GiveawayProvider prov) => prov.giveaways
      .where((g) => g.status == GiveawayStatus.open)
      .fold(0.0, (sum, g) => sum + g.totalPotential);

  int _totalSoldTickets(GiveawayProvider prov) => prov.giveaways
      .where((g) => g.status == GiveawayStatus.open)
      .fold(0, (sum, g) => sum + g.soldTickets);

  String _formatMoney(double v) {
    return '\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

// ─── _GiveawayCard ────────────────────────────────────────────────────────────

class _GiveawayCard extends StatelessWidget {
  const _GiveawayCard({
    required this.giveaway,
    required this.onTap,
    required this.onLongPress,
  });

  final Giveaway giveaway;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final progress = giveaway.soldPercentage;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila superior ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.pinkLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.confirmation_number_outlined,
                      color: AppColors.pink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        giveaway.title,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: c.textHint),
                          const SizedBox(width: 3),
                          Text(
                            'Sorteo: ${_fmtDate(giveaway.drawDate)}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: c.textHint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: giveaway.status),
              ],
            ),

            const SizedBox(height: 14),

            // ── Stats ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat(
                  label: 'Precio',
                  value: _fmtMoney(giveaway.ticketPrice),
                  valueColor: AppColors.pink,
                ),
                _Stat(
                  label: 'Boletos',
                  value: '${giveaway.soldTickets}/${giveaway.totalTickets}',
                ),
                _Stat(
                  label: 'Premios',
                  value: '${giveaway.prizeCount}',
                ),
                _Stat(
                  label: 'Potencial',
                  value: _fmtMoney(giveaway.totalPotential),
                  valueColor: AppColors.success,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Barra de progreso de ventas ────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% vendido',
                  style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: c.divider,
                    color: giveaway.status == GiveawayStatus.finished
                        ? AppColors.success
                        : AppColors.pink,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String d) {
    try {
      return DateFormat('d MMM yyyy', 'es').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _fmtMoney(double v) =>
      '\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final GiveawayStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    Color bg;
    Color textColor;

    switch (status) {
      case GiveawayStatus.open:
        bg = c.pinkLight;
        textColor = AppColors.pink;
        break;
      case GiveawayStatus.finished:
        bg = c.successLight;
        textColor = AppColors.success;
        break;
      case GiveawayStatus.cancelled:
        bg = c.divider;
        textColor = c.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        status.label,
        style: TextStyle(
            color: textColor, fontSize: 10, fontWeight: FontWeight.w700),
      ),
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? c.textPrimary)),
      ],
    );
  }
}

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
      trailing: Icon(Icons.chevron_right_rounded, color: c.textHint, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return RefreshIndicator(
      color: AppColors.pink,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/giveaway2.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Sin rifas',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca + para crear tu primera rifa',
                    style: AppTextStyles.bodySmall.copyWith(color: c.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
          const SizedBox(height: 12),
          Text(message,
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(foregroundColor: AppColors.pink),
          ),
        ],
      ),
    );
  }
}
