import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_pagination.dart';
import '../../../../shared/widgets/kolekta_search_bar.dart';
import '../../../../shared/widgets/kolekta_search_results.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/catalog_service.dart';
import 'create_sale_screen.dart';
import 'sale_detail_screen.dart';
import 'products_home_screen.dart';

class CatalogsHomeScreen extends StatefulWidget {
  const CatalogsHomeScreen({super.key});

  @override
  State<CatalogsHomeScreen> createState() => _CatalogsHomeScreenState();
}

class _CatalogsHomeScreenState extends State<CatalogsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingMore = false;

  /// IDs de ventas que están siendo canceladas o eliminadas en este momento.
  final Set<String> _actionLoadingSaleIds = {};
  bool _searchOpen = false;

  static const _tabs = [
    (label: 'Todos', status: null),
    (label: 'Pendiente', status: SaleStatus.pending),
    (label: 'Pagado', status: SaleStatus.paid),
    (label: 'Cancelado', status: SaleStatus.cancelled),
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
    context.read<CatalogProvider>().setStatusFilter(token, status);
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<CatalogProvider>().loadSales(token);
  }

  Future<void> _loadMore() async {
    final token = context.read<AuthProvider>().token ?? '';
    setState(() => _loadingMore = true);
    await context.read<CatalogProvider>().loadMore(token);
    if (mounted) setState(() => _loadingMore = false);
  }

  void _goToCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
    );
  }

  void _goToProducts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductsHomeScreen()),
    );
  }

  void _goToDetail(Sale sale) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id)),
    );
  }

  // ── Búsqueda ─────────────────────────────────────────────────────────────
  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    setState(() => _searchOpen = false);
    context.read<CatalogProvider>().clearSearch();
  }

  void _onSearch(String query) {
    final token = context.read<AuthProvider>().token ?? '';
    context.read<CatalogProvider>().searchSales(token, query);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final safeArea = MediaQuery.of(context).padding;

    return Consumer2<CatalogProvider, AuthProvider>(
      builder: (context, prov, auth, _) {
        final token = auth.token ?? '';

        return Scaffold(
          backgroundColor: c.background,
          body: KolektaSearchBar(
            isOpen: _searchOpen,
            hintText: 'Buscar venta, cliente o producto…',
            onSearch: _onSearch,
            onClose: _closeSearch,
            child: Column(
              children: [
                SizedBox(height: safeArea.top + 16),

                // ── Header ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catálogo',
                              style: AppTextStyles.displayMedium
                                  .copyWith(color: c.textPrimary)),
                          Text('Ventas y cobros',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: c.textSecondary)),
                        ],
                      ),
                      Row(
                        children: [
                          // ── Botón buscar ──────────────────────────────────
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
                          // ── Botón mis productos ────────────────────────────
                          Tooltip(
                            message: 'Mis productos',
                            child: GestureDetector(
                              onTap: _goToProducts,
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.border),
                                ),
                                child: Icon(Icons.inventory_2_outlined,
                                    size: 18, color: c.textSecondary),
                              ),
                            ),
                          ),
                          // ── Botón nueva venta ──────────────────────────────
                          FloatingActionButton(
                            heroTag: 'catalog_fab',
                            onPressed: _goToCreate,
                            backgroundColor: AppColors.green,
                            mini: true,
                            elevation: 4,
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white),
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
                        color: AppColors.greenMedium,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.greenMedium.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Saldo pendiente',
                                    style: AppTextStyles.labelSmall
                                        .copyWith(color: Colors.white70)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _formatMoney(prov.pendingBalance),
                                    style: AppTextStyles.displayMedium.copyWith(
                                        color: Colors.white, fontSize: 30),
                                  ),
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
                                  '${prov.pendingCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800),
                                ),
                                const Text(
                                  'Pendientes',
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
                          color: AppColors.green,
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
                if (_searchOpen)
                  _buildSearchContent()
                else
                  _buildNormalContent(prov, token, c),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Vista de resultados de búsqueda ─────────────────────────────────────
  Widget _buildSearchContent() {
    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.watch<CatalogProvider>();

    return KolektaSearchResults<Sale>(
      query: prov.searchQuery,
      isLoading: prov.searchLoading,
      groups: [
        SearchResultGroup<Sale>(
          label: 'Pendientes',
          items: prov.searchPending,
          total: prov.searchTotalPending,
          hasMore: prov.searchHasMorePending,
        ),
        SearchResultGroup<Sale>(
          label: 'Pagadas',
          items: prov.searchPaid,
          total: prov.searchTotalPaid,
          hasMore: prov.searchHasMorePaid,
        ),
        SearchResultGroup<Sale>(
          label: 'Canceladas',
          items: prov.searchCancelled,
          total: prov.searchTotalCancelled,
          hasMore: prov.searchHasMoreCancelled,
        ),
      ],
      itemBuilder: (sale) => _SaleCard(
        sale: sale,
        isLoading: _actionLoadingSaleIds.contains(sale.id),
        onTap: () => _goToDetail(sale),
        onContextMenu: () => _showContextMenu(context, sale, token),
      ),
      onLoadMore: (groupIndex) => prov.searchLoadMore(token, groupIndex),
      emptyMessage: 'Sin resultados para',
    );
  }

  // ── Vista normal con tabs ───────────────────────────────────────────────
  Widget _buildNormalContent(
      CatalogProvider prov, String token, KolektaColors c) {
    if (prov.loading && prov.sales.isEmpty) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      );
    }

    if (prov.errorMessage != null && prov.sales.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
                const SizedBox(height: 12),
                Text(
                  prov.errorMessage!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.green),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (prov.isEmpty) {
      return Expanded(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/catalog2.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Sin ventas registradas',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: c.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toca + para registrar una venta',
                        style:
                            AppTextStyles.bodySmall.copyWith(color: c.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Todos
          _SaleList(
            sales: prov.sales,
            total: prov.total,
            hasMore: prov.hasMore,
            isLoadingMore: _loadingMore,
            onLoadMore: _loadMore,
            onRefresh: _load,
            onTapSale: _goToDetail,
            onContextMenu: (sale) => _showContextMenu(context, sale, token),
            actionLoadingSaleIds: _actionLoadingSaleIds,
          ),
          // Pendientes
          _SaleList(
            sales: prov.sales
                .where((s) => s.status == SaleStatus.pending)
                .toList(),
            total: prov.total,
            hasMore: prov.hasMore,
            isLoadingMore: _loadingMore,
            onLoadMore: _loadMore,
            onRefresh: _load,
            onTapSale: _goToDetail,
            onContextMenu: (sale) => _showContextMenu(context, sale, token),
            actionLoadingSaleIds: _actionLoadingSaleIds,
          ),
          // Pagadas
          _SaleList(
            sales:
                prov.sales.where((s) => s.status == SaleStatus.paid).toList(),
            total: prov.total,
            hasMore: prov.hasMore,
            isLoadingMore: _loadingMore,
            onLoadMore: _loadMore,
            onRefresh: _load,
            onTapSale: _goToDetail,
            onContextMenu: (sale) => _showContextMenu(context, sale, token),
            actionLoadingSaleIds: _actionLoadingSaleIds,
          ),
          // Canceladas
          _SaleList(
            sales: prov.sales
                .where((s) => s.status == SaleStatus.cancelled)
                .toList(),
            total: prov.total,
            hasMore: prov.hasMore,
            isLoadingMore: _loadingMore,
            onLoadMore: _loadMore,
            onRefresh: _load,
            onTapSale: _goToDetail,
            onContextMenu: (sale) => _showContextMenu(context, sale, token),
            actionLoadingSaleIds: _actionLoadingSaleIds,
          ),
        ],
      ),
    );
  }

  // ── Menú contextual ───────────────────────────────────────────────────────

  void _showContextMenu(BuildContext context, Sale sale, String token) {
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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pedido #${sale.orderNum} · ${sale.clientName}',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: c.textSecondary),
                  ),
                ),
              ),
              Divider(height: 1, color: c.divider),
              _SheetOption(
                icon: Icons.visibility_outlined,
                iconBg: c.primarySurface,
                iconColor: AppColors.primary,
                label: 'Ver detalle',
                onTap: () {
                  Navigator.pop(context);
                  _goToDetail(sale);
                },
              ),
              if (sale.status == SaleStatus.pending)
                _SheetOption(
                  icon: Icons.edit_outlined,
                  iconBg: c.orangeLight,
                  iconColor: AppColors.orange,
                  label: 'Editar venta',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CreateSaleScreen(saleToEdit: sale),
                    ));
                  },
                ),
              if (sale.status == SaleStatus.pending)
                _SheetOption(
                  icon: Icons.cancel_outlined,
                  iconBg: AppColors.statusPending,
                  iconColor: AppColors.statusPendingText,
                  label: 'Cancelar venta',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmCancel(context, sale, token);
                  },
                ),
              _SheetOption(
                icon: Icons.delete_outline_rounded,
                iconBg: AppColors.error.withOpacity(0.1),
                iconColor: AppColors.error,
                label: 'Eliminar venta',
                labelColor: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, sale, token);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, Sale sale, String token) async {
    final c = context.kolekta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar venta',
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
            '¿Cancelar la venta #${sale.orderNum} de ${sale.clientName}? Sus pagos también serán cancelados.',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('No', style: TextStyle(color: c.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar venta',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoadingSaleIds.add(sale.id));
    final prov = context.read<CatalogProvider>();
    final ok = await prov.cancelSale(token, sale.id);
    if (!mounted) return;
    setState(() => _actionLoadingSaleIds.remove(sale.id));
    _showSnack(ok ? 'Venta cancelada' : prov.errorMessage ?? 'Error', ok);
  }

  Future<void> _confirmDelete(
      BuildContext context, Sale sale, String token) async {
    final c = context.kolekta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar venta',
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
            '¿Eliminar permanentemente la venta #${sale.orderNum}? Esta acción no se puede deshacer.',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('No', style: TextStyle(color: c.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoadingSaleIds.add(sale.id));
    final prov = context.read<CatalogProvider>();
    final ok = await prov.deleteSale(token, sale.id);
    if (!mounted) return;
    setState(() => _actionLoadingSaleIds.remove(sale.id));
    _showSnack(ok ? 'Venta eliminada' : prov.errorMessage ?? 'Error', ok);
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.green : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatMoney(double v) {
    final abs = v.abs();
    final formatted = abs.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '\$$formatted';
  }
}

// ─── _SaleList ───────────────────────────────────────────────────────────────

class _SaleList extends StatelessWidget {
  const _SaleList({
    required this.sales,
    required this.total,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onTapSale,
    required this.onContextMenu,
    required this.actionLoadingSaleIds,
  });

  final List<Sale> sales;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final void Function(Sale) onTapSale;
  final void Function(Sale) onContextMenu;
  final Set<String> actionLoadingSaleIds;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return RefreshIndicator(
        color: AppColors.green,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/catalog2.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Sin ventas en esta categoría',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: context.kolekta.textSecondary),
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

    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: sales.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i < sales.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SaleCard(
                sale: sales[i],
                isLoading: actionLoadingSaleIds.contains(sales[i].id),
                onTap: () => onTapSale(sales[i]),
                onContextMenu: () => onContextMenu(sales[i]),
              ),
            );
          }
          return KolektaPagination(
            loaded: sales.length,
            total: total,
            hasMore: hasMore,
            isLoading: isLoadingMore,
            onLoadMore: onLoadMore,
          );
        },
      ),
    );
  }
}

// ─── _SaleCard ────────────────────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.isLoading,
    required this.onTap,
    required this.onContextMenu,
  });

  final Sale sale;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Stack(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          onLongPress: isLoading ? null : onContextMenu,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.greenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${sale.orderNum}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SaleStatusBadge(status: sale.status),
                    const Spacer(),
                    // Indicador de número de productos
                    if (sale.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 11, color: c.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${sale.items.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(sale.title,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: c.textHint),
                    const SizedBox(width: 4),
                    Text(sale.clientName,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: c.divider),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AmountItem(
                      label: 'Total',
                      value: _fmt(sale.totalAmount),
                      color: c.textPrimary,
                    ),
                    _AmountItem(
                      label: 'Cobrado',
                      value: _fmt(sale.collected),
                      color: AppColors.green,
                    ),
                    _AmountItem(
                      label: 'Saldo',
                      value: _fmt(sale.balance),
                      color:
                          sale.balance > 0 ? AppColors.orange : AppColors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ── Overlay de carga (mismo patrón que _BatchCard) ──────────────────
        if (isLoading)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.green),
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

  String _fmt(double v) {
    return '\$${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

class _AmountItem extends StatelessWidget {
  const _AmountItem(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

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
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─── _SaleStatusBadge ─────────────────────────────────────────────────────────

class _SaleStatusBadge extends StatelessWidget {
  const _SaleStatusBadge({required this.status});
  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    Color bg;
    Color textColor;

    switch (status) {
      case SaleStatus.pending:
        bg = AppColors.statusPending;
        textColor = AppColors.statusPendingText;
        break;
      case SaleStatus.paid:
        bg = c.successLight;
        textColor = AppColors.success;
        break;
      case SaleStatus.cancelled:
        bg = c.divider;
        textColor = c.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(status.label,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── _SheetOption ─────────────────────────────────────────────────────────────

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
