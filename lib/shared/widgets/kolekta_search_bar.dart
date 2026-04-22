// lib/shared/widgets/kolekta_search_bar.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/kolekta_colors.dart';

/// Barra de búsqueda reutilizable que se superpone al header.
///
/// Uso (en cualquier screen con header propio):
/// ```dart
/// // 1. Agrega a tu State:
/// bool _searchOpen = false;
///
/// // 2. Envuelve tu header + contenido:
/// KolektaSearchBar(
///   isOpen: _searchOpen,
///   hintText: 'Buscar tanda o participante…',
///   onSearch: (query) => _doSearch(query),
///   onClose: () => setState(() => _searchOpen = false),
///   child: Column(children: [ /* tu header normal */ ... ]),
/// )
/// ```
class KolektaSearchBar extends StatefulWidget {
  const KolektaSearchBar({
    super.key,
    required this.isOpen,
    required this.hintText,
    required this.onSearch,
    required this.onClose,
    required this.child,
    this.debounceMs = 400,
  });

  /// Si true, la barra está visible y cubre el header.
  final bool isOpen;

  /// Placeholder del campo de texto.
  final String hintText;

  /// Callback con el texto de búsqueda (se llama tras el debounce).
  final ValueChanged<String> onSearch;

  /// Callback al presionar la "×".
  final VoidCallback onClose;

  /// El widget hijo (header + contenido normal) que queda debajo.
  final Widget child;

  /// Milisegundos de debounce antes de disparar [onSearch].
  final int debounceMs;

  @override
  State<KolektaSearchBar> createState() => _KolektaSearchBarState();
}

class _KolektaSearchBarState extends State<KolektaSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    if (widget.isOpen) _animCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(KolektaSearchBar old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      if (widget.isOpen) {
        _animCtrl.forward();
        Future.microtask(() => _focus.requestFocus());
      } else {
        _animCtrl.reverse();
        _textCtrl.clear();
        _debounce?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _textCtrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
      widget.onSearch(value.trim());
    });
  }

  void _onClearText() {
    _textCtrl.clear();
    _focus.requestFocus();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final safeTop = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Contenido normal (header + tabs + lista) ──────────
        widget.child,

        // ── Overlay de búsqueda ───────────────────────────────
        if (widget.isOpen)
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                color: c.background, // cubre completamente el header
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: safeTop + 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // ── Campo de texto ────────────────────
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(Icons.search_rounded,
                                      size: 20, color: c.textHint),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _textCtrl,
                                      focusNode: _focus,
                                      onChanged: _onChanged,
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(color: c.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: widget.hintText,
                                        hintStyle: AppTextStyles.bodyMedium
                                            .copyWith(color: c.textHint),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (v) =>
                                          widget.onSearch(v.trim()),
                                    ),
                                  ),
                                  // ── Limpiar texto ──────────────
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _textCtrl,
                                    builder: (_, val, __) => val.text.isNotEmpty
                                        ? GestureDetector(
                                            onTap: _onClearText,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: Icon(
                                                Icons.cancel_rounded,
                                                size: 18,
                                                color: c.textHint,
                                              ),
                                            ),
                                          )
                                        : const SizedBox(width: 8),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // ── Botón cerrar ──────────────────────
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border),
                              ),
                              child: Icon(Icons.close_rounded,
                                  size: 20, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}