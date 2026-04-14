import 'package:flutter/material.dart';

/// Extensión de tema que contiene todos los colores semánticos de Kolekta.
/// Se registra dentro de [ThemeData.extensions] para que cualquier widget
/// pueda leerla con:
///   final c = Theme.of(context).kolekta;
///
/// Los colores que NUNCA cambian (verde, morado, rosa, naranja de marca)
/// siguen viviendo en [AppColors] como const.
/// Los colores que SÍ cambian entre claro/oscuro (fondo, superficie, texto,
/// bordes) viven aquí.
class KolektaColors extends ThemeExtension<KolektaColors> {
  const KolektaColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.divider,
    required this.primarySurface,
    // Variantes suaves que invierten en oscuro
    required this.greenLight,
    required this.purpleLight,
    required this.pinkLight,
    required this.orangeLight,
    required this.successLight,
    required this.statusCompleted,
    required this.statusCompletedText,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color divider;
  final Color primarySurface;
  final Color greenLight;
  final Color purpleLight;
  final Color pinkLight;
  final Color orangeLight;
  final Color successLight;
  final Color statusCompleted;
  final Color statusCompletedText;

  // ── Tema claro ────────────────────────────────────────────
  static const light = KolektaColors(
    background: Color(0xFFF5F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF8F7F4),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF64748B),
    textHint: Color(0xFFB0BAC5),
    border: Color(0xFFE2E8F0),
    divider: Color(0xFFF1F5F9),
    primarySurface: Color(0xFFEEF2FF),
    greenLight: Color(0xFFDCFCE7),
    purpleLight: Color(0xFFEDE9FE),
    pinkLight: Color(0xFFFCE7F3),
    orangeLight: Color(0xFFFEF3C7),
    successLight: Color(0xFFD1FAE5),
    statusCompleted: Color(0xFFE5E7EB),
    statusCompletedText: Color(0xFF6B7280),
  );

  // ── Tema oscuro ───────────────────────────────────────────
  static const dark = KolektaColors(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceVariant: Color(0xFF263348),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textHint: Color(0xFF475569),
    border: Color(0xFF334155),
    divider: Color(0xFF1E293B),
    primarySurface: Color(0xFF1E3060),
    greenLight: Color(0xFF14532D),
    purpleLight: Color(0xFF2E1065),
    pinkLight: Color(0xFF4A0D2E),
    orangeLight: Color(0xFF451A03),
    successLight: Color(0xFF14532D),
    statusCompleted: Color(0xFF374151),
    statusCompletedText: Color(0xFF9CA3AF),
  );

  @override
  KolektaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? border,
    Color? divider,
    Color? primarySurface,
    Color? greenLight,
    Color? purpleLight,
    Color? pinkLight,
    Color? orangeLight,
    Color? successLight,
    Color? statusCompleted,
    Color? statusCompletedText,
  }) {
    return KolektaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primarySurface: primarySurface ?? this.primarySurface,
      greenLight: greenLight ?? this.greenLight,
      purpleLight: purpleLight ?? this.purpleLight,
      pinkLight: pinkLight ?? this.pinkLight,
      orangeLight: orangeLight ?? this.orangeLight,
      successLight: successLight ?? this.successLight,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCompletedText: statusCompletedText ?? this.statusCompletedText,
    );
  }

  @override
  KolektaColors lerp(KolektaColors? other, double t) {
    if (other == null) return this;
    return KolektaColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      greenLight: Color.lerp(greenLight, other.greenLight, t)!,
      purpleLight: Color.lerp(purpleLight, other.purpleLight, t)!,
      pinkLight: Color.lerp(pinkLight, other.pinkLight, t)!,
      orangeLight: Color.lerp(orangeLight, other.orangeLight, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
      statusCompletedText:
          Color.lerp(statusCompletedText, other.statusCompletedText, t)!,
    );
  }
}

/// Acceso rápido desde cualquier BuildContext.
/// Uso: `final c = context.kolekta;`
extension KolektaColorsX on BuildContext {
  KolektaColors get kolekta =>
      Theme.of(this).extension<KolektaColors>() ?? KolektaColors.light;
}