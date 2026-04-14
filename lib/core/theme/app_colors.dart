import 'package:flutter/material.dart';

/// Paleta de colores oficial de Kolekta
/// Derivada del logo: azul marino, verde, naranja/amarillo
class AppColors {
  AppColors._();

  // ── Primarios ──────────────────────────────────────────
  static const Color primary = Color(0xFF1E3A8A); // Azul marino
  static const Color primaryLight = Color(0xFF3B5FCC); // Azul medio
  static const Color primarySurface = Color(0xFFEEF2FF); // Azul muy suave

  // Colores de los personajes/características (del logo original)

  static const Color greenMedium = Color(0xFF10B981); // Verde más brillante (botones en Catálogo)

  // ── Secundarios ────────────────────────────────────────
  static const Color green = Color(0xFF22C55E); // Verde – Catálogo
  static const Color greenLight = Color(0xFFDCFCE7); // Verde suave
  static const Color orange = Color(0xFFF59E0B); // Naranja – Rifas / accento
  static const Color orangeLight = Color(0xFFFEF3C7); // Naranja suave
  static const Color purple = Color(0xFF818CF8); // Morado – Tandas
  static const Color purpleLight = Color(0xFFEDE9FE); // Morado suave
  static const Color pink = Color(0xFFF472B6); // Rosa – variante rifas
  static const Color pinkLight = Color(0xFFFCE7F3); // Rosa suave

  // ── Fondo & Superficie ─────────────────────────────────
  static const Color background = Color(0xFFF5F3EE); // Crema (fondo general)
  static const Color surface = Color(0xFFFFFFFF); // Blanco (tarjetas)
  static const Color surfaceVariant = Color(0xFFF8F7F4); // Gris muy suave

  // ── Texto ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFFB0BAC5);

  // ── Semánticos ─────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color statusCompleted = Color(0xFFE5E7EB); // Gris (para 'Completada')
  static const Color statusCompletedText = Color(0xFF6B7280);
  static const Color statusPending = Color(0xFFFEE2E2); // Rosa (para 'Pendiente')
  static const Color statusPendingText = Color(0xFFEF4444);
  static const Color statusDelivered = Color(0xFFEDE9FE); // Morado (para 'Entregado')
  static const Color statusDeliveredText = Color(0xFF6D28D9);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ── Bordes ─────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
}
