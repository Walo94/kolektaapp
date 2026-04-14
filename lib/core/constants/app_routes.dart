/// Nombres de rutas de la app Kolekta
class AppRoutes {
  AppRoutes._();

  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String activity = '/home/activity';
  static const String profile = '/home/profile';
  static const String forgotPassword = '/forgot-password';
  static const String security = '/home/profile/security';
  static const String personalInfo = '/home/profile/personal-info';

  // Módulos

  // ── Notificaciones ─────────────────────────────────────────────────────────
  static const String notifications = '/home/profile/notifications';
  static const String notificationPreferences =
      '/home/profile/notifications/preferences';

// ── Tandas ────────────────────────────────────────────
  static const String batchs = '/batchs';
  static const String createBatch = '/batchs/create';
  static const String batchDetail = '/batchs/:id';

// ── Catalogos ────────────────────────────────────────────
  static const String catalogs = '/catalogs';
  static const String createSale = '/catalogs/create-sale';
  static const String saleDetail = '/catalogs/sale/:id';
  static const String createPayment = '/catalogs/sale/:id/payment';

  // ── Rifas ──────────────────────────────────────────────────────────────────
  static const String giveaways = '/giveaways';
  static const String createGiveaway = '/giveaways/create';
  static const String giveawayDetail = '/giveaways/:id';
}
