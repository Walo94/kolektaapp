// lib/shared/widgets/kolekta_pagination.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/kolekta_colors.dart';

/// Widget de paginación reutilizable.
/// Muestra un botón "Cargar más" con el conteo de elementos mostrados vs total.
///
/// Uso:
/// ```dart
/// KolektaPagination(
///   loaded: provider.sales.length,
///   total: provider.total,
///   hasMore: provider.hasMore,
///   onLoadMore: () => provider.loadMore(token),
/// )
/// ```
class KolektaPagination extends StatelessWidget {
  const KolektaPagination({
    super.key,
    required this.loaded,
    required this.total,
    required this.hasMore,
    required this.onLoadMore,
    this.isLoading = false,
  });

  final int loaded;
  final int total;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Contador de registros
          Text(
            'Mostrando $loaded de $total',
            style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
          ),
          if (hasMore) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onLoadMore,
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  isLoading ? 'Cargando...' : 'Cargar más',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}