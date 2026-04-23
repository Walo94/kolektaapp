import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/kolekta_colors.dart';
import '../../../admin/providers/auth_provider.dart';
import '../../providers/batch_provider.dart';
import '../../services/batch_service.dart';

class CreateBatchScreen extends StatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  int _step = 0;

  // ── Campos paso 1 ─────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _slotsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  BatchFrequency _frequency = BatchFrequency.weekly;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  bool _randomize = false;

  // ── Imagen de portada ─────────────────────────────────
  File? _coverImageFile;
  final _imagePicker = ImagePicker();

  // ── Participantes ─────────────────────────────────────
  final List<_ParticipantRow> _participants = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _slotsCtrl.dispose();
    _notesCtrl.dispose();
    for (final p in _participants) {
      p.dispose();
    }
    super.dispose();
  }

  int get _totalSlots => int.tryParse(_slotsCtrl.text) ?? 0;
  double get _entryPrice => double.tryParse(_priceCtrl.text) ?? 0;
  double get _payoutAmount => _entryPrice * _totalSlots;

  // ── Selección de fecha ────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  // ── Imagen de portada ─────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    // Para cámara pedimos el permiso explícitamente.
    // Para galería dejamos que image_picker maneje sus propios permisos
    // (desde v0.8+ lo hace internamente en Android e iOS).
    // Solo mostramos el diálogo de ajustes si el permiso quedó permanentemente denegado.
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        if (status.isPermanentlyDenied) {
          _showPermissionDialog('cámara');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permiso de cámara requerido'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    } else {
      // Android 13+ usa READ_MEDIA_IMAGES, versiones anteriores READ_EXTERNAL_STORAGE.
      // Pedimos ambos; el sistema ignora el que no aplique.
      PermissionStatus status;
      if (Platform.isAndroid) {
        final photos = await Permission.photos.request();
        // En SDK < 33 photos puede dar 'restricted'; verificamos storage como fallback
        if (photos.isGranted || photos.isLimited) {
          status = photos;
        } else {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (!status.isGranted && !status.isLimited) {
        if (!mounted) return;
        if (status.isPermanentlyDenied) {
          _showPermissionDialog('galería');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permiso de galería requerido'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _coverImageFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showPermissionDialog(String tipo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Permiso de $tipo requerido'),
        content: Text(
          'El permiso de $tipo fue denegado permanentemente. '
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

  void _showImageSourceSheet() {
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
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary),
                ),
                title: Text('Tomar foto',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.purpleLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded,
                      color: AppColors.purple),
                ),
                title: Text('Elegir de galería',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_coverImageFile != null)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.statusPending,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: AppColors.statusPendingText),
                  ),
                  title: Text('Eliminar imagen',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _coverImageFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seleccionar contacto ──────────────────────────────
  Future<void> _pickContact(int index) async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de contactos requerido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      // Cargar detalle completo (con teléfonos)
      final full = await FlutterContacts.getContact(contact.id);
      if (full == null) return;

      final name = full.displayName;
      final phone = full.phones.isNotEmpty
          ? full.phones.first.number.replaceAll(RegExp(r'\s+'), '')
          : null;

      setState(() {
        _participants[index].nameCtrl.text = name;
        if (phone != null) _participants[index].phoneCtrl.text = phone;
      });
    } catch (_) {
      // El usuario canceló la selección
    }
  }

  // ── Sincronizar filas de participantes ────────────────
  void _syncParticipantRows(int slots) {
    if (slots <= 0) return;
    while (_participants.length > slots) {
      _participants.removeLast().dispose();
    }
    while (_participants.length < slots) {
      _participants.add(_ParticipantRow(number: _participants.length + 1));
    }
    setState(() {});
  }

  // ── Crear tanda ───────────────────────────────────────
  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final batchProvider = context.read<BatchProvider>();

    final participants = _participants
        .where((p) => p.nameCtrl.text.trim().isNotEmpty)
        .map((p) {
          final num = int.tryParse(p.numberCtrl.text);
          return ParticipantInput(
            contactName: p.nameCtrl.text.trim(),
            phone: p.phoneCtrl.text.trim().isNotEmpty
                ? p.phoneCtrl.text.trim()
                : null,
            assignedNumber: _randomize ? null : num,
          );
        })
        .toList();

    final batch = await batchProvider.createBatch(
      token: auth.token!,
      name: _nameCtrl.text.trim(),
      entryPrice: _entryPrice,
      totalSlots: _totalSlots,
      frequency: _frequency,
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      participants: participants,
      randomize: _randomize,
      coverImageFile: _coverImageFile,
    );

    if (!mounted) return;

    if (batch != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('¡Tanda creada exitosamente!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(batchProvider.errorMessage ?? 'Error al crear la tanda'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final isLoading = context.watch<BatchProvider>().loading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Nueva Tanda',
            style:
                AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepIndicator(currentStep: _step, totalSteps: 2),
        ),
      ),
      body: Form(
        key: _formKey,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _step == 0
              ? _StepInfo(
                  key: const ValueKey(0),
                  nameCtrl: _nameCtrl,
                  priceCtrl: _priceCtrl,
                  slotsCtrl: _slotsCtrl,
                  notesCtrl: _notesCtrl,
                  frequency: _frequency,
                  startDate: _startDate,
                  randomize: _randomize,
                  payoutAmount: _payoutAmount,
                  coverImageFile: _coverImageFile,
                  onFrequencyChanged: (f) => setState(() => _frequency = f),
                  onPickDate: _pickDate,
                  onRandomizeChanged: (v) => setState(() => _randomize = v),
                  onPickImage: _showImageSourceSheet,
                )
              : _StepParticipants(
                  key: const ValueKey(1),
                  participants: _participants,
                  totalSlots: _totalSlots,
                  entryPrice: _entryPrice,
                  randomize: _randomize,
                  onPickContact: _pickContact,
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _step = 0),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Atrás',
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: AppColors.primary)),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_step == 0) {
                            if (!_formKey.currentState!.validate()) return;
                            _syncParticipantRows(_totalSlots);
                            setState(() => _step = 1);
                          } else {
                            _handleCreate();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _step == 0
                              ? 'Siguiente → Participantes'
                              : 'Crear Tanda',
                          style: AppTextStyles.buttonMedium
                              .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paso 1: Info de la tanda ──────────────────────────────

class _StepInfo extends StatelessWidget {
  const _StepInfo({
    super.key,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.slotsCtrl,
    required this.notesCtrl,
    required this.frequency,
    required this.startDate,
    required this.randomize,
    required this.payoutAmount,
    required this.coverImageFile,
    required this.onFrequencyChanged,
    required this.onPickDate,
    required this.onRandomizeChanged,
    required this.onPickImage,
  });

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController slotsCtrl;
  final TextEditingController notesCtrl;
  final BatchFrequency frequency;
  final DateTime startDate;
  final bool randomize;
  final double payoutAmount;
  final File? coverImageFile;
  final ValueChanged<BatchFrequency> onFrequencyChanged;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onRandomizeChanged;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen de portada ───────────────────────
          _Label('Imagen de portada (opcional)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: coverImageFile != null
                      ? AppColors.primary
                      : c.border,
                  width: coverImageFile != null ? 2 : 1,
                ),
                image: coverImageFile != null
                    ? DecorationImage(
                        image: FileImage(coverImageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: coverImageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text('Toca para agregar imagen',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: c.textSecondary)),
                        Text('Cámara o galería',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: c.textHint)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 18),
                            onPressed: onPickImage,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Preview del premio ───────────────────────
          if (payoutAmount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Premio por turno',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70)),
                  Text(
                    '\$${NumberFormat('#,##0', 'es').format(payoutAmount)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Nombre ──────────────────────────────────
          _Label('Nombre de la tanda'),
          const SizedBox(height: 6),
          TextFormField(
            controller: nameCtrl,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Ej: Tanda Navideña 2025',
              prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
            ),
            validator: (v) =>
                v!.trim().isEmpty ? 'El nombre es requerido' : null,
          ),

          const SizedBox(height: 16),

          // ── Precio y Lugares ─────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Aportación \$'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: '500',
                        prefixIcon:
                            Icon(Icons.attach_money_rounded, size: 20),
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Monto inválido';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Números (mín. 5)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: slotsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: '10',
                        prefixIcon:
                            Icon(Icons.grid_3x3_rounded, size: 20),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 5) return 'Mín. 5 números';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Periodicidad ─────────────────────────────
          _Label('Periodicidad de entrega'),
          const SizedBox(height: 8),
          Row(
            children: BatchFrequency.values.map((f) {
              final selected = frequency == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onFrequencyChanged(f),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: f != BatchFrequency.monthly ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : context.kolekta.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : context.kolekta.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          f == BatchFrequency.weekly
                              ? Icons.calendar_view_week_rounded
                              : f == BatchFrequency.biweekly
                                  ? Icons.calendar_view_month_rounded
                                  : Icons.calendar_month_rounded,
                          size: 20,
                          color: selected
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : context.kolekta.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Fecha de inicio ──────────────────────────
          _Label('Fecha de primera entrega'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.kolekta.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.kolekta.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE d \'de\' MMMM yyyy', 'es')
                        .format(startDate),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down_rounded,
                      color: context.kolekta.textHint),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Notas ────────────────────────────────────
          _Label('Notas (opcional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: notesCtrl,
            maxLines: 2,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Reglas, acuerdos, etc.',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // ── Asignación aleatoria ──────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.kolekta.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.kolekta.border),
            ),
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: randomize
                      ? AppColors.primarySurface
                      : context.kolekta.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shuffle_rounded,
                    size: 18,
                    color: randomize
                        ? AppColors.primary
                        : AppColors.orange),
              ),
              title: Text('Asignación aleatoria',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: context.kolekta.textPrimary)),
              subtitle: Text(
                randomize
                    ? 'Los números se asignan al azar'
                    : 'Cada participante elige su número',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.kolekta.textSecondary),
              ),
              value: randomize,
              activeThumbColor: AppColors.primary,
              onChanged: onRandomizeChanged,
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Paso 2: Participantes ─────────────────────────────────

class _StepParticipants extends StatefulWidget {
  const _StepParticipants({
    super.key,
    required this.participants,
    required this.totalSlots,
    required this.entryPrice,
    required this.randomize,
    required this.onPickContact,
  });

  final List<_ParticipantRow> participants;
  final int totalSlots;
  final double entryPrice;
  final bool randomize;
  final Future<void> Function(int index) onPickContact;

  @override
  State<_StepParticipants> createState() => _StepParticipantsState();
}

class _StepParticipantsState extends State<_StepParticipants> {
  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final payout = widget.entryPrice * widget.totalSlots;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: widget.participants.length,
      itemBuilder: (context, i) {
        final p = widget.participants[i];
        final number = i + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado del número ───────────────
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$number',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.primary,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Número $number',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: c.textPrimary)),
                        Text(
                          'Cobra: \$${NumberFormat('#,##0', 'es').format(payout)}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  // ── Botón de seleccionar contacto ───
                  IconButton(
                    onPressed: () => widget.onPickContact(i),
                    icon: Icon(
                      Icons.person_search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: 'Seleccionar contacto',
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  // ELIMINADO: el input de número (row/assignedNumber)
                  // El número de turno se infiere del orden (i + 1) automáticamente.
                ],
              ),

              const SizedBox(height: 10),

              // ── Nombre ──────────────────────────────
              TextFormField(
                controller: p.nameCtrl,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Nombre del participante (opcional)',
                  hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.person_outline_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 8),

              // ── Teléfono ─────────────────────────────
              TextFormField(
                controller: p.phoneCtrl,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Teléfono (opcional)',
                  hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────

class _ParticipantRow {
  final int number;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  // numberCtrl ya no se usa en la UI pero se conserva para compatibilidad
  final TextEditingController numberCtrl;

  _ParticipantRow({required this.number})
      : numberCtrl = TextEditingController(text: '$number');

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    numberCtrl.dispose();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelMedium
            .copyWith(color: context.kolekta.textPrimary));
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator(
      {required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 2 : 0),
            color: active ? AppColors.primary : context.kolekta.divider,
          ),
        );
      }),
    );
  }
}