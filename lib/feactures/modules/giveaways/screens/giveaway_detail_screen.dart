import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/giveaway_provider.dart';
import '../../services/giveaway_service.dart';
import 'create_giveaway_screen.dart';

class GiveawayDetailScreen extends StatefulWidget {
  const GiveawayDetailScreen({super.key, required this.giveawayId});
  final String giveawayId;

  @override
  State<GiveawayDetailScreen> createState() => _GiveawayDetailScreenState();
}

class _GiveawayDetailScreenState extends State<GiveawayDetailScreen>
    with TickerProviderStateMixin {
  late TabController _innerTab;

  // ── Animación del sorteo ──────────────────────────────────────────────────
  /// null = no mostrando animación
  /// 'spinning' = mostrando rueda
  /// 'trophy'   = mostrando trofeo con los ganadores
  String? _drawAnimState;
  List<GiveawayTicket>? _pendingWinners;
  late AnimationController _lottieCtrl;

  /// IDs de boletos que están siendo liberados en este momento.
  final Set<String> _releasingTicketIds = {};

  static final String _kBaseShareUrl =
      '${dotenv.env['WEB_URL']}/shared/giveaway';

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _lottieCtrl = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _innerTab.dispose();
    _lottieCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token ?? '';
    await context
        .read<GiveawayProvider>()
        .loadGiveawayDetail(token, widget.giveawayId);
  }

  // ── Compartir link ────────────────────────────────────────────────────────

  Future<void> _shareLink(Giveaway g) async {
    final url = '$_kBaseShareUrl/${g.publicToken}';
    await Share.share(
      '🎟️ ¡Participa en la rifa "${g.title}"!\n\n'
      '💰 Boleto: \$${g.ticketPrice.toStringAsFixed(0)}\n'
      '🎁 Premios: ${g.prizeCount}\n'
      '📅 Sorteo: ${_fmtDate(g.drawDate)}\n\n'
      'Aparta tu número aquí:\n$url',
      subject: 'Rifa "${g.title}" — Kolekta',
    );
  }

  // ── Comprobante PDF ───────────────────────────────────────────────────────

  Future<void> _shareTicketReceipt(GiveawayTicket ticket) async {
    final token = context.read<AuthProvider>().token ?? '';
    final g = context.read<GiveawayProvider>().selectedGiveaway;

    try {
      _showSnack('Generando comprobante del boleto…', true);
      final bytes = await GiveawayService.getTicketReceiptPdf(
        token: token,
        giveawayId: widget.giveawayId,
        ticketId: ticket.id,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/boleto_${ticket.ticketNumber}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Boleto #${ticket.ticketNumber} - ${g?.title ?? "Rifa"}',
        text: '¡Tu boleto de rifa en Kolekta!',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al generar el comprobante', false);
    }
  }

  // ── Contactos ─────────────────────────────────────────────────────────────

  Future<void> _pickContact(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    void Function(void Function()) setSheetState,
  ) async {
    final status = await Permission.contacts.request();

    if (!status.isGranted) {
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
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
      } else {
        _showSnack('Permiso de contactos requerido', false);
      }
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;
      final full = await FlutterContacts.getContact(contact.id);
      if (full == null) return;
      final phone = full.phones.isNotEmpty
          ? full.phones.first.number.replaceAll(RegExp(r'\s+'), '')
          : null;
      setSheetState(() {
        nameCtrl.text = full.displayName;
        if (phone != null) phoneCtrl.text = phone;
      });
    } catch (_) {}
  }

  // ── Asignar boleto ────────────────────────────────────────────────────────

  void _showAssignSheet(Giveaway g) {
    final c = context.kolekta;
    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.read<GiveawayProvider>();

    final freeTickets = g.details
        .where((t) => t.status == TicketStatus.free)
        .toList()
      ..sort((a, b) => a.ticketNumber.compareTo(b.ticketNumber));

    if (freeTickets.isEmpty) {
      _showSnack('No hay boletos libres disponibles', false);
      return;
    }

    int? selectedTicket;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isPaid = false;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Asignar boleto',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 16),
                Text('Número de boleto',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: c.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedTicket,
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Seleccionar número',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textHint)),
                      ),
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: c.surface,
                      items: freeTickets
                          .map((t) => DropdownMenuItem(
                                value: t.ticketNumber,
                                child: Text('# ${t.ticketNumber}',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: c.textPrimary)),
                              ))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedTicket = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Cliente',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: c.textSecondary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _pickContact(nameCtrl, phoneCtrl, setSheetState),
                      icon: Icon(Icons.person_search_rounded,
                          size: 15, color: AppColors.pink),
                      label: Text('Desde contactos',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.pink)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente *',
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.contacts_outlined,
                          color: AppColors.pink, size: 20),
                      tooltip: 'Seleccionar contacto',
                      onPressed: () =>
                          _pickContact(nameCtrl, phoneCtrl, setSheetState),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: AppTextStyles.bodyMedium,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Teléfono (opcional)',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isPaid,
                      activeColor: AppColors.pink,
                      onChanged: (v) =>
                          setSheetState(() => isPaid = v ?? false),
                    ),
                    Text('Marcar como pagado',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: c.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isAssigning
                        ? null
                        : () async {
                            if (selectedTicket == null) {
                              _showSnack('Selecciona un número', false);
                              return;
                            }
                            if (nameCtrl.text.trim().isEmpty) {
                              _showSnack(
                                  'Ingresa el nombre del cliente', false);
                              return;
                            }
                            setSheetState(() => isAssigning = true);
                            final ticketNum = selectedTicket!;
                            final ok = await prov.assignTicket(
                              token: token,
                              giveawayId: g.id,
                              ticketNumber: ticketNum,
                              clientName: nameCtrl.text.trim(),
                              clientPhone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              paid: isPaid,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _showSnack(
                              ok
                                  ? 'Boleto #$ticketNum asignado'
                                  : prov.errorMessage ?? 'Error',
                              ok,
                            );
                          },
                    child: isAssigning
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Asignar boleto'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Sorteo ────────────────────────────────────────────────────────────────

  void _showDrawSheet(Giveaway g) {
    final c = context.kolekta;
    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.read<GiveawayProvider>();
    final manualCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Realizar sorteo',
                style:
                    AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Se necesitan ${g.prizeCount} número(s) ganador(es)',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Sorteo aleatorio (con animación) ─────────────────────────
            _DrawOption(
              icon: Icons.casino_outlined,
              iconBg: c.pinkLight,
              iconColor: AppColors.pink,
              title: 'Sorteo aleatorio',
              subtitle:
                  'El sistema selecciona aleatoriamente entre los boletos pagados',
              onTap: () async {
                Navigator.pop(ctx);
                // Mostrar animación de rueda
                setState(() {
                  _drawAnimState = 'spinning';
                  _pendingWinners = null;
                });
                _lottieCtrl.reset();

                await Future.delayed(const Duration(seconds: 2));

                // Llamar al sorteo mientras la animación corre
                final winners =
                    await prov.drawRandom(token: token, giveawayId: g.id);

                if (!mounted) return;

                if (winners == null) {
                  setState(() => _drawAnimState = null);
                  _showSnack(prov.errorMessage ?? 'Error', false);
                  return;
                }

                // Esperar a que la animación de rueda complete al menos 2s
                await Future.delayed(const Duration(seconds: 6));

                if (!mounted) return;

                // Transición a trofeo
                setState(() {
                  _drawAnimState = 'trophy';
                  _pendingWinners = winners;
                });
              },
            ),

            const SizedBox(height: 12),

            // ── Sorteo manual ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: c.primarySurface,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.list_alt_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sorteo manual',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: c.textPrimary)),
                            Text('Ingresa los números en orden de premio',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: c.textHint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: manualCtrl,
                    style: AppTextStyles.bodyMedium,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Ej: 7, 23, 5 (${g.prizeCount} número(s))',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final raw = manualCtrl.text.trim();
                        if (raw.isEmpty) {
                          _showSnack('Ingresa los números ganadores', false);
                          return;
                        }
                        final nums = raw
                            .split(RegExp(r'[,\s]+'))
                            .map((s) => int.tryParse(s.trim()))
                            .whereType<int>()
                            .toList();
                        if (nums.length != g.prizeCount) {
                          _showSnack(
                            'Ingresa exactamente ${g.prizeCount} número(s)',
                            false,
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final winners = await prov.drawManual(
                          token: token,
                          giveawayId: g.id,
                          winnerTicketNumbers: nums,
                        );
                        if (!mounted) return;
                        if (winners != null) {
                          _showWinnersDialog(winners);
                        } else {
                          _showSnack(prov.errorMessage ?? 'Error', false);
                        }
                      },
                      child: const Text('Confirmar sorteo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showWinnersDialog(List<GiveawayTicket> winners) {
    final c = context.kolekta;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.orange, size: 24),
            const SizedBox(width: 8),
            Text('¡Ganadores!',
                style:
                    AppTextStyles.headingSmall.copyWith(color: c.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: winners
              .map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${w.prizePlace}°',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Boleto #${w.ticketNumber}',
                                    style: AppTextStyles.labelLarge
                                        .copyWith(color: c.textPrimary)),
                                Text(w.clientName ?? '—',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: c.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('¡Excelente!'),
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

  Future<void> _markAsPaid(GiveawayTicket ticket, String token) async {
    final prov = context.read<GiveawayProvider>();
    final ok = await prov.updateTicket(
      token: token,
      giveawayId: widget.giveawayId,
      ticketId: ticket.id,
      paid: true,
    );
    _showSnack(
        ok
            ? 'Boleto #${ticket.ticketNumber} marcado como pagado'
            : prov.errorMessage ?? 'Error',
        ok);
  }

  Future<void> _confirmCancelTicket(GiveawayTicket ticket, String token) async {
    final c = context.kolekta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Liberar boleto #${ticket.ticketNumber}',
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
        content: Text(
          '¿Liberar este boleto? El cliente "${ticket.clientName}" perderá su reserva.',
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Liberar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Activar indicador de carga para este boleto
    setState(() => _releasingTicketIds.add(ticket.id));

    final prov = context.read<GiveawayProvider>();
    final ok = await prov.cancelTicket(
      token: token,
      giveawayId: widget.giveawayId,
      ticketId: ticket.id,
    );

    if (!mounted) return;

    // Desactivar indicador de carga
    setState(() => _releasingTicketIds.remove(ticket.id));

    _showSnack(ok ? 'Boleto liberado' : prov.errorMessage ?? 'Error', ok);
  }

  // ── Overlay de animación de sorteo ─────────────────────────────────────────

  Widget _buildDrawAnimationOverlay() {
    final isSpinning = _drawAnimState == 'spinning';
    final isTrophy = _drawAnimState == 'trophy';

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animación Lottie
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.transparent, // Fondo transparente
                borderRadius: BorderRadius.circular(20),
              ),
              child: isSpinning
                  ? Lottie.asset(
                      'assets/animations/slot.json',
                      controller: _lottieCtrl,
                      onLoaded: (comp) {
                        _lottieCtrl.duration = comp.duration;
                        _lottieCtrl.repeat();
                      },
                      // Forzar fondo transparente
                      fit: BoxFit.contain,
                    )
                  : Lottie.asset(
                      'assets/animations/trophy.json',
                      controller: _lottieCtrl,
                      onLoaded: (comp) {
                        _lottieCtrl.duration = comp.duration;
                        _lottieCtrl.forward();
                      },
                      fit: BoxFit.contain,
                    ),
            ),

            const SizedBox(height: 20),

            Text(
              isSpinning ? '¡Sorteando…!' : '¡Tenemos ganadores!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),

            // Si ya hay ganadores, mostrarlos debajo de la animación
            if (isTrophy && _pendingWinners != null) ...[
              const SizedBox(height: 20),
              ..._pendingWinners!.map((w) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${w.prizePlace}°',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Boleto #${w.ticketNumber}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text(w.clientName ?? '—',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _drawAnimState = null;
                    _pendingWinners = null;
                  });
                  _lottieCtrl.reset();
                },
                child: const Text('¡Excelente!',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Stack(
      children: [
        Consumer2<GiveawayProvider, AuthProvider>(
          builder: (context, prov, auth, _) {
            final g = prov.selectedGiveaway;
            final token = auth.token ?? '';

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
                  g?.title ?? 'Detalle',
                  style:
                      AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
                actions: [
                  if (g != null && g.status == GiveawayStatus.open) ...[
                    IconButton(
                      icon: Icon(Icons.share_rounded,
                          color: c.textSecondary, size: 20),
                      tooltip: 'Compartir link',
                      onPressed: () => _shareLink(g),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          color: c.textSecondary, size: 20),
                      tooltip: 'Editar',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateGiveawayScreen(giveawayToEdit: g),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              body: prov.actionLoading && g == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.pink))
                  : g == null
                      ? Center(
                          child: Text('Rifa no encontrada',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: c.textSecondary)))
                      : RefreshIndicator(
                          color: AppColors.pink,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            children: [
                              // ── Imagen de portada ───────────────────
                              if (g.coverImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: g.coverImage!,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (g.coverImage != null)
                                const SizedBox(height: 16),

                              _GiveawayHeader(giveaway: g),
                              const SizedBox(height: 16),

                              _SaleProgress(giveaway: g),
                              const SizedBox(height: 20),

                              _InfoCard(giveaway: g),
                              const SizedBox(height: 20),

                              // ── Acciones ────────────────────────────
                              if (g.status == GiveawayStatus.open) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.add_circle_outline_rounded,
                                        label: 'Asignar boleto',
                                        color: AppColors.pink,
                                        onTap: () => _showAssignSheet(g),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.casino_outlined,
                                        label: 'Realizar sorteo',
                                        color: AppColors.orange,
                                        onTap: () => _showDrawSheet(g),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ── Tabs ────────────────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.border),
                                ),
                                child: TabBar(
                                  controller: _innerTab,
                                  indicator: BoxDecoration(
                                    color: AppColors.pink,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicatorPadding: const EdgeInsets.all(3),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: c.textSecondary,
                                  labelStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                  unselectedLabelStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                  dividerColor: Colors.transparent,
                                  tabs: const [
                                    Tab(text: 'Boletos'),
                                    Tab(text: 'Ganadores'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              ListenableBuilder(
                                listenable: _innerTab,
                                builder: (_, __) {
                                  if (_innerTab.index == 0) {
                                    return _TicketsGrid(
                                      giveaway: g,
                                      isOpen: g.status == GiveawayStatus.open,
                                      token: token,
                                      onMarkPaid: _markAsPaid,
                                      onCancelTicket: _confirmCancelTicket,
                                      onShareTicket: (ticket) =>
                                          _shareTicketReceipt(ticket),
                                      releasingTicketIds: _releasingTicketIds,
                                    );
                                  }
                                  return _WinnersList(giveaway: g);
                                },
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
            );
          },
        ),

        // ── Overlay de animación encima de todo ────────────────────────────
        if (_drawAnimState != null)
          Positioned.fill(child: _buildDrawAnimationOverlay()),
      ],
    );
  }

  String _fmtDate(String d) {
    try {
      return DateFormat("d 'de' MMMM yyyy", 'es').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}

// ─── _GiveawayHeader ──────────────────────────────────────────────────────────

class _GiveawayHeader extends StatelessWidget {
  const _GiveawayHeader({required this.giveaway});
  final Giveaway giveaway;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: AppColors.pink.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Precio por boleto',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Colors.white70)),
                Text(
                  '\$${giveaway.ticketPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${giveaway.prizeCount} premio(s) · Sorteo: ${_fmtDate(giveaway.drawDate)}',
                  style:
                      AppTextStyles.labelSmall.copyWith(color: Colors.white70),
                ),
                if (giveaway.autoDrawAt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.auto_mode_rounded,
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Auto: ${DateFormat('dd/MM/yyyy HH:mm').format(giveaway.autoDrawAt!.toLocal())}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${giveaway.soldTickets}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'de ${giveaway.totalTickets}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Vendidos',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
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
}

// ─── _SaleProgress ───────────────────────────────────────────────────────────

class _SaleProgress extends StatelessWidget {
  const _SaleProgress({required this.giveaway});
  final Giveaway giveaway;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final progress = giveaway.soldPercentage;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progreso de ventas',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: c.textSecondary)),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: c.divider,
              color: giveaway.status == GiveawayStatus.finished
                  ? AppColors.success
                  : AppColors.pink,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressStat(
                label: 'Libres',
                value: '${giveaway.totalTickets - giveaway.soldTickets}',
                color: c.textSecondary,
              ),
              _ProgressStat(
                label: 'Vendidos',
                value: '${giveaway.soldTickets}',
                color: AppColors.pink,
              ),
              _ProgressStat(
                label: 'Potencial',
                value: '\$${giveaway.totalPotential.toStringAsFixed(0)}',
                color: AppColors.success,
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

// ─── _InfoCard ────────────────────────────────────────────────────────────────

class _InfoCard extends StatefulWidget {
  const _InfoCard({required this.giveaway});
  final Giveaway giveaway;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _showPrizes = false;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final g = widget.giveaway;
    final hasPrizeDetails = g.prizes.isNotEmpty;

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
              style:
                  AppTextStyles.labelMedium.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),

          if (g.description != null && g.description!.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.notes_rounded,
              label: 'Descripción',
              value: g.description!,
            ),
            Divider(height: 16, color: c.divider),
          ],

          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha del sorteo',
            value: _fmtDate(g.drawDate),
          ),

          if (g.autoDrawAt != null) ...[
            Divider(height: 16, color: c.divider),
            _InfoRow(
              icon: Icons.auto_mode_rounded,
              label: 'Sorteo automático',
              value: DateFormat("dd/MM/yyyy 'a las' HH:mm")
                  .format(g.autoDrawAt!.toLocal()),
            ),
          ],

          Divider(height: 16, color: c.divider),

          _InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Total de boletos',
            value: '${g.totalTickets}',
          ),
          Divider(height: 16, color: c.divider),

          // Premios con opción de expandir descripciones
          GestureDetector(
            onTap: hasPrizeDetails
                ? () => setState(() => _showPrizes = !_showPrizes)
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emoji_events_outlined, size: 16, color: c.textHint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Premios',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: c.textHint)),
                      Text('${g.prizeCount} lugar(es)',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textPrimary)),
                    ],
                  ),
                ),
                if (hasPrizeDetails)
                  Icon(
                    _showPrizes
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.pink,
                    size: 20,
                  ),
              ],
            ),
          ),

          // Expandible: descripciones e imágenes de premios
          if (_showPrizes && hasPrizeDetails) ...[
            const SizedBox(height: 12),
            ...g.prizes
                .sorted((a, b) => a.prizePlace.compareTo(b.prizePlace))
                .map((prize) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Número de lugar
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${prize.prizePlace}°',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Descripción
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prize.description,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: c.textPrimary),
                                  ),
                                ],
                              ),
                            ),

                            // Imagen del premio
                            if (prize.imageUrl != null) ...[
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: prize.imageUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String d) {
    try {
      return DateFormat("d 'de' MMMM yyyy", 'es').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}

// Helper extension para sorted
extension _ListSorted<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
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
                  style: AppTextStyles.labelSmall.copyWith(color: c.textHint)),
              Text(value,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── _ActionButton ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── _TicketsGrid ─────────────────────────────────────────────────────────────

class _TicketsGrid extends StatelessWidget {
  const _TicketsGrid({
    required this.giveaway,
    required this.isOpen,
    required this.token,
    required this.onMarkPaid,
    required this.onCancelTicket,
    required this.onShareTicket,
    required this.releasingTicketIds,
  });

  final Giveaway giveaway;
  final bool isOpen;
  final String token;
  final Future<void> Function(GiveawayTicket, String) onMarkPaid;
  final Future<void> Function(GiveawayTicket, String) onCancelTicket;
  final Future<void> Function(GiveawayTicket) onShareTicket;
  final Set<String> releasingTicketIds;

  @override
  Widget build(BuildContext context) {
    final tickets = [...giveaway.details]
      ..sort((a, b) => a.ticketNumber.compareTo(b.ticketNumber));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: tickets.length,
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        return _TicketCell(
          ticket: t,
          isOpen: isOpen,
          token: token,
          onMarkPaid: onMarkPaid,
          onCancelTicket: onCancelTicket,
          onShareTicket: onShareTicket,
          isReleasing: releasingTicketIds.contains(t.id),
        );
      },
    );
  }
}

class _TicketCell extends StatelessWidget {
  const _TicketCell({
    required this.ticket,
    required this.isOpen,
    required this.token,
    required this.onMarkPaid,
    required this.onCancelTicket,
    required this.onShareTicket,
    required this.isReleasing,
  });

  final GiveawayTicket ticket;
  final bool isOpen;
  final String token;
  final Future<void> Function(GiveawayTicket, String) onMarkPaid;
  final Future<void> Function(GiveawayTicket, String) onCancelTicket;
  final Future<void> Function(GiveawayTicket) onShareTicket;
  final bool isReleasing;

  Color _bgColor(BuildContext ctx) {
    final c = ctx.kolekta;
    switch (ticket.status) {
      case TicketStatus.free:
        return c.divider;
      case TicketStatus.reserved:
        return AppColors.orangeLight;
      case TicketStatus.paid:
        return AppColors.greenLight;
      case TicketStatus.winner:
        return AppColors.orangeLight;
      case TicketStatus.cancelled:
        return c.divider;
    }
  }

  Color _textColor(BuildContext ctx) {
    final c = ctx.kolekta;
    switch (ticket.status) {
      case TicketStatus.free:
        return c.textHint;
      case TicketStatus.reserved:
        return AppColors.warning;
      case TicketStatus.paid:
        return AppColors.success;
      case TicketStatus.winner:
        return AppColors.orange;
      case TicketStatus.cancelled:
        return c.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(context);
    final text = _textColor(context);

    return GestureDetector(
      onTap: () {
        if (!isOpen || isReleasing) return;
        if (ticket.status == TicketStatus.free ||
            ticket.status == TicketStatus.cancelled) {
          return;
        }
        _showTicketMenu(context);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isReleasing ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isReleasing ? AppColors.error.withOpacity(0.08) : bg,
            borderRadius: BorderRadius.circular(8),
            border: isReleasing
                ? Border.all(
                    color: AppColors.error.withOpacity(0.4), width: 1.5)
                : ticket.status == TicketStatus.winner
                    ? Border.all(color: AppColors.orange, width: 2)
                    : null,
          ),
          child: Stack(
            children: [
              Center(
                child: isReleasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(
                        '${ticket.ticketNumber}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: text),
                      ),
              ),
              if (ticket.status == TicketStatus.winner && !isReleasing)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.star_rounded,
                      color: AppColors.orange, size: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketMenu(BuildContext context) {
    final c = context.kolekta;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Boleto #${ticket.ticketNumber}',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textPrimary)),
              if (ticket.clientName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: c.textHint),
                    const SizedBox(width: 6),
                    Text(ticket.clientName!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary)),
                    if (ticket.clientPhone != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_outlined, size: 14, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(ticket.clientPhone!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: c.textSecondary)),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (ticket.status == TicketStatus.reserved)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success, size: 20),
                  ),
                  title: Text('Marcar como pagado',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textPrimary)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(context);
                    onMarkPaid(ticket, token);
                  },
                ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.statusPending,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_open_rounded,
                      color: AppColors.error, size: 20),
                ),
                title: Text('Liberar boleto',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.error)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  onCancelTicket(ticket, token);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.pink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.pink, size: 20),
                ),
                title: Text('Compartir boleto',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  onShareTicket(ticket);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _WinnersList ─────────────────────────────────────────────────────────────

class _WinnersList extends StatelessWidget {
  const _WinnersList({required this.giveaway});
  final Giveaway giveaway;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final winners = giveaway.details
        .where((t) => t.status == TicketStatus.winner)
        .toList()
      ..sort((a, b) => (a.prizePlace ?? 99).compareTo(b.prizePlace ?? 99));

    if (winners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: c.textHint),
            const SizedBox(height: 8),
            Text(
              giveaway.status == GiveawayStatus.open
                  ? 'El sorteo aún no se ha realizado'
                  : 'No hay ganadores registrados',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: winners.map((w) {
        // Buscar descripción del premio correspondiente
        final prize = giveaway.prizes
            .where((p) => p.prizePlace == w.prizePlace)
            .firstOrNull;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.orange.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.orange.withOpacity(0.08), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${w.prizePlace}°',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Boleto #${w.ticketNumber}',
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: c.textPrimary)),
                          Text(
                            w.clientName ?? '—',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textSecondary),
                          ),
                          if (w.clientPhone != null)
                            Text(
                              w.clientPhone!,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: c.textHint),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Ganador',
                          style: TextStyle(
                              color: AppColors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                // Descripción del premio ganado
                if (prize != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            prize.description,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textPrimary),
                          ),
                        ),
                        if (prize.imageUrl != null) ...[
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: prize.imageUrl!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── _DrawOption ──────────────────────────────────────────────────────────────

class _DrawOption extends StatelessWidget {
  const _DrawOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textPrimary)),
                  Text(subtitle,
                      style:
                          AppTextStyles.labelSmall.copyWith(color: c.textHint)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.textHint),
          ],
        ),
      ),
    );
  }
}
