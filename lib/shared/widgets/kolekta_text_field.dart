import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class KolektaTextField extends StatefulWidget {
  const KolektaTextField({
    super.key,
    this.controller,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.isPassword = false,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.inputFormatters,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool isPassword;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final int maxLines;

  @override
  State<KolektaTextField> createState() => _KolektaTextFieldState();
}

class _KolektaTextFieldState extends State<KolektaTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    Widget? finalSuffixIcon;

    if (widget.isPassword) {
      finalSuffixIcon = IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: AppColors.textHint,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    } else {
      finalSuffixIcon =
          widget.suffixIcon; // <--- Usar el que pasaste desde afuera
    }

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscure,
      textInputAction: widget.textInputAction,
      style: AppTextStyles.bodyMedium,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        enabled: widget.enabled,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20)
            : null,
        suffixIcon: finalSuffixIcon,
      ),
    );
  }
}
