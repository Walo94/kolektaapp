// lib/shared/widgets/kolekta_search_results.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/kolekta_colors.dart';
import '../../shared/widgets/kolekta_pagination.dart';

/// Modelo genérico de resultado de búsqueda por grupo/status.
class SearchResultGroup<T> {
  final String label;
  final List<T> items;
  final int total;
  final bool hasMore;

  const SearchResultGroup({
    required this.label,
    required this.items,
    required this.total,
    required this.hasMore,
  });
}

/// Widget que muestra resultados de búsqueda agrupados por sección.
/// Cada grupo tiene su propio "Cargar más".
///
/// Uso:
/// ```dart
/// KolektaSearchResults<Batch>(
///   query: _query,
///   isLoading: provider.searchLoading,
///   groups: [
///     SearchResultGroup(label: 'Activas', items: provider.searchActive, ...),
///     SearchResultGroup(label: 'Terminadas', items: provider.searchFinished, ...),
///     SearchResultGroup(label: 'Canceladas', items: provider.searchCancelled, ...),
///   ],
///   itemBuilder: (item) => _BatchCard(batch: item, ...),
///   onLoadMore: (groupIndex) => provider.searchLoadMore(token, groupIndex),
///   emptyMessage: 'Sin resultados para',
/// )
/// ```
class KolektaSearchResults<T> extends StatelessWidget {
  const KolektaSearchResults({
    super.key,
    required this.query,
    required this.isLoading,
    required this.groups,
    required this.itemBuilder,
    required this.onLoadMore,
    this.emptyMessage = 'Sin resultados para',
  });

  final String query;
  final bool isLoading;
  final List<SearchResultGroup<T>> groups;
  final Widget Function(T item) itemBuilder;
  final void Function(int groupIndex) onLoadMore;
  final String emptyMessage;

  bool get _hasAnyResult => groups.any((g) => g.items.isNotEmpty);

  /// Construye la lista de widgets para un grupo dado.
  List<Widget> _buildGroup(
    BuildContext context,
    int gi,
    SearchResultGroup<T> group,
  ) {
    final c = context.kolekta;
    if (group.items.isEmpty) return [];

    return [
      // ── Encabezado de sección ──────────────────────────
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(
          children: [
            _GroupDot(index: gi),
            const SizedBox(width: 8),
            Text(
              group.label,
              style:
                  AppTextStyles.labelMedium.copyWith(color: c.textSecondary),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Text(
                '${group.total}',
                style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
              ),
            ),
          ],
        ),
      ),

      // ── Items ──────────────────────────────────────────
      for (final item in group.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: itemBuilder(item),
        ),

      // ── Paginación por grupo ───────────────────────────
      KolektaPagination(
        loaded: group.items.length,
        total: group.total,
        hasMore: group.hasMore,
        onLoadMore: () => onLoadMore(gi),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    if (isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (query.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 48, color: c.textHint),
              const SizedBox(height: 12),
              Text(
                'Escribe para buscar',
                style: AppTextStyles.bodyMedium.copyWith(color: c.textHint),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasAnyResult) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: c.textHint),
              const SizedBox(height: 12),
              Text(
                '$emptyMessage "$query"',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Aplanamos los grupos en una sola lista de widgets
    final groupWidgets = <Widget>[];
    for (int gi = 0; gi < groups.length; gi++) {
      groupWidgets.addAll(_buildGroup(context, gi, groups[gi]));
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: groupWidgets,
      ),
    );
  }
}

/// Punto de color por grupo (Activas=verde, Terminadas=azul, Canceladas=rojo)
class _GroupDot extends StatelessWidget {
  const _GroupDot({required this.index});
  final int index;

  static const _colors = [
    AppColors.success,
    Color(0xFF2563EB), // blue-600
    AppColors.error,
  ];

  @override
  Widget build(BuildContext context) {
    final color = index < _colors.length ? _colors[index] : AppColors.primary;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}