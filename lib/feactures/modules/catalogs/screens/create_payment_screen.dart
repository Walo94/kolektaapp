import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_button.dart';
import '../../../../shared/widgets/kolekta_text_field.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/catalog_service.dart';

class CreatePaymentScreen extends StatefulWidget {
  const CreatePaymentScreen({super.key, required this.sale});

  final Sale sale;

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token  = context.read<AuthProvider>().token ?? '';
    final prov   = context.read<CatalogProvider>();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

    final ok = await prov.createPayment(
      token: token,
      saleId: widget.sale.id,
      amount: amount,
      date: _selectedDate,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(prov.errorMessage ?? 'Error al registrar el pago'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.kolekta;
    final loading = context.watch<CatalogProvider>().actionLoading;
    final balance = widget.sale.balance;
    // Detectar modo oscuro para adaptar el card de resumen
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Registrar pago',
            style:
                AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Resumen de la venta ──────────────────────────────────────
            // En modo claro usa fondo verde sólido (greenMedium) para que
            // los textos blancos tengan suficiente contraste.
            // En modo oscuro usa el greenLight semitransparente del tema.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? c.greenLight : AppColors.greenMedium,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sale.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark ? AppColors.green : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pedido #${widget.sale.orderNum} · ${widget.sale.clientName}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? c.textSecondary
                          : Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InfoChip(
                        label: 'Total',
                        value: '\$${widget.sale.totalAmount.toStringAsFixed(2)}',
                        isDark: isDark,
                      ),
                      _InfoChip(
                        label: 'Saldo pendiente',
                        value: '\$${balance.toStringAsFixed(2)}',
                        highlight: true,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Monto del pago',
                style: AppTextStyles.labelMedium
                    .copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            KolektaTextField(
              controller: _amountCtrl,
              hint: 'Monto a registrar *',
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
                if (n > balance) {
                  return 'El monto no puede exceder el saldo (\$${balance.toStringAsFixed(2)})';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            Text('Fecha del pago',
                style: AppTextStyles.labelMedium
                    .copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
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
                    Icon(Icons.chevron_right_rounded,
                        color: c.textHint, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            KolektaButton(
              label: 'Registrar pago',
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.isDark,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // En modo claro el fondo es verde oscuro → texto blanco con buen contraste.
    // En modo oscuro el fondo es verde oscuro del tema → mismo comportamiento.
    final labelColor = isDark
        ? Colors.white60
        : Colors.white.withOpacity(0.8);
    final valueColor = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: labelColor,
                fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}