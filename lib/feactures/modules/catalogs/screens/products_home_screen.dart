import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_pagination.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/product_service.dart';
import 'product_form_screen.dart';

class ProductsHomeScreen extends StatefulWidget {
  const ProductsHomeScreen({super.key});

  @override
  State<ProductsHomeScreen> createState() => _ProductsHomeScreenState();
}

class _ProductsHomeScreenState extends State<ProductsHomeScreen> {
  final _searchCtrl = TextEditingController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sesión activa')),
        );
      }
      return;
    }
    try {
      await context.read<ProductProvider>().loadProducts(token);
    } catch (e, stack) {
      debugPrint('Error cargando productos: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) return;
    setState(() => _loadingMore = true);
    await context.read<ProductProvider>().loadMore(token);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _onSearch(String query) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) return;
    await context.read<ProductProvider>().setSearch(token, query);
  }

  void _goToCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
  }

  void _goToEdit(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProductFormScreen(productToEdit: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final safeArea = MediaQuery.of(context).padding;

    return Consumer2<ProductProvider, AuthProvider>(
      builder: (context, prov, auth, _) {
        final token = auth.token ?? '';

        return Scaffold(
          backgroundColor: c.background,
          body: Column(
            children: [
              SizedBox(height: safeArea.top + 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          color: c.textPrimary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mis productos',
                              style: AppTextStyles.displayMedium
                                  .copyWith(color: c.textPrimary)),
                          Text('${prov.total} registrados',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'products_fab',
                      onPressed: _goToCreate,
                      backgroundColor: AppColors.green,
                      mini: true,
                      elevation: 4,
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Buscador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => Future.delayed(
                    const Duration(milliseconds: 400),
                    () {
                      if (_searchCtrl.text == v) _onSearch(v.trim());
                    },
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto…',
                    hintStyle:
                        AppTextStyles.bodySmall.copyWith(color: c.textHint),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: c.textHint, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: c.textHint, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: c.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.green, width: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Lista
              Expanded(child: _buildList(context, prov, token, c)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    ProductProvider prov,
    String token,
    KolektaColors c,
  ) {
    if (prov.loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.green));
    }

    if (prov.errorMessage != null && prov.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: c.textHint),
            const SizedBox(height: 12),
            Text(prov.errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
            ),
          ],
        ),
      );
    }

    if (prov.isEmpty) {
      return RefreshIndicator(
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
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: c.textHint),
                    const SizedBox(height: 16),
                    Text(
                      prov.searchQuery.isEmpty
                          ? 'Sin productos registrados'
                          : 'Sin resultados para "${prov.searchQuery}"',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (prov.searchQuery.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Toca + para agregar un producto',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textHint),
                        ),
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
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: prov.products.length + 1,
        itemBuilder: (_, i) {
          if (i < prov.products.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProductCard(
                product: prov.products[i],
                onEdit: () => _goToEdit(prov.products[i]),
                onDelete: () async {
                  final token = context.read<AuthProvider>().token ?? '';
                  await context
                      .read<ProductProvider>()
                      .deleteProduct(token, prov.products[i].id);
                },
              ),
            );
          }
          return KolektaPagination(
            loaded: prov.products.length,
            total: prov.total,
            hasMore: prov.hasMore,
            isLoading: _loadingMore,
            onLoadMore: _loadMore,
          );
        },
      ),
    );
  }
}

// ─── _ProductCard ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  // ── Menú contextual (bottom sheet) ────────────────────────────────────────
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill decorativo
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Nombre del producto
              Text(
                product.description,
                style:
                    AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'en_US', symbol: '\$')
                    .format(product.price),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 16),

              // ── Editar ──────────────────────────────────
              _SheetOption(
                icon: Icons.edit_outlined,
                iconBg: AppColors.primarySurface,
                iconColor: AppColors.primary,
                label: 'Editar producto',
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),

              const Divider(height: 24),

              // ── Eliminar ────────────────────────────────
              _SheetOption(
                icon: Icons.delete_outline_rounded,
                iconBg: AppColors.statusPending,
                iconColor: AppColors.error,
                label: 'Eliminar producto',
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
    );
  }

  // ── Diálogo de confirmación de borrado ────────────────────────────────────
  void _confirmDelete(BuildContext context) {
    final c = context.kolekta;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar producto',
          style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
        ),
        content: Text(
          '¿Seguro que deseas eliminar "${product.description}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'No, volver',
              style:
                  AppTextStyles.buttonMedium.copyWith(color: c.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Sí, eliminar',
              style: AppTextStyles.buttonMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? _SafeNetworkImage(
                      imageUrl: product.imageUrl!,
                      width: 58,
                      height: 58,
                      c: c,
                    )
                  : _ImagePlaceholder(c: c),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.description,
                    style:
                        AppTextStyles.labelLarge.copyWith(color: c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(product.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Botón de menú contextual
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: c.textHint, size: 20),
              onPressed: () => _showContextMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _SheetOption ──────────────────────────────────────────────────────────────

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
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        label,
        style: AppTextStyles.labelLarge
            .copyWith(color: labelColor ?? c.textPrimary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textHint),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ─── Widgets de imagen ─────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  final KolektaColors c;
  const _ImagePlaceholder({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      color: c.surfaceVariant,
      child: Icon(Icons.inventory_2_outlined, color: c.textHint, size: 26),
    );
  }
}

class _SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final KolektaColors c;

  const _SafeNetworkImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: 200,
      cacheHeight: 200,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: c.surfaceVariant,
          child: const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.green),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error en imagen de producto: $error');
        return Container(
          width: width,
          height: height,
          color: c.surfaceVariant,
          child: Icon(Icons.broken_image_outlined, color: c.textHint, size: 24),
        );
      },
    );
  }
}
