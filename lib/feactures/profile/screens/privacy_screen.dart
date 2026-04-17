import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(
          'Privacidad y datos',
          style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Banner introductorio
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 48,
                      color: AppColors.purple,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu privacidad es nuestra prioridad',
                      style: AppTextStyles.headingLarge.copyWith(
                        color: c.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En Kolekta tratamos tus datos con total confidencialidad y solo los usamos para que la app funcione correctamente.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sección 1: Datos que recolectamos
              _SectionTitle(title: 'Datos que recolectamos'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _BulletItem(text: 'Correo electrónico y número de teléfono'),
                  _BulletItem(text: 'Nombre completo'),
                  _BulletItem(
                    text: 'Fotos de tandas, rifas y productos de ventas (almacenadas en Cloudinary)',
                  ),
                  _BulletItem(
                    text: 'Información de las tandas, ventas y rifas que creas o en las que participas',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No guardamos fotos de perfil ni listas completas de tus contactos. Solo leemos temporalmente los contactos cuando tú decides seleccionar un participante.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: c.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección 2: Cómo usamos tus datos
              _SectionTitle(title: '¿Cómo usamos tus datos?'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'Solo utilizamos tu información para:',
                    style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _BulletItem(
                    text: 'Crear y gestionar tus tandas, ventas por catálogo y rifas',
                  ),
                  _BulletItem(
                    text: 'Notificarte sobre pagos, ganadores, recordatorios y actualizaciones',
                  ),
                  _BulletItem(
                    text: 'Permitirte seleccionar rápidamente participantes o compradores desde tu lista de contactos',
                  ),
                  _BulletItem(
                    text: 'Mostrar tu nombre en las tandas y rifas que creas o en las que participas',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nunca vendemos, compartimos ni publicamos tus datos personales. Todo se mantiene confidencial y solo se usa dentro del servicio de Kolekta.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: c.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección 3: Permisos de la aplicación
              _SectionTitle(title: 'Permisos que solicitamos'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _PermissionRow(
                    icon: Icons.contacts_outlined,
                    title: 'Lista de contactos',
                    description:
                        'Te permite seleccionar rápidamente participantes para tandas, compradores de ventas o boletos de rifas. Solo leemos nombre y teléfono temporalmente. No guardamos tu lista de contactos.',
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.camera_alt_outlined,
                    title: 'Cámara y galería',
                    description:
                        'Para que puedas tomar o seleccionar fotos de productos, premios, portadas de tandas o rifas. Estas fotos se suben directamente a Cloudinary.',
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notificaciones push',
                    description:
                        'Para enviarte alertas importantes sobre pagos pendientes, sorteos, ganadores y actualizaciones de tus actividades.',
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección 4: Tus derechos
              _SectionTitle(title: 'Tus derechos'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _BulletItem(text: 'Acceder a todos los datos que tenemos sobre ti'),
                  _BulletItem(text: 'Corregir o actualizar tu información personal'),
                  _BulletItem(text: 'Solicitar la eliminación completa de tu cuenta y todos tus datos'),
                  _BulletItem(text: 'Retirar consentimientos en cualquier momento'),
                ],
              ),

              const SizedBox(height: 32),

              // Botón de acción
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Escríbenos a soporte@kolekta.gamezdev.com.mx'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Solicitar mis datos o eliminar mi cuenta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: BorderSide(color: AppColors.purple.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Última actualización: 17 de abril de 2026',
                      style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kolekta v1.0.0',
                      style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets reutilizables (mismo estilo que ProfileScreen y HelpScreen)
// ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Text(
      title,
      style: AppTextStyles.headingSmall.copyWith(
        color: c.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: c.textSecondary, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.purpleLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.purple, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}