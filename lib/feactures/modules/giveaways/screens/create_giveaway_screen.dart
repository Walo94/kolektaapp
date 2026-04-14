import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../../shared/widgets/kolekta_button.dart';
import '../../../../shared/widgets/kolekta_text_field.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/giveaway_provider.dart';
import '../../services/giveaway_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado mutable de un premio en el formulario
// ─────────────────────────────────────────────────────────────────────────────
class _PrizeFormItem {
  final int place;
  final TextEditingController descCtrl;
  File? imageFile;
  String? existingImageUrl; // para edición

  _PrizeFormItem({
    required this.place,
    String desc = '',
    this.existingImageUrl,
  }) : descCtrl = TextEditingController(text: desc);

  void dispose() => descCtrl.dispose();

  PrizeInput toPrizeInput() => PrizeInput(
      prizePlace: place,
      description: descCtrl.text.trim(),
      imageFile: imageFile,
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class CreateGiveawayScreen extends StatefulWidget {
  const CreateGiveawayScreen({super.key, this.giveawayToEdit});

  final Giveaway? giveawayToEdit;

  @override
  State<CreateGiveawayScreen> createState() => _CreateGiveawayScreenState();
}

class _CreateGiveawayScreenState extends State<CreateGiveawayScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _ticketsCtrl = TextEditingController();
  final _prizesCtrl = TextEditingController();

  DateTime _drawDate = DateTime.now().add(const Duration(days: 7));
  File? _imageFile;
  bool _removeCoverImage = false;

  // ── Sorteo automático ─────────────────────────────────────────────────────
  bool _autoDrawEnabled = false;
  TimeOfDay _autoDrawTime = const TimeOfDay(hour: 12, minute: 0);

  // ── Descripciones de premios ──────────────────────────────────────────────
  List<_PrizeFormItem> _prizeItems = [];

  bool get _isEdit => widget.giveawayToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final g = widget.giveawayToEdit!;
      _titleCtrl.text = g.title;
      _descCtrl.text = g.description ?? '';
      _priceCtrl.text = g.ticketPrice.toStringAsFixed(2);
      _ticketsCtrl.text = g.totalTickets.toString();
      _prizesCtrl.text = g.prizeCount.toString();
      _drawDate = DateTime.tryParse(g.drawDate) ?? _drawDate;

      // Restaurar sorteo automático si está configurado
      if (g.autoDrawAt != null) {
        _autoDrawEnabled = true;
        _autoDrawTime = TimeOfDay(
          hour: g.autoDrawAt!.hour,
          minute: g.autoDrawAt!.minute,
        );
      }

      // Restaurar premios existentes
      _buildPrizeItems(g.prizeCount, existingPrizes: g.prizes);
    } else {
      _prizesCtrl.text = '1';
      _buildPrizeItems(1);
    }

    // Escuchar cambios en el campo de premios para actualizar los items
    _prizesCtrl.addListener(_onPrizesChanged);
  }

  void _buildPrizeItems(int count, {List<GiveawayPrize> existingPrizes = const []}) {
    for (final item in _prizeItems) {
      item.dispose();
    }
    _prizeItems = List.generate(count, (i) {
      final place = i + 1;
      final existing = existingPrizes.where((p) => p.prizePlace == place).firstOrNull;
      return _PrizeFormItem(
        place: place,
        desc: existing?.description ?? '',
        existingImageUrl: existing?.imageUrl,
      );
    });
  }

  void _onPrizesChanged() {
    final n = int.tryParse(_prizesCtrl.text) ?? 0;
    if (n < 1 || n == _prizeItems.length) return;
    setState(() {
      if (n > _prizeItems.length) {
        // Agregar los nuevos
        for (int i = _prizeItems.length + 1; i <= n; i++) {
          _prizeItems.add(_PrizeFormItem(place: i));
        }
      } else {
        // Eliminar los sobrantes
        for (int i = _prizeItems.length - 1; i >= n; i--) {
          _prizeItems[i].dispose();
          _prizeItems.removeAt(i);
        }
      }
    });
  }

  @override
  void dispose() {
    _prizesCtrl.removeListener(_onPrizesChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _ticketsCtrl.dispose();
    _prizesCtrl.dispose();
    for (final item in _prizeItems) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _drawDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : _drawDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.pink),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _drawDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _autoDrawTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.pink),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _autoDrawTime = picked);
  }

  Future<void> _pickImage() async {
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
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: _iconBox(c.pinkLight, Icons.camera_alt_outlined, AppColors.pink),
                title: Text('Cámara',
                    style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (img != null) {
                    setState(() {
                      _imageFile = File(img.path);
                      _removeCoverImage = false;
                    });
                  }
                },
              ),
              ListTile(
                leading: _iconBox(c.primarySurface, Icons.photo_library_outlined, AppColors.primary),
                title: Text('Galería',
                    style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) {
                    setState(() {
                      _imageFile = File(img.path);
                      _removeCoverImage = false;
                    });
                  }
                },
              ),
              if (_isEdit &&
                  widget.giveawayToEdit!.coverImage != null &&
                  _imageFile == null)
                ListTile(
                  leading: _iconBox(AppColors.statusPending, Icons.delete_outline_rounded, AppColors.error),
                  title: Text('Eliminar imagen',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageFile = null;
                      _removeCoverImage = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPrizeImage(_PrizeFormItem item) async {
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
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: _iconBox(c.pinkLight, Icons.camera_alt_outlined, AppColors.pink),
                title: Text('Cámara',
                    style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (img != null) setState(() => item.imageFile = File(img.path));
                },
              ),
              ListTile(
                leading: _iconBox(c.primarySurface, Icons.photo_library_outlined, AppColors.primary),
                title: Text('Galería',
                    style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) setState(() => item.imageFile = File(img.path));
                },
              ),
              if (item.imageFile != null || item.existingImageUrl != null)
                ListTile(
                  leading: _iconBox(AppColors.statusPending, Icons.delete_outline_rounded, AppColors.error),
                  title: Text('Quitar imagen',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      item.imageFile = null;
                      item.existingImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(Color bg, IconData icon, Color iconColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que los items de premios con descripción tengan texto
    for (final item in _prizeItems) {
      if (item.descCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Agrega la descripción del ${item.place}° premio'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
        return;
      }
    }

    final token = context.read<AuthProvider>().token ?? '';
    final prov = context.read<GiveawayProvider>();
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    final tickets = int.tryParse(_ticketsCtrl.text) ?? 0;
    final prizes = int.tryParse(_prizesCtrl.text) ?? 1;
    final dateStr = DateFormat('yyyy-MM-dd').format(_drawDate);

    // Construir autoDrawAt combinando fecha + hora seleccionada
    DateTime? autoDrawAt;
    if (_autoDrawEnabled) {
      autoDrawAt = DateTime(
        _drawDate.year,
        _drawDate.month,
        _drawDate.day,
        _autoDrawTime.hour,
        _autoDrawTime.minute,
      );
      if (autoDrawAt.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('La hora del sorteo automático debe ser futura'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
        return;
      }
    }

    final prizeInputs = _prizeItems.map((item) => item.toPrizeInput()).toList();

    bool ok;

    if (_isEdit) {
      ok = await prov.updateGiveaway(
        token: token,
        id: widget.giveawayToEdit!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        drawDate: dateStr,
        autoDrawAt: _autoDrawEnabled ? autoDrawAt : null,
        clearAutoDraw: !_autoDrawEnabled,
        prizeCount: prizes,
        coverImageFile: _imageFile,
        removeCoverImage: _removeCoverImage,
        prizes: prizeInputs,
      );
    } else {
      final created = await prov.createGiveaway(
        token: token,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        drawDate: dateStr,
        autoDrawAt: autoDrawAt,
        ticketPrice: price,
        totalTickets: tickets,
        prizeCount: prizes,
        coverImageFile: _imageFile,
        prizes: prizeInputs,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final loading = context.watch<GiveawayProvider>().actionLoading;
    final existingImage = widget.giveawayToEdit?.coverImage;
    final hasSoldTickets =
        _isEdit && (widget.giveawayToEdit!.soldTickets > 0);

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
          _isEdit ? 'Editar rifa' : 'Nueva rifa',
          style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Imagen de portada ────────────────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: c.pinkLight,
                  borderRadius: BorderRadius.circular(16),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : (existingImage != null && !_removeCoverImage)
                          ? DecorationImage(
                              image: NetworkImage(existingImage),
                              fit: BoxFit.cover)
                          : null,
                ),
                child: (_imageFile == null &&
                        (existingImage == null || _removeCoverImage))
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.pink, size: 36),
                          const SizedBox(height: 8),
                          Text('Agregar imagen (opcional)',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.pink)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Información general ──────────────────────────────────────
            Text('Información general',
                style: AppTextStyles.labelMedium.copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            KolektaTextField(
              controller: _titleCtrl,
              hint: 'Título de la rifa *',
              prefixIcon: Icons.confirmation_number_outlined,
              validator: (v) => v!.trim().isEmpty ? 'Ingresa un título' : null,
            ),
            const SizedBox(height: 10),
            KolektaTextField(
              controller: _descCtrl,
              hint: 'Descripción (premios, causa, etc.)',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // ── Configuración ────────────────────────────────────────────
            Text('Configuración',
                style: AppTextStyles.labelMedium.copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: KolektaTextField(
                    controller: _priceCtrl,
                    hint: 'Precio boleto *',
                    prefixIcon: Icons.attach_money_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    // Precio no editable si ya hay boletos vendidos
                    enabled: !(_isEdit && hasSoldTickets),
                    validator: (v) {
                      if (_isEdit && hasSoldTickets) return null;
                      final n = double.tryParse(v?.replaceAll(',', '') ?? '');
                      if (n == null || n <= 0) return 'Precio inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KolektaTextField(
                    controller: _ticketsCtrl,
                    hint: 'No. boletos *',
                    prefixIcon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // No. boletos nunca se puede cambiar al editar
                    enabled: !_isEdit,
                    validator: (v) {
                      if (_isEdit) return null;
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 2) return 'Mín. 2';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Número de premios ────────────────────────────────────────
            KolektaTextField(
              controller: _prizesCtrl,
              hint: 'Número de premios *',
              prefixIcon: Icons.emoji_events_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Mín. 1 premio';
                return null;
              },
            ),

            // ── Descripciones de premios ─────────────────────────────────
            if (_prizeItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Descripción de premios',
                  style: AppTextStyles.labelMedium.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
              ..._prizeItems.map((item) => _PrizeItemCard(
                    item: item,
                    onPickImage: () => _pickPrizeImage(item),
                  )),
            ],

            const SizedBox(height: 20),

            // ── Fecha del sorteo ─────────────────────────────────────────
            Text('Fecha del sorteo',
                style: AppTextStyles.labelMedium.copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            // Fecha siempre editable (incluso con boletos vendidos)
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 18, color: c.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_drawDate),
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

            const SizedBox(height: 16),

            // ── Sorteo automático ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.orangeLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_mode_rounded,
                            color: AppColors.orange, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sorteo automático',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: c.textPrimary)),
                            Text(
                              'El sistema realizará el sorteo en la fecha y hora indicada',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: c.textHint),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoDrawEnabled,
                        activeColor: AppColors.orange,
                        onChanged: (v) => setState(() => _autoDrawEnabled = v),
                      ),
                    ],
                  ),
                  if (_autoDrawEnabled) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 16, color: c.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              'Hora del sorteo: ${_autoDrawTime.format(context)}',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: c.textPrimary),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                color: c.textHint, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Avisos modo edición ──────────────────────────────────────
            if (_isEdit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasSoldTickets
                            ? 'El número de boletos y el precio no se pueden cambiar porque ya hay boletos vendidos.'
                            : 'El número de boletos no se puede cambiar después de crear la rifa.',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            KolektaButton(
              label: _isEdit ? 'Guardar cambios' : 'Crear rifa',
              onPressed: loading ? null : _submit,
              isLoading: loading,
              color: AppColors.pink,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de un ítem de premio en el formulario
// ─────────────────────────────────────────────────────────────────────────────
class _PrizeItemCard extends StatefulWidget {
  const _PrizeItemCard({
    required this.item,
    required this.onPickImage,
  });

  final _PrizeFormItem item;
  final VoidCallback onPickImage;

  @override
  State<_PrizeItemCard> createState() => _PrizeItemCardState();
}

class _PrizeItemCardState extends State<_PrizeItemCard> {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final item = widget.item;
    final placeLabel = '${item.place}° lugar';
    final hasImage = item.imageFile != null || item.existingImageUrl != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del lugar
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${item.place}°',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(placeLabel,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),

            // Descripción del premio
            TextField(
              controller: item.descCtrl,
              style: AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Descripción del premio *',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: c.textHint),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border)),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 10),

            // Imagen del premio
            GestureDetector(
              onTap: widget.onPickImage,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: hasImage ? null : c.pinkLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: hasImage ? AppColors.pink : c.border, width: 1),
                  image: item.imageFile != null
                      ? DecorationImage(
                          image: FileImage(item.imageFile!),
                          fit: BoxFit.cover)
                      : (item.existingImageUrl != null)
                          ? DecorationImage(
                              image:
                                  CachedNetworkImageProvider(item.existingImageUrl!),
                              fit: BoxFit.cover)
                          : null,
                ),
                child: !hasImage
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.pink, size: 24),
                          const SizedBox(height: 4),
                          Text('Imagen del premio (opcional)',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.pink)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}