import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum KolektaButtonVariant { primary, secondary, outlined, ghost }

class KolektaButton extends StatelessWidget {
  const KolektaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KolektaButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.color,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final KolektaButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final Color? color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    Widget child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label, style: AppTextStyles.buttonLarge),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: switch (variant) {
        KolektaButtonVariant.primary => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: child,
          ),
        KolektaButtonVariant.secondary => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveColor.withOpacity(0.12),
              foregroundColor: effectiveColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: DefaultTextStyle(
              style: AppTextStyles.buttonLarge.copyWith(color: effectiveColor),
              child: child,
            ),
          ),
        KolektaButtonVariant.outlined => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: effectiveColor,
              side: BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: DefaultTextStyle(
              style: AppTextStyles.buttonLarge
                  .copyWith(color: AppColors.textPrimary),
              child: child,
            ),
          ),
        KolektaButtonVariant.ghost => TextButton(
            onPressed: isLoading ? null : onPressed,
            child: DefaultTextStyle(
              style: AppTextStyles.buttonMedium.copyWith(color: effectiveColor),
              child: child,
            ),
          ),
      },
    );
  }
}
