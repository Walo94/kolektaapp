import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_button.dart';
import '../../../../shared/widgets/kolekta_text_field.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/product_service.dart' show Product;
import '../../services/catalog_service.dart';
import 'product_picker_screen.dart';

class CreateSaleScreen extends StatefulWidget {
  const CreateSaleScreen({super.key, this.saleToEdit});

  /// Si se pasa una venta, el screen funciona en modo edición.
  final Sale? saleToEdit;

  @override
  State<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends State<CreateSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<SelectedSaleItem> _items = [];

  bool get _isEdit => widget.saleToEdit != null;

  double get _totalAmount =>
      _items.fold(0.0, (sum, i) => sum + i.subtotal);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.saleToEdit!;
      _clientNameCtrl.text = s.clientName;
      _clientPhoneCtrl.text = s.clientPhone ?? '';
      _titleCtrl.text = s.title;
      _selectedDate = DateTime.tryParse(s.date) ?? DateTime.now();

      // Cargar items existentes desde los snapshots de la venta
      if (s.items.isNotEmpty) {
        _items = s.items
            .map((item) => SelectedSaleItem(
                  productId: item.productId,
                  productName: item.productName,
                  unitPrice: item.unitPrice,
                  quantity: item.quantity,
                  isFree: item.productId == null,
                ))
            .toList();
      }
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Selector de contacto ─────────────────────────────────────────────────

  Future<void> _pickContact() async {
    final status = await Permission.contacts.request();

    if (!status.isGranted) {
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de contactos requerido'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      final full = await FlutterContacts.getContact(contact.id);
      if (full == null) return;

      final name = full.displayName;
      final phone = full.phones.isNotEmpty
          ? full.phones.first.number.replaceAll(RegExp(r'\s+'), '')
          : null;

      setState(() {
        _clientNameCtrl.text = name;
        if (phone != null) _clientPhoneCtrl.text = phone;
      });
    } catch (_) {}
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso de contactos requerido'),
        content: const Text(
          'El permiso fue denegado permanentemente. '
          'Habilítalo desde Ajustes → Aplicaciones → Kolekta → Permisos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  // ── Selector de fecha ────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.green),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Abrir picker de productos ────────────────────────────────────────────

  Future<void> _pickProducts() async {
    final result = await Navigator.of(context).push<List<SelectedSaleItem>>(
      MaterialPageRoute(
        builder: (_) => ProductPickerScreen(initialItems: List.from(_items)),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _items = result);
    }
  }

  // ── Guardar / crear venta ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Agrega al menos un producto a la venta'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.read<CatalogProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final itemInputs = _items.map((i) => i.toItemInput()).toList();

    bool ok;

    if (_isEdit) {
      ok = await prov.updateSale(
        token: token,
        id: widget.saleToEdit!.id,
        title: _titleCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim().isEmpty
            ? null
            : _clientPhoneCtrl.text.trim(),
        items: itemInputs,
      );
    } else {
      final created = await prov.createSale(
        token: token,
        clientName: _clientNameCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim().isEmpty
            ? null
            : _clientPhoneCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        date: dateStr,
        items: itemInputs,
      );
      ok = created != null;
    }

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(prov.errorMessage ?? 'Error al guardar'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final loading = context.watch<CatalogProvider>().actionLoading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Editar venta' : 'Nueva venta',
          style:
              AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Cliente ──────────────────────────────────────────────────
            Row(
              children: [
                Text('Cliente',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: c.textSecondary)),
                const Spacer(),
                if (!_isEdit)
                  TextButton.icon(
                    onPressed: _pickContact,
                    icon: Icon(Icons.person_search_rounded,
                        size: 16, color: AppColors.green),
                    label: Text('Desde contactos',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.green)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            KolektaTextField(
              controller: _clientNameCtrl,
              hint: 'Nombre del cliente *',
              prefixIcon: Icons.person_outline_rounded,
              enabled: !_isEdit,
              suffixIcon: !_isEdit
                  ? IconButton(
                      icon: Icon(Icons.contacts_outlined,
                          color: AppColors.green, size: 20),
                      tooltip: 'Seleccionar contacto',
                      onPressed: _pickContact,
                    )
                  : null,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Ingresa el nombre del cliente' : null,
            ),
            const SizedBox(height: 10),
            KolektaTextField(
              controller: _clientPhoneCtrl,
              hint: 'Teléfono (opcional)',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),

            // ── Datos de la venta ────────────────────────────────────────
            Text('Venta',
                style: AppTextStyles.labelMedium
                    .copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            KolektaTextField(
              controller: _titleCtrl,
              hint: 'Título de la venta *',
              prefixIcon: Icons.label_outline_rounded,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Ingresa un título' : null,
            ),

            const SizedBox(height: 20),

            // ── Fecha ────────────────────────────────────────────────────
            Text('Fecha de la venta',
                style: AppTextStyles.labelMedium
                    .copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isEdit ? null : _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: c.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: c.textPrimary),
                    ),
                    const Spacer(),
                    if (!_isEdit)
                      Icon(Icons.chevron_right_rounded,
                          color: c.textHint, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Productos ────────────────────────────────────────────────
            Row(
              children: [
                Text('Productos',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: c.textSecondary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickProducts,
                  icon: Icon(Icons.add_rounded,
                      size: 16, color: AppColors.green),
                  label: Text(
                    _items.isEmpty ? 'Agregar' : 'Editar',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.green),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              // Placeholder vacío
              GestureDetector(
                onTap: _pickProducts,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 36, color: c.textHint),
                      const SizedBox(height: 8),
                      Text('Sin productos agregados',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: c.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Toca para buscar en tu catálogo',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textHint)),
                    ],
                  ),
                ),
              )
            else ...[
              // Lista de productos seleccionados
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    ..._items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isLast = i == _items.length - 1;
                      final products =
                          context.read<ProductProvider>().products;
                      final liveProduct = item.productId != null
                          ? products
                              .where((p) => p.id == item.productId)
                              .firstOrNull
                          : null;

                      return Column(
                        children: [
                          _SaleItemRow(
                            item: item,
                            liveImageUrl: liveProduct?.imageUrl,
                            onRemove: () =>
                                setState(() => _items.removeAt(i)),
                            onQuantityChanged: (q) {
                              if (q <= 0) {
                                setState(() => _items.removeAt(i));
                              } else {
                                setState(() => _items[i].quantity = q);
                              }
                            },
                          ),
                          if (!isLast) Divider(height: 1, color: c.divider),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Total
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: c.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total de la venta',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.green)),
                    Text(
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            KolektaButton(
              label: _isEdit ? 'Guardar cambios' : 'Registrar venta',
              onPressed: loading ? null : _submit,
              isLoading: loading,
              color: AppColors.green,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── _SaleItemRow ─────────────────────────────────────────────────────────────

class _SaleItemRow extends StatelessWidget {
  const _SaleItemRow({
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    this.liveImageUrl,
  });

  final SelectedSaleItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  /// URL de la imagen obtenida del producto vivo (null si fue eliminado o es libre)
  final String? liveImageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Imagen del producto vivo; si fue eliminado o es libre, muestra placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: liveImageUrl != null && liveImageUrl!.isNotEmpty
                ? Image.network(
                    liveImageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                    cacheHeight: 120,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _MiniPlaceholder(c: c);
                    },
                    errorBuilder: (_, __, ___) => _MiniPlaceholder(c: c),
                  )
                : _MiniPlaceholder(c: c),
          ),
          const SizedBox(width: 10),
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
                        style: AppTextStyles.labelMedium
                            .copyWith(color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} × ${item.quantity} = \$${item.subtotal.toStringAsFixed(2)}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Controles de cantidad
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: () => onQuantityChanged(item.quantity - 1),
                color: item.quantity == 1 ? AppColors.error : c.textSecondary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('${item.quantity}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: () => onQuantityChanged(item.quantity + 1),
                color: AppColors.green,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPlaceholder extends StatelessWidget {
  const _MiniPlaceholder({required this.c});
  final KolektaColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: c.surfaceVariant,
      child: Icon(Icons.inventory_2_outlined, color: c.textHint, size: 20),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
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
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}