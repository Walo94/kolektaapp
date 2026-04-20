// product_form_screen.dart
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

class ProductFormScreen extends StatefulWidget {
  final Product? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  File? _pickedImage;
  bool _removeImage = false;
  bool _imageLoading = false;

  bool get _isEdit => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _descCtrl.text = widget.productToEdit!.description;
      _priceCtrl.text = widget.productToEdit!.price.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
      _removeImage = false;
    });
  }

  Future<String?> _toBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error convirtiendo imagen a base64: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      _showError('No hay sesión activa');
      return;
    }

    final prov = context.read<ProductProvider>();
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;

    String? imageBase64;
    if (_pickedImage != null) {
      setState(() => _imageLoading = true);
      imageBase64 = await _toBase64(_pickedImage!);
      setState(() => _imageLoading = false);
    }

    bool ok;
    if (_isEdit) {
      ok = await prov.updateProduct(
        token: token,
        id: widget.productToEdit!.id,
        description: _descCtrl.text.trim(),
        price: price,
        imageBase64: imageBase64,
        removeImage: _removeImage,
      );
    } else {
      final created = await prov.createProduct(
        token: token,
        description: _descCtrl.text.trim(),
        price: price,
        imageBase64: imageBase64,
      );
      ok = created != null;
    }

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      _showError(prov.errorMessage ?? 'Error al guardar el producto');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final loading = context.watch<ProductProvider>().actionLoading || _imageLoading;

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
          _isEdit ? 'Editar producto' : 'Nuevo producto',
          style: AppTextStyles.headingSmall.copyWith(color: c.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Imagen
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border),
                  ),
                  child: _buildImagePreview(c),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.photo_library_outlined,
                    size: 18, color: AppColors.green),
                label: Text(
                  _pickedImage != null ||
                          (widget.productToEdit?.imageUrl != null && !_removeImage)
                      ? 'Cambiar imagen'
                      : 'Agregar imagen',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.green),
                ),
              ),
            ),

            if ((_pickedImage != null ||
                    (widget.productToEdit?.imageUrl != null && !_removeImage)) &&
                !_removeImage)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _pickedImage = null;
                    _removeImage = true;
                  }),
                  child: Text(
                    'Quitar imagen',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Descripción
            KolektaTextField(
              controller: _descCtrl,
              hint: 'Descripción del producto *',
              prefixIcon: Icons.label_outline_rounded,
              maxLines: 2,
              validator: (v) => v!.trim().isEmpty ? 'Ingresa una descripción' : null,
            ),
            const SizedBox(height: 16),

            // Precio
            KolektaTextField(
              controller: _priceCtrl,
              hint: 'Precio *',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (v) {
                final n = double.tryParse(v?.replaceAll(',', '') ?? '');
                if (n == null || n <= 0) return 'Ingresa un precio válido';
                return null;
              },
            ),

            const SizedBox(height: 40),

            KolektaButton(
              label: _isEdit ? 'Guardar cambios' : 'Registrar producto',
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

  Widget _buildImagePreview(KolektaColors c) {
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(_pickedImage!, fit: BoxFit.cover),
      );
    }

    if (widget.productToEdit?.imageUrl != null && !_removeImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _SafeNetworkImage(
          imageUrl: widget.productToEdit!.imageUrl!,
          c: c,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 42, color: c.textHint),
        const SizedBox(height: 8),
        Text('Agregar foto',
            style: AppTextStyles.labelSmall.copyWith(color: c.textHint)),
      ],
    );
  }
}

// Widget reutilizable y seguro para imágenes de red
class _SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final KolektaColors c;

  const _SafeNetworkImage({required this.imageUrl, required this.c});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 300,
      cacheHeight: 300,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: c.surfaceVariant,
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.green,
              strokeWidth: 2.5,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error cargando imagen: $error');
        return Container(
          color: c.surfaceVariant,
          child: Icon(Icons.broken_image_outlined, color: c.textHint, size: 42),
        );
      },
    );
  }
}