import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';

class ConditionsScreen extends StatelessWidget {
  const ConditionsScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:contacto@gamezdev.com.mx');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escríbenos a contacto@gamezdev.com.mx'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(
          'Términos y Condiciones',
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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gavel_rounded,
                        size: 34,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Términos y Condiciones',
                      style: AppTextStyles.headingLarge
                          .copyWith(color: c.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Al descargar o usar Kolekta, aceptas automáticamente los siguientes términos. Lee detenidamente antes de usar la aplicación.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Sección: Propiedad intelectual
              _SectionTitle(title: 'Propiedad intelectual'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'Está estrictamente prohibido:',
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  _BulletItem(
                      text:
                          'Copiar o modificar la aplicación o cualquier parte de ella'),
                  _BulletItem(
                      text:
                          'Intentar extraer el código fuente de la aplicación'),
                  _BulletItem(
                      text:
                          'Traducir la app a otros idiomas o crear versiones derivadas'),
                  const SizedBox(height: 8),
                  Text(
                    'Todas las marcas registradas, derechos de autor, derechos de bases de datos y demás derechos de propiedad intelectual relacionados con la aplicación permanecen siendo propiedad del proveedor.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Cambios en el servicio
              _SectionTitle(title: 'Cambios en el servicio'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'El proveedor se reserva el derecho de modificar la aplicación o cobrar por sus servicios en cualquier momento y por cualquier razón. Cualquier cargo será comunicado claramente.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Seguridad del dispositivo
              _SectionTitle(title: 'Seguridad de tu dispositivo'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'La aplicación almacena y procesa los datos personales que proporcionas. Eres responsable de mantener la seguridad de tu teléfono y el acceso a la app.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  _WarningChip(
                    icon: Icons.warning_amber_rounded,
                    text:
                        'Se desaconseja hacer jailbreak o root a tu teléfono, ya que puede exponer el dispositivo a malware, comprometer funciones de seguridad y causar que la app no funcione correctamente.',
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Conectividad y cargos
              _SectionTitle(title: 'Conectividad y cargos'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _BulletItem(
                      text:
                          'Algunas funciones requieren conexión a internet activa (Wi-Fi o datos móviles)'),
                  _BulletItem(
                      text:
                          'El proveedor no se hace responsable si la app no funciona por falta de acceso a internet'),
                  _BulletItem(
                      text:
                          'Aceptas la responsabilidad de cargos de datos, incluyendo roaming si usas la app fuera de tu país sin desactivar datos móviles'),
                  _BulletItem(
                      text:
                          'Si no eres el titular del plan de datos, se asume que tienes permiso del titular'),
                  _BulletItem(
                      text:
                          'El proveedor no se hace responsable si tu dispositivo se queda sin batería'),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Limitación de responsabilidad
              _SectionTitle(title: 'Limitación de responsabilidad'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'El proveedor se apoya en terceros para suministrar información que pone a tu disposición. No acepta responsabilidad por pérdidas directas o indirectas derivadas de confiar completamente en la funcionalidad de la aplicación.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Actualizaciones y terminación
              _SectionTitle(title: 'Actualizaciones y terminación'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'El proveedor puede desear actualizar la aplicación. Los requisitos del sistema operativo pueden cambiar y deberás descargar las actualizaciones para continuar usando la app.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  _WarningChip(
                    icon: Icons.info_outline_rounded,
                    text:
                        'El proveedor puede cesar el servicio en cualquier momento sin previo aviso. Al terminar, los derechos y licencias otorgados también concluyen.',
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Sección: Cambios en los términos
              _SectionTitle(title: 'Cambios en estos términos'),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  Text(
                    'Los Términos y Condiciones pueden actualizarse periódicamente. Se te aconseja revisar esta página regularmente. Los cambios entran en vigor en el momento de su publicación.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Botón de contacto
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launchEmail(context),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Contactar al proveedor'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
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
                      'Vigente desde: 22 de abril de 2026',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: context.kolekta.textHint),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'contacto@gamezdev.com.mx',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: context.kolekta.textHint),
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
// Widgets reutilizables
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

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.orangeLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.orange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
