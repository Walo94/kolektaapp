import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';
import '../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _setupDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // ── Deep Links: kolekta://subscription/success ─────────────────────────────
    // ── Deep Links: kolekta://subscription/success ─────────────────────────────
  void _setupDeepLinks() {
  _appLinks.uriLinkStream.listen((Uri? uri) async {
    if (uri == null || !mounted) return;

    print('🔗 Deep link recibido: ${uri.toString()}');

    if (uri.scheme == 'kolekta' && uri.host == 'subscription') {
      final String path = uri.path;
      final auth = context.read<AuthProvider>();
      final sub = context.read<SubscriptionProvider>();

      if (path == '/success') {
        print('✅ SUCCESS deep link - Refrescando...');
        await auth.refreshUserInfo();

        // Esperamos un poco más para que Stripe procese el webhook
        await Future.delayed(const Duration(milliseconds: 2500));

        await sub.refresh(token: auth.token!);

        if (mounted) {
          _showSuccessSnackBar();
          // Forzamos navegación limpia para evitar conflicto con GoRouter
          context.go(AppRoutes.subscription);
        }
      } 
      else if (path == '/cancel' || path == '/portal-return') {
        print('🔄 Cancel/Portal return - Refrescando...');
        await Future.delayed(const Duration(milliseconds: 1500));
        await sub.refresh(token: auth.token!);

        if (mounted) {
          context.go(AppRoutes.subscription);
        }
      }
    }
  });
}

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: const Text('¡Suscripción activada exitosamente!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    if (auth.token == null) return;

    await Future.wait(
        [auth.refreshUserInfo(), sub.refresh(token: auth.token!)]);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showError('No se pudo abrir el enlace');
    }
  }

  Future<void> _subscribe(String priceId) async {
    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    if (auth.token == null) return;

    final url = await sub.createCheckout(token: auth.token!, priceId: priceId);
    if (url != null)
      await _launchUrl(url);
    else if (sub.errorMessage != null) _showError(sub.errorMessage!);
  }

  Future<void> _openPortal() async {
    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    if (auth.token == null) return;

    final url = await sub.createPortalSession(token: auth.token!);
    if (url != null)
      await _launchUrl(url);
    else if (sub.errorMessage != null) _showError(sub.errorMessage!);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: c.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
          title: Text('Suscripción',
              style:
                  AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
          actions: [
            if (!sub.isLoading)
              IconButton(
                  icon: Icon(Icons.refresh_rounded, color: c.textSecondary),
                  onPressed: _loadData)
          ]),
      body: sub.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: CustomScrollView(slivers: [
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    sliver: SliverList(
                        delegate: SliverChildListDelegate([
                      _buildStatusCard(sub, c),
                      const SizedBox(height: 24),
                      _buildPlansSectionIfNeeded(sub, c),
                      const SizedBox(height: 24),
                      if (sub.hasActiveSubscription)
                        _buildManageSection(sub, c),
                      const SizedBox(height: 24)
                    ])))
              ])),
    );
  }

  // ── Estado (Premium o Free) ─────────────────────────────────────
  Widget _buildStatusCard(SubscriptionProvider sub, KolektaColors c) {
    if (sub.subscription != null && sub.subscription!.status == 'active') {
      return _PremiumStatusCard(subscription: sub.subscription!, c: c);
    }
    return _FreeStatusCard(c: c);
  }

  // ── Mostrar planes SOLO si NO hay suscripción activa ───────
  Widget _buildPlansSectionIfNeeded(SubscriptionProvider sub, KolektaColors c) {
    if (sub.hasActiveSubscription) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elige tu plan',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        const SizedBox(height: 4),
        Text('Desbloquea todas las funciones de Kolekta',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        const SizedBox(height: 16),
        _PlanCard(
            title: 'Mensual',
            price: '\$49',
            period: '/mes',
            description: 'Facturado mensualmente',
            badge: null,
            isPopular: false,
            color: AppColors.primaryLight,
            lightColor: c.primarySurface,
            icon: Icons.calendar_month_rounded,
            isLoading: sub.checkoutLoading,
            onTap: () => _subscribe(SubscriptionService.priceMonthly),
            c: c),
        const SizedBox(height: 12),
        _PlanCard(
            title: 'Anual',
            price: '\$450',
            period: '/año',
            description: 'Equivale a \$37.50/mes · Ahorra \$138',
            badge: 'MEJOR PRECIO',
            isPopular: true,
            color: AppColors.green,
            lightColor: c.greenLight,
            icon: Icons.workspace_premium_rounded,
            isLoading: sub.checkoutLoading,
            onTap: () => _subscribe(SubscriptionService.priceAnnual),
            c: c),
      ],
    );
  }

  // ── Gestionar suscripción (solo si está activa) ─────────────
  Widget _buildManageSection(SubscriptionProvider sub, KolektaColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gestionar suscripción',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: _ManageOption(
            icon: Icons.settings_rounded,
            label: 'Gestionar suscripción',
            subtitle: 'Cambiar plan o cancelar',
            color: AppColors.primaryLight,
            isLoading: sub.portalLoading,
            onTap: _openPortal,
            c: c,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La gestión se realiza de forma segura a través del portal de Stripe.',
          style: AppTextStyles.labelSmall.copyWith(color: c.textHint),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ═══════════════════════════════════════════════════════════════════════════

// ── Tarjeta: Plan FREE ────────────────────────────────────────────────────
class _FreeStatusCard extends StatelessWidget {
  final KolektaColors c;
  const _FreeStatusCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: c.textSecondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan gratuito',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('Suscríbete para desbloquear todas las funciones',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta: PREMIUM activo ───────────────────────────────────────────────
class _PremiumStatusCard extends StatelessWidget {
  final SubscriptionInfo subscription;
  final KolektaColors c;
  const _PremiumStatusCard({required this.subscription, required this.c});

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('d MMM yyyy', 'es').format(subscription.currentPeriodEnd);
    final planLabel = subscription.planType == 'annual' ? 'Anual' : 'Mensual';
    final planIcon = subscription.planType == 'annual'
        ? Icons.workspace_premium_rounded
        : Icons.calendar_month_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B5FCC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(planIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                // ← Esto evita el overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium · $planLabel',
                        style: AppTextStyles.headingSmall
                            .copyWith(color: Colors.white)),
                    if (subscription.cancelAtPeriodEnd)
                      Text('Se cancelará al final del periodo',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.orange[200]))
                    else
                      Text('Activa · Renovación automática',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.event_repeat_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subscription.cancelAtPeriodEnd
                        ? 'Acceso hasta el $formattedDate'
                        : 'Próxima renovación: $formattedDate',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de plan disponible ────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String description;
  final String? badge;
  final bool isPopular;
  final Color color;
  final Color lightColor;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;
  final KolektaColors c;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.description,
    required this.badge,
    required this.isPopular,
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.isLoading,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? color.withOpacity(0.5) : c.border,
            width: isPopular ? 1.5 : 1,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: c.textPrimary)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style:
                            AppTextStyles.headingMedium.copyWith(color: color),
                      ),
                      TextSpan(
                        text: period,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Elegir',
                            style: AppTextStyles.buttonMedium
                                .copyWith(color: Colors.white)),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Opción de gestión ─────────────────────────────────────────────────────
class _ManageOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  final KolektaColors c;

  const _ManageOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelLarge.copyWith(color: c.textPrimary)),
                  Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.arrow_forward_ios_rounded, color: c.textHint, size: 14),
          ],
        ),
      ),
    );
  }
}
