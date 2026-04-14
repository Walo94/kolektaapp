import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/catalog_service.dart';
import 'create_payment_screen.dart';
import 'create_sale_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token ?? '';
    await context
        .read<CatalogProvider>()
        .loadSaleDetail(token, widget.saleId);
  }

  // ── Compartir comprobante PDF ─────────────────────────────────────────────

  Future<void> _shareReceipt(SalePayment payment) async {
    final token = context.read<AuthProvider>().token ?? '';
    try {
      _showSnack('Generando comprobante…', isInfo: true);
      final bytes = await CatalogService.getPaymentReceiptPdf(
        token: token,
        paymentId: payment.id,
      );

      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/comprobante_pago_${payment.id.substring(0, 8)}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Comprobante de pago',
        text:
            'Comprobante de pago por \$${payment.amount.toStringAsFixed(2)} del ${DateFormat('dd/MM/yyyy').format(payment.date)}',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al generar el comprobante', isInfo: false);
    }
  }

  // ── Cancelar pago ─────────────────────────────────────────────────────────

  Future<void> _confirmCancelPayment(SalePayment payment) async {
    final c = context.kolekta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar pago',
            style:
                AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
          'El monto de \$${payment.amount.toStringAsFixed(2)} será devuelto al saldo pendiente.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('No', style: TextStyle(color: c.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar pago',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().token ?? '';
    final prov  = context.read<CatalogProvider>();
    final ok = await prov.cancelPayment(
      token: token,
      paymentId: payment.id,
      saleId: widget.saleId,
    );
    if (!mounted) return;
    _showSnack(
        ok ? 'Pago cancelado' : prov.errorMessage ?? 'Error',
        isInfo: ok);
  }

  // ── Eliminar pago ─────────────────────────────────────────────────────────

  Future<void> _confirmDeletePayment(SalePayment payment) async {
    final c = context.kolekta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar pago',
            style:
                AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Eliminar permanentemente este pago? El monto regresará al saldo pendiente.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
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

    final token = context.read<AuthProvider>().token ?? '';
    final prov  = context.read<CatalogProvider>();
    final ok = await prov.deletePayment(
      token: token,
      paymentId: payment.id,
      saleId: widget.saleId,
    );
    if (!mounted) return;
    _showSnack(
        ok ? 'Pago eliminado' : prov.errorMessage ?? 'Error',
        isInfo: ok);
  }

  void _showSnack(String msg, {required bool isInfo}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isInfo ? AppColors.green : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Consumer2<CatalogProvider, AuthProvider>(
      builder: (context, prov, auth, _) {
        final sale  = prov.selectedSale;

        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: c.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: c.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              sale != null ? 'Pedido #${sale.orderNum}' : 'Detalle',
              style: AppTextStyles.headingSmall
                  .copyWith(color: c.textPrimary),
            ),
            centerTitle: true,
            actions: [
              if (sale != null &&
                  sale.status == SaleStatus.pending)
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: c.textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateSaleScreen(saleToEdit: sale),
                    ),
                  ),
                ),
            ],
          ),
          body: prov.actionLoading && sale == null
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.green))
              : sale == null
                  ? Center(
                      child: Text('Venta no encontrada',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: c.textSecondary)))
                  : RefreshIndicator(
                      color: AppColors.green,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          // ── Encabezado de la venta ──────────────────
                          _SaleHeader(sale: sale),
                          const SizedBox(height: 16),

                          // ── Barra de progreso de cobro ──────────────
                          _PaymentProgress(sale: sale),
                          const SizedBox(height: 20),

                          // ── Detalles ────────────────────────────────
                          _SaleInfoCard(sale: sale),
                          const SizedBox(height: 20),

                          // ── Botón registrar pago ────────────────────
                          if (sale.status == SaleStatus.pending)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result =
                                    await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreatePaymentScreen(sale: sale),
                                  ),
                                );
                                if (result == true) await _load();
                              },
                              icon: const Icon(Icons.add_rounded,
                                  size: 18),
                              label: const Text('Registrar pago'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),

                          const SizedBox(height: 20),

                          // ── Historial de pagos ──────────────────────
                          Text('Historial de pagos',
                              style: AppTextStyles.headingSmall
                                  .copyWith(color: c.textPrimary)),
                          const SizedBox(height: 12),

                          if (sale.payments.isEmpty)
                            _EmptyPayments()
                          else
                            ...sale.payments.map(
                              (p) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: _PaymentTile(
                                  payment: p,
                                  onShare: () => _shareReceipt(p),
                                  onCancel: p.status ==
                                          PaymentStatus.paid
                                      ? () => _confirmCancelPayment(p)
                                      : null,
                                  onDelete: () =>
                                      _confirmDeletePayment(p),
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _SaleHeader extends StatelessWidget {
  const _SaleHeader({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: c.greenLight,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.shopping_bag_outlined,
                color: AppColors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.title,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                Text(sale.clientName,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary)),
                const SizedBox(height: 4),
                _SaleStatusChip(status: sale.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleStatusChip extends StatelessWidget {
  const _SaleStatusChip({required this.status});
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor)),
    );
  }
}

class _PaymentProgress extends StatelessWidget {
  const _PaymentProgress({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final progress =
        sale.totalAmount > 0 ? sale.collected / sale.totalAmount : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progreso de cobro',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: c.textSecondary)),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: c.divider,
              color: AppColors.green,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressStat(
                label: 'Total',
                value: '\$${sale.totalAmount.toStringAsFixed(2)}',
                color: c.textPrimary,
              ),
              _ProgressStat(
                label: 'Cobrado',
                value: '\$${sale.collected.toStringAsFixed(2)}',
                color: AppColors.green,
              ),
              _ProgressStat(
                label: 'Pendiente',
                value: '\$${sale.balance.toStringAsFixed(2)}',
                color:
                    sale.balance > 0 ? AppColors.orange : AppColors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(color: c.textHint)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _SaleInfoCard extends StatelessWidget {
  const _SaleInfoCard({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Información',
              style: AppTextStyles.labelMedium
                  .copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.notes_rounded, label: 'Descripción',
              value: sale.description),
          Divider(height: 16, color: c.divider),
          _InfoRow(icon: Icons.calendar_today_outlined, label: 'Fecha',
              value: sale.date),
          if (sale.clientPhone != null) ...[
            Divider(height: 16, color: c.divider),
            _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono',
                value: sale.clientPhone!),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c.textHint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: c.textHint)),
              Text(value,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: c.textHint),
          const SizedBox(height: 8),
          Text('Sin pagos registrados',
              style: AppTextStyles.labelMedium
                  .copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.onShare,
    this.onCancel,
    required this.onDelete,
  });

  final SalePayment payment;
  final VoidCallback onShare;
  final VoidCallback? onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final isCancelled = payment.status == PaymentStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancelled ? c.divider : c.border,
        ),
        boxShadow: [
          if (!isCancelled)
            BoxShadow(
                color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCancelled ? c.divider : c.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCancelled
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline_rounded,
              color: isCancelled ? c.textHint : AppColors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${payment.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? c.textHint
                        : AppColors.green,
                    decoration: isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(payment.date),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: c.textHint),
                ),
                if (isCancelled)
                  Text('Cancelado',
                      style: TextStyle(
                          fontSize: 10,
                          color: c.textHint,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Acciones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compartir comprobante (solo pagos activos)
              if (!isCancelled)
                _ActionIcon(
                  icon: Icons.share_rounded,
                  color: AppColors.primary,
                  onTap: onShare,
                  tooltip: 'Compartir comprobante',
                ),
              // Cancelar
              if (onCancel != null)
                _ActionIcon(
                  icon: Icons.block_rounded,
                  color: AppColors.orange,
                  onTap: onCancel!,
                  tooltip: 'Cancelar pago',
                ),
              // Eliminar
              _ActionIcon(
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                onTap: onDelete,
                tooltip: 'Eliminar pago',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}