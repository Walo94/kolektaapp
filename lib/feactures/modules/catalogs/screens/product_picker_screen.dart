import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_button.dart';
import '../../../../shared/widgets/kolekta_text_field.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/product_service.dart';

/// Representa un ítem seleccionado para la venta
class SelectedSaleItem {
  final String? productId;
  final String productName;
  final double unitPrice;
  int quantity;
  final String? imageUrl;
  final bool isFree; // producto libre (no registrado)

  SelectedSaleItem({
    this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
    this.imageUrl,
    this.isFree = false,
  });

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toItemInput() => {
        if (productId != null) 'productId': productId,
        if (isFree) 'description': productName,
        if (isFree) 'price': unitPrice,
        'quantity': quantity,
      };
}

/// Screen para buscar y seleccionar productos del catálogo.
/// Retorna [List<SelectedSaleItem>] al hacer pop.
class ProductPickerScreen extends StatefulWidget {
  const ProductPickerScreen({
    super.key,
    this.initialItems = const [],
  });

  /// Ítems ya seleccionados (modo edición)
  final List<SelectedSaleItem> initialItems;

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  final _searchCtrl = TextEditingController();
  final List<SelectedSaleItem> _selected = [];
  bool _showFreeForm = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialItems);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<ProductProvider>().loadProducts(token);
  }

  Future<void> _onSearch(String query) async {
    final token = context.read<AuthProvider>().token ?? '';
    await context.read<ProductProvider>().setSearch(token, query);
  }

  void _addProduct(Product product) {
    final existing = _selected.indexWhere((s) => s.productId == product.id);
    if (existing != -1) {
      setState(() => _selected[existing].quantity++);
    } else {
      setState(() {
        _selected.add(SelectedSaleItem(
          productId: product.id,
          productName: product.description,
          unitPrice: product.price,
          imageUrl: product.imageUrl,
        ));
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _selected.removeAt(index));
  }

  void _updateQuantity(int index, int qty) {
    if (qty <= 0) {
      _removeItem(index);
      return;
    }
    setState(() => _selected[index].quantity = qty);
  }

  void _done() {
    Navigator.of(context).pop(_selected);
  }

  double get _subtotal => _selected.fold(0.0, (sum, s) => sum + s.subtotal);

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(<SelectedSaleItem>[]),
        ),
        title: Text('Seleccionar productos',
            style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
        centerTitle: true,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _done,
              child: Text(
                'Listo (${_selected.length})',
                style: TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Búsqueda ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  Future.delayed(const Duration(milliseconds: 400), () {
                if (_searchCtrl.text == v) _onSearch(v.trim());
              }),
              decoration: InputDecoration(
                hintText: 'Buscar en catálogo…',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: c.textHint),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // ── Seleccionados ─────────────────────────────────────────────────
          if (_selected.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.greenLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 16, color: AppColors.green),
                      const SizedBox(width: 6),
                      Text('Ítems seleccionados',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.green)),
                      const Spacer(),
                      Text(
                        '\$${_subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._selected.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return _SelectedItemRow(
                      item: item,
                      onRemove: () => _removeItem(i),
                      onQuantityChanged: (q) => _updateQuantity(i, q),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Botón producto libre ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showFreeForm = !_showFreeForm),
                icon: Icon(
                  _showFreeForm ? Icons.close : Icons.add_box_outlined,
                  size: 18,
                  color: AppColors.green,
                ),
                label: Text(
                  _showFreeForm
                      ? 'Cancelar producto libre'
                      : 'Agregar producto no registrado',
                  style:
                      AppTextStyles.labelSmall.copyWith(color: AppColors.green),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.green.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // ── Formulario producto libre ───────────────────────────────────────
          if (_showFreeForm)
            _FreeProductForm(
              onAdd: (name, price, qty) {
                setState(() {
                  _selected.add(SelectedSaleItem(
                    productName: name,
                    unitPrice: price,
                    quantity: qty,
                    isFree: true,
                  ));
                  _showFreeForm = false;
                });
              },
              onRegister: (name, price) async {
                // Navega a crear producto con los datos prellenados
                final token = context.read<AuthProvider>().token ?? '';
                final prov = context.read<ProductProvider>();
                final created = await prov.createProduct(
                  token: token,
                  description: name,
                  price: price,
                );
                if (created != null && mounted) {
                  setState(() {
                    _selected.add(SelectedSaleItem(
                      productId: created.id,
                      productName: created.description,
                      unitPrice: created.price,
                      imageUrl: created.imageUrl,
                    ));
                    _showFreeForm = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Producto registrado y agregado'),
                    backgroundColor: AppColors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ));
                }
              },
            ),

          const SizedBox(height: 8),
          Divider(height: 1, color: context.kolekta.divider),

          // ── Catálogo ──────────────────────────────────────────────────────
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, prov, _) {
                if (prov.loading) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.green));
                }

                if (prov.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: c.textHint),
                        const SizedBox(height: 12),
                        Text(
                          prov.searchQuery.isEmpty
                              ? 'Sin productos en tu catálogo'
                              : 'Sin resultados para "${prov.searchQuery}"',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: prov.products.length,
                  itemBuilder: (_, i) {
                    final product = prov.products[i];
                    final selectedIdx =
                        _selected.indexWhere((s) => s.productId == product.id);
                    final isSelected = selectedIdx != -1;

                    return _CatalogProductTile(
                      product: product,
                      isSelected: isSelected,
                      quantity:
                          isSelected ? _selected[selectedIdx].quantity : 0,
                      onAdd: () => _addProduct(product),
                      onRemove:
                          isSelected ? () => _removeItem(selectedIdx) : null,
                      onQuantityChanged: isSelected
                          ? (q) => _updateQuantity(selectedIdx, q)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirmar ${_selected.length} ítem${_selected.length != 1 ? 's' : ''} · \$${_subtotal.toStringAsFixed(2)}',
                    style: AppTextStyles.buttonLarge,
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── _CatalogProductTile ──────────────────────────────────────────────────────

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({
    required this.product,
    required this.isSelected,
    required this.quantity,
    required this.onAdd,
    this.onRemove,
    this.onQuantityChanged,
  });

  final Product product;
  final bool isSelected;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? c.greenLight : c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.green.withOpacity(0.4) : c.border,
        ),
      ),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: c.surfaceVariant,
                      child: Icon(Icons.inventory_2_outlined,
                          color: c.textHint, size: 22),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: c.surfaceVariant,
                    child: Icon(Icons.inventory_2_outlined,
                        color: c.textHint, size: 22),
                  ),
          ),
          const SizedBox(width: 10),
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
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          // Control de cantidad o botón agregar
          if (!isSelected)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onTap: () => onQuantityChanged?.call(quantity - 1),
                  color: AppColors.error,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$quantity',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onTap: () => onQuantityChanged?.call(quantity + 1),
                  color: AppColors.green,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── _SelectedItemRow ─────────────────────────────────────────────────────────

class _SelectedItemRow extends StatelessWidget {
  const _SelectedItemRow({
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final SelectedSaleItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.isFree)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('libre',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700)),
                      ),
                    Flexible(
                      child: Text(
                        item.productName,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} × ${item.quantity} = \$${item.subtotal.toStringAsFixed(2)}',
                  style:
                      AppTextStyles.labelSmall.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                icon: Icons.remove_rounded,
                onTap: () => onQuantityChanged(item.quantity - 1),
                color: AppColors.error,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
              ),
              _QtyButton(
                icon: Icons.add_rounded,
                onTap: () => onQuantityChanged(item.quantity + 1),
                color: AppColors.green,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child:
                    Icon(Icons.close_rounded, size: 18, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── _FreeProductForm ─────────────────────────────────────────────────────────

class _FreeProductForm extends StatefulWidget {
  const _FreeProductForm({
    required this.onAdd,
    required this.onRegister,
  });

  final void Function(String name, double price, int qty) onAdd;
  final Future<void> Function(String name, double price) onRegister;

  @override
  State<_FreeProductForm> createState() => _FreeProductFormState();
}

class _FreeProductFormState extends State<_FreeProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  bool _registering = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Producto no registrado',
              style:
                  AppTextStyles.labelMedium.copyWith(color: AppColors.orange),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDec(c, 'Nombre del producto *'),
              style: AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
              validator: (v) => v!.trim().isEmpty ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: _inputDec(c, 'Precio *'),
                    style:
                        AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Precio inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDec(c, 'Cantidad *'),
                    style:
                        AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Mín. 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _registering
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) return;
                            widget.onAdd(
                              _nameCtrl.text.trim(),
                              double.parse(_priceCtrl.text),
                              int.parse(_qtyCtrl.text),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Solo agregar',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: c.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _registering
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _registering = true);
                            await widget.onRegister(
                              _nameCtrl.text.trim(),
                              double.parse(_priceCtrl.text),
                            );
                            if (mounted) {
                              setState(() => _registering = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _registering
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Registrar',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(KolektaColors c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: c.textHint),
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      );
}