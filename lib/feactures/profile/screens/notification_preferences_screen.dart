// lib/feactures/profile/screens/notification_preferences_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/kolekta_colors.dart';
import '../../admin/providers/auth_provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<NotificationProvider>().loadPreferences(token);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final provider = context.watch<NotificationProvider>();

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
        title: Text('Preferencias',
            style: AppTextStyles.headingMedium.copyWith(color: c.textPrimary)),
        centerTitle: false,
      ),
      body: provider.prefsLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Intro ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Elige qué notificaciones deseas recibir. '
                            'Las desactivadas no aparecerán en tu bandeja.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Rifas ─────────────────────────────────────
                  Text('Rifas',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  _PrefsGroup(
                    items: _rifaPrefs(provider, c),
                  ),
                  const SizedBox(height: 24),

                  // ── Tandas ────────────────────────────────────
                  Text('Tandas',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  _PrefsGroup(
                    items: _tandaPrefs(provider, c),
                  ),
                  const SizedBox(height: 24),

                  // ── Próximamente ──────────────────────────────
                  _ComingSoonCard(c: c),
                ],
              ),
            ),
    );
  }

  // ── Builders por sección ──────────────────────────────────────────────────

  List<Widget> _rifaPrefs(NotificationProvider provider, KolektaColors c) {
    return [
      _PrefTile(
        icon: Icons.confirmation_num_outlined,
        iconBg: c.pinkLight,
        iconColor: AppColors.pink,
        title: 'Boleto apartado',
        subtitle: 'Cuando alguien reserva un boleto por tu link',
        type: NotificationType.giveawayTicketReserved,
        preferences: provider.preferences,
        onToggle: (val) =>
            _toggle(NotificationType.giveawayTicketReserved.value, val),
      ),
      _PrefTile(
        icon: Icons.emoji_events_outlined,
        iconBg: c.orangeLight,
        iconColor: AppColors.orange,
        title: 'Sorteo automático realizado',
        subtitle: 'Cuando el sistema ejecuta un sorteo automático',
        type: NotificationType.giveawayAutoDrawDone,
        preferences: provider.preferences,
        onToggle: (val) =>
            _toggle(NotificationType.giveawayAutoDrawDone.value, val),
      ),
      _PrefTile(
        icon: Icons.timer_outlined,
        iconBg: c.orangeLight,
        iconColor: AppColors.orange,
        title: 'Recordatorio de sorteo',
        subtitle: 'El día del sorteo cuando no es automático',
        type: NotificationType.giveawayDrawReminder,
        preferences: provider.preferences,
        onToggle: (val) =>
            _toggle(NotificationType.giveawayDrawReminder.value, val),
      ),
    ];
  }

  List<Widget> _tandaPrefs(NotificationProvider provider, KolektaColors c) {
    final pref =
        _prefFor(provider.preferences, NotificationType.batchDeliveryReminder);
    final days = pref?.daysBeforeDelivery ?? 0;

    return [
      _PrefTile(
        icon: Icons.sync_alt_rounded,
        iconBg: c.purpleLight,
        iconColor: AppColors.purple,
        title: 'Recordatorio de entrega',
        subtitle: 'Avisa cuando alguien en tu tanda recibe su dinero',
        type: NotificationType.batchDeliveryReminder,
        preferences: provider.preferences,
        onToggle: (val) =>
            _toggle(NotificationType.batchDeliveryReminder.value, val),
        extra: pref?.enabled == true
            ? _DaysBeforeSelector(
                current: days,
                onChanged: (d) => _setDays(d),
              )
            : null,
      ),
    ];
  }

  NotificationPreferenceModel? _prefFor(
      List<NotificationPreferenceModel> prefs, NotificationType type) {
    try {
      return prefs.firstWhere((p) => p.type == type);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggle(String type, bool enabled) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context
        .read<NotificationProvider>()
        .updatePreference(token, type, enabled: enabled);
  }

  Future<void> _setDays(int days) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<NotificationProvider>().updatePreference(
          token,
          NotificationType.batchDeliveryReminder.value,
          daysBeforeDelivery: days,
        );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PrefsGroup extends StatelessWidget {
  const _PrefsGroup({required this.items});
  final List<Widget> items;

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
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 60, endIndent: 16, color: c.divider),
            ],
          );
        }),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.preferences,
    required this.onToggle,
    this.extra,
  });

  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final NotificationType type;
  final List<NotificationPreferenceModel> preferences;
  final ValueChanged<bool> onToggle;
  final Widget? extra;

  bool _isEnabled() {
    try {
      return preferences.firstWhere((p) => p.type == type).enabled;
    } catch (_) {
      return true; // por defecto habilitado
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    final enabled = _isEnabled();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (extra != null && enabled) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: extra!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector de cuántos días antes para tandas
class _DaysBeforeSelector extends StatelessWidget {
  const _DaysBeforeSelector({
    required this.current,
    required this.onChanged,
  });

  final int current;
  final ValueChanged<int> onChanged;

  static const _options = [0, 1, 2, 3, 5, 7];

  @override
  Widget build(BuildContext context) {
    final c = context.kolekta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avisar con anticipación:',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _options.map((d) {
            final selected = d == current;
            final label = d == 0
                ? 'El mismo día'
                : d == 1
                    ? '1 día antes'
                    : '$d días antes';
            return GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.purple.withOpacity(0.15)
                      : c.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.purple : c.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.purple : c.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.c});
  final KolektaColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.greenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.payments_outlined, color: AppColors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pagos y abonos',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('Próximamente — links de cobro a clientes',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Pronto',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green)),
          ),
        ],
      ),
    );
  }
}
