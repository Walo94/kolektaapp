import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {

  // ── Función principal de refrescar ─────────────────────────────────────
  Future<void> _refreshUser() async {
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.refreshUserInfo();

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar( 
        content: const Text('Información actualizada'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al actualizar: ${authProvider.errorMessage ?? "Inténtalo de nuevo"}',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSnack(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '—';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final isEmailVerified = user?.emailVerified ?? false;
    final hasPhone = (user?.phone ?? '').isNotEmpty;

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
        title: Text('Información personal',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshUser,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Datos básicos ──────────────────────────────────
              Text('Datos de la cuenta',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),

              _SectionCard(
                children: [
                  // Nombre completo (solo lectura)
                  _InfoTile(
                    icon: Icons.person_outline_rounded,
                    iconBg: c.primarySurface,
                    iconColor: AppColors.primary,
                    label: 'Nombre completo',
                    value: auth.displayName,
                  ),
                  _Divider(),
                  // Correo electrónico con badge de verificación
                  _InfoTile(
                    icon: Icons.email_outlined,
                    iconBg: isEmailVerified ? c.successLight : c.orangeLight,
                    iconColor:
                        isEmailVerified ? AppColors.success : AppColors.orange,
                    label: 'Correo electrónico',
                    value: auth.displayEmail,
                    trailing: _VerifiedBadge(verified: isEmailVerified),
                  ),
                  _Divider(),
                  // Teléfono sin badge
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    iconBg: c.purpleLight,
                    iconColor: AppColors.purple,
                    label: 'Teléfono',
                    value: hasPhone ? auth.displayPhone : 'No registrado',
                  ),
                ],
              ),

              const SizedBox(height: 28),

              

              // ── Detalles ───────────────────────────────────────
              Text('Detalles',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),

              _SectionCard(
                children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    iconBg: c.purpleLight,
                    iconColor: AppColors.purple,
                    label: 'ID de usuario',
                    value: user?.id ?? '—',
                    trailing:
                        Icon(Icons.copy_rounded, size: 16, color: c.textHint),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user?.id ?? ''));
                      _showSnack(context, 'ID copiado al portapapeles');
                    },
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    iconBg: c.orangeLight,
                    iconColor: AppColors.orange,
                    label: 'Miembro desde',
                    value: _formatDate(user?.createdAt),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

/// Contenedor de tarjeta con sombra suave
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 60,
        endIndent: 16,
        color: context.kolekta.divider,
      );
}

/// Fila de dato de solo lectura
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg, iconColor;
  final String label, value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: c.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: c.textPrimary)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge de verificación — únicamente para el correo electrónico
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.success.withOpacity(0.12)
            : AppColors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 12,
            color: verified ? AppColors.success : AppColors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verificado' : 'Pendiente',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: verified ? AppColors.success : AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}