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
import '../../services/catalog_service.dart';

class CreateSaleScreen extends StatefulWidget {
  const CreateSaleScreen({super.key, this.saleToEdit});

  /// Si se pasa una venta, el screen funciona en modo edición.
  final Sale? saleToEdit;

  @override
  State<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends State<CreateSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameCtrl  = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _amountCtrl      = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  bool get _isEdit => widget.saleToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.saleToEdit!;
      _clientNameCtrl.text  = s.clientName;
      _clientPhoneCtrl.text = s.clientPhone ?? '';
      _titleCtrl.text       = s.title;
      _descCtrl.text        = s.description;
      _amountCtrl.text      = s.totalAmount.toStringAsFixed(2);
      _selectedDate = DateTime.tryParse(s.date) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
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

      // Cargar detalles completos (incluye teléfonos)
      final full = await FlutterContacts.getContact(contact.id);
      if (full == null) return;

      final name  = full.displayName;
      final phone = full.phones.isNotEmpty
          ? full.phones.first.number.replaceAll(RegExp(r'\s+'), '')
          : null;

      setState(() {
        _clientNameCtrl.text = name;
        if (phone != null) _clientPhoneCtrl.text = phone;
      });
    } catch (_) {
      // El usuario canceló la selección — no hacer nada
    }
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
          colorScheme:
              ColorScheme.light(primary: AppColors.green),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Guardar / crear venta ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token   = context.read<AuthProvider>().token ?? '';
    final prov    = context.read<CatalogProvider>();
    final amount  = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    bool ok;

    if (_isEdit) {
      ok = await prov.updateSale(
        token: token,
        id: widget.saleToEdit!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim().isEmpty
            ? null
            : _clientPhoneCtrl.text.trim(),
        totalAmount: amount,
      );
    } else {
      final created = await prov.createSale(
        token: token,
        clientName: _clientNameCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim().isEmpty
            ? null
            : _clientPhoneCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        totalAmount: amount,
        date: dateStr,
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
    final c       = context.kolekta;
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
          style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
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
                // Botón de selección de contacto (solo al crear, no al editar)
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
            // Campo nombre con icono de contacto al final cuando no está en edición
            KolektaTextField(
              controller: _clientNameCtrl,
              hint: 'Nombre del cliente *',
              prefixIcon: Icons.person_outline_rounded,
              enabled: !_isEdit, // no se edita el cliente
              // Icono de contacto dentro del campo para acceso rápido
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

            // ── Venta ────────────────────────────────────────────────────
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
            const SizedBox(height: 10),
            KolektaTextField(
              controller: _descCtrl,
              hint: 'Descripción de lo vendido *',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Ingresa una descripción' : null,
            ),
            const SizedBox(height: 10),
            KolektaTextField(
              controller: _amountCtrl,
              hint: 'Monto total *',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (v) {
                final n = double.tryParse(v?.replaceAll(',', '') ?? '');
                if (n == null || n <= 0) return 'Ingresa un monto válido';
                return null;
              },
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