import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/batch_provider.dart';
import '../../services/batch_service.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<BatchProvider>().loadBatchDetail(token, widget.batchId);
  }

  Future<void> _handleDelivery(BatchDetail detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = context.kolekta;
        return AlertDialog(
          backgroundColor: c.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Registrar entrega',
              style: AppTextStyles.headingMedium
                  .copyWith(color: c.textPrimary)),
          content: Text(
            '¿Confirmas la entrega del turno #${detail.assignedNumber} a ${detail.contactName}?\n\nMonto: \$${NumberFormat('#,##0', 'es').format(detail.payoutAmount)}',
            style:
                AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Confirmar',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final token = context.read<AuthProvider>().token!;
    final success = await context.read<BatchProvider>().registerDelivery(
          token: token,
          batchId: widget.batchId,
          detailId: detail.id,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? '✅ Entrega registrada correctamente'
          : context.read<BatchProvider>().errorMessage ??
              'Error al registrar'),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      return DateFormat('d MMM yyyy', 'es').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final batchProvider = context.watch<BatchProvider>();
    final batch = batchProvider.selectedBatch;

    if (batchProvider.loading || batch == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress =
        batch.totalSlots > 0 ? batch.currentTurn / batch.totalSlots : 0.0;
    final sortedDetails = [...batch.details]
      ..sort((a, b) => a.assignedNumber.compareTo(b.assignedNumber));

    final pendingCount = sortedDetails
        .where((d) => d.status == BatchDetailStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar con imagen o fondo degradado ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Fondo: imagen de Cloudinary o degradado ──
                  if (batch.coverImage != null)
                    CachedNetworkImage(
                      imageUrl: batch.coverImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                  // ── Overlay oscuro para garantizar legibilidad del texto ──
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(
                              batch.coverImage != null ? 0.55 : 0.0),
                        ],
                      ),
                    ),
                  ),

                  // ── Texto del header ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          batch.name,
                          style: AppTextStyles.headingLarge
                              .copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Chip(
                                label: batch.frequency.label,
                                icon: Icons.repeat_rounded),
                            const SizedBox(width: 8),
                            _Chip(
                                label: '${batch.totalSlots} números',
                                icon: Icons.people_rounded),
                            const SizedBox(width: 8),
                            _Chip(
                              label: batch.status.label,
                              icon: batch.status == BatchStatus.active
                                  ? Icons.circle
                                  : Icons.check_circle_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Resumen ───────────────────────────
                  Container(
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
                            _InfoItem(
                              label: 'Aportación',
                              value:
                                  '\$${NumberFormat('#,##0', 'es').format(batch.entryPrice)}',
                              color: AppColors.primary,
                            ),
                            _InfoItem(
                              label: 'Pago',
                              value:
                                  '\$${NumberFormat('#,##0', 'es').format(batch.payoutAmount)}',
                              color: AppColors.success,
                            ),
                            _InfoItem(
                              label: 'Turno actual',
                              value:
                                  '${batch.currentTurn}/${batch.totalSlots}',
                              color: AppColors.purple,
                            ),
                            _InfoItem(
                              label: 'Pendientes',
                              value: '$pendingCount',
                              color: AppColors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: c.divider,
                                  color: AppColors.primary,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (batch.nextDeliveryDate != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.event_rounded,
                                  size: 16, color: AppColors.orange),
                              const SizedBox(width: 6),
                              Text(
                                'Próxima entrega: ${_formatDate(batch.nextDeliveryDate)}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.orange),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text('Participantes',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    'Ordenados por número de cobro. El #1 cobra primero.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Lista de participantes ─────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final detail = sortedDetails[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _DetailRow(
                    detail: detail,
                    batchStatus: batch.status,
                    currentTurn: batch.currentTurn,
                    formatDate: _formatDate,
                    onDeliver: () => _handleDelivery(detail),
                  ),
                );
              },
              childCount: sortedDetails.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Fila de un participante ───────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.detail,
    required this.batchStatus,
    required this.currentTurn,
    required this.formatDate,
    required this.onDeliver,
  });

  final BatchDetail detail;
  final BatchStatus batchStatus;
  final int currentTurn;
  final String Function(String?) formatDate;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final isDelivered = detail.status == BatchDetailStatus.delivered;
    final isCurrent = detail.assignedNumber == currentTurn + 1 &&
        batchStatus == BatchStatus.active;
    final isEmpty = detail.contactName.isEmpty;

    Color rowColor;
    Color numberColor;
    if (isDelivered) {
      rowColor = c.successLight;
      numberColor = AppColors.success;
    } else if (isCurrent) {
      rowColor = AppColors.primarySurface;
      numberColor = AppColors.primary;
    } else {
      rowColor = c.surface;
      numberColor = c.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withOpacity(0.4)
              : isDelivered
                  ? AppColors.success.withOpacity(0.3)
                  : c.border,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ── Número ───────────────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDelivered
                  ? AppColors.success
                  : isCurrent
                      ? AppColors.primary
                      : c.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDelivered
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20)
                  : Text(
                      '${detail.assignedNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isCurrent ? Colors.white : numberColor,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Info (Expanded para evitar overflow) ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nombre + badge "Turno actual" ─────────
                // Se usa Row con Flexible para que el nombre se trunca
                // antes de que el badge provoque overflow.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isEmpty ? 'Lugar disponible' : detail.contactName,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isEmpty ? c.textHint : c.textPrimary,
                          fontStyle: isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        // maxLines + overflow evitan el desbordamiento
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Turno actual',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Fecha + teléfono ──────────────────────
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: c.textHint),
                    const SizedBox(width: 4),
                    Text(formatDate(detail.deliveryDate),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: c.textHint)),
                    if (detail.phone != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_outlined,
                          size: 12, color: c.textHint),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          detail.phone!,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: c.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Monto ─────────────────────────────────
                Text(
                  '\$${NumberFormat('#,##0', 'es').format(detail.payoutAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDelivered
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // ── Acción ──────────────────────────────────
          if (isCurrent && !isEmpty)
            IconButton(
              onPressed: onDeliver,
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.primary),
              tooltip: 'Registrar entrega',
            )
          else if (isDelivered)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem(
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}