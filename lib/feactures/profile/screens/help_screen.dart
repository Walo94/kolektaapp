import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // Función para abrir URL de forma segura
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication, // Abre en navegador externo
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir $urlString'),
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
          'Centro de ayuda',
          style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary),
        ),
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Banner de bienvenida / búsqueda rápida
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Cómo te podemos ayudar?',
                      style: AppTextStyles.headingLarge.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Encuentra respuestas rápidas o contáctanos directamente.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Preguntas frecuentes
              Text(
                'Preguntas frecuentes',
                style: AppTextStyles.headingSmall.copyWith(
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _FaqCategory(
                title: 'General',
                icon: Icons.help_outline_rounded,
                iconBg: c.orangeLight,
                iconColor: AppColors.orange,
                questions: _generalFaqs,
              ),

              const SizedBox(height: 20),

              _FaqCategory(
                title: 'Tandas',
                icon: Icons.groups_rounded,
                iconBg: c.purpleLight,
                iconColor: AppColors.purple,
                imagePath: 'assets/images/batch.png',
                questions: _tandasFaqs,
              ),

              const SizedBox(height: 20),

              _FaqCategory(
                title: 'Ventas por Catálogo',
                icon: Icons.shopping_bag_outlined,
                iconBg: c.greenLight,
                iconColor: AppColors.green,
                imagePath: 'assets/images/catalog.png',
                questions: _catalogoFaqs,
              ),

              const SizedBox(height: 20),

              _FaqCategory(
                title: 'Rifas',
                icon: Icons.card_giftcard_rounded,
                iconBg: c.pinkLight,
                iconColor: AppColors.pink,
                imagePath: 'assets/images/giveaway.png',
                questions: _rifasFaqs,
              ),

              const SizedBox(height: 32),

              // Opciones de contacto
              Text(
                '¿No encontraste lo que buscabas?',
                style: AppTextStyles.headingSmall.copyWith(
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _SettingsGroup(items: [
                _ContactItem(
                  icon: Icons.email_outlined,
                  iconBg: c.orangeLight,
                  iconColor: AppColors.orange,
                  title: 'Enviar correo',
                  subtitle: 'contacto@gamezdev.com.mx',
                  onTap: () {
                    Clipboard.setData(
                        const ClipboardData(text: 'contacto@gamezdev.com.mx'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Correo copiado al portapapeles'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
                _ContactItem(
                  icon: Icons.help_center_outlined,
                  iconBg: c.purpleLight,
                  iconColor: AppColors.purple,
                  title: 'Visitar centro de ayuda web',
                  subtitle: 'kolekta.gamezdev.com.mx',
                  onTap: () =>
                      _launchURL('https://kolekta.gamezdev.com.mx/#faq'),
                ),
              ]),

              const SizedBox(height: 40),

              Center(
                child: Text(
                  'Kolekta v1.0.0 • Soporte',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: c.textHint,
                  ),
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
// Subwidgets reutilizables (estilo similar a ProfileScreen)
// ─────────────────────────────────────────────────────────────

class _FaqCategory extends StatelessWidget {
  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.questions,
    this.imagePath,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final List<Map<String, String>> questions;
  final String? imagePath;

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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: imagePath != null
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(imagePath!, fit: BoxFit.contain),
                  )
                : Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary),
          ),
          children: questions
              .map((faq) => _FaqItem(question: faq['q']!, answer: faq['a']!))
              .toList(),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          question,
          style: AppTextStyles.bodyMedium.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
            child: Text(
              answer,
              style: AppTextStyles.bodySmall.copyWith(
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});

  final List<_ContactItem> items;

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
      child: Column(
        children: List.generate(
          items.length,
          (i) => Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 60, endIndent: 16, color: c.divider),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Datos de FAQ (puedes expandir o modificar fácilmente)
// ─────────────────────────────────────────────────────────────

final List<Map<String, String>> _generalFaqs = [
  {
    'q': '¿Qué es Kolekta?',
    'a':
        'Kolekta es una plataforma que te permite organizar tandas, vender y administrar por catálogo y crear rifas de forma sencilla y segura. Ideal para emprendedores, grupos de amigos, familias y pequeños negocios.'
  },
  {
    'q': '¿Es gratis usar Kolekta?',
    'a':
        'Sí, Kolekta es completamente gratuita. Sin suscripciones, sin sorpresas. Si te es útil, una donación voluntaria nos ayuda a seguir mejorando.'
  },
  {
    'q': '¿Cómo recupero mi contraseña?',
    'a':
        'En la pantalla de inicio de sesión, toca "¿Olvidaste tu contraseña?" e ingresa tu correo. Te enviaremos un enlace para restablecerla.'
  },
];

final List<Map<String, String>> _tandasFaqs = [
  {
    'q': '¿Cómo funciona una tanda en Kolekta?',
    'a':
        'Una tanda es un ahorro grupal donde cada participante aporta una cantidad fija cada periodo (semana, quinca, mes). Al final de cada ronda, uno de los participantes recibe el total acumulado.'
  },
  {
    'q': '¿Puedo eliminar o cancelar una tanda?',
    'a':
        'Sí, el administrador puede eliminar la tanda o cancelarla antes de que inicie. Una vez iniciada, las cancelaciones están sujetas a las reglas del grupo.'
  },
  {
    'q': '¿Como se manejan los pagos en la aplicación?',
    'a':
        'Por ahora kolekta no administra transacciones o pagos de dinero real, el administrador se debe de encargar de marcar como entregado cada número'
  },
];

final List<Map<String, String>> _catalogoFaqs = [
  {
    'q': '¿Cómo vendo por catálogo?',
    'a':
        'Sube tus productos con fotos, precios y descripción. Crea una venta seleccionando un cliente, puedes agregar tus productos o solo agregar la descripción y precio sin tenerlo registrado.'
  },
  {
    'q': '¿Los clientes pueden pagar en línea?',
    'a': 'Por ahora es una función que esta en desarrollo.'
  },
];

final List<Map<String, String>> _rifasFaqs = [
  {
    'q': '¿Cómo creo una rifa?',
    'a':
        'Ve a la sección de Rifas, toca "Nueva rifa", agrega el premio, precio del boleto, cantidad de boletos y fecha del sorteo. ¡Listo!.'
  },
  {
    'q': '¿Cómo se realiza el sorteo?',
    'a':
        'Al crear una rifa puedes configurar que el sorteo sea automático, también puedes realizar el sorteo manual ingresando los números ganadores, esto por si lo manejas con la lotería nacional.'
  },
  {
    'q': '¿Puedo vender boletos físicos y digitales?',
    'a':
        'Puedes vender solo boletos digitales, selecciona un número y asigan el cliente, puedes marcarlo como pagado o apartado, también puedes compartir el link de la rifa para que tus clientes puedan apartar sus boletos.'
  },
];
