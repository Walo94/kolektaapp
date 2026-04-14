import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/utils/theme_provider.dart';
import 'feactures/admin/providers/auth_provider.dart';
import 'feactures/modules/providers/batch_provider.dart';
import 'feactures/modules/providers/catalog_provider.dart';
import 'feactures/modules/providers/giveaway_provider.dart';
import 'feactures/activity/providers/activity_provider.dart';
import 'feactures/profile/providers/notification_provider.dart';
import 'feactures/profile/services/push_notification_handler.dart';
import 'app.dart';

/// Handler de mensajes en background/terminated.
/// DEBE ser top-level (fuera de cualquier clase) — Firebase lo ejecuta
/// en un isolate separado.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[Push] Mensaje en background: ${message.messageId}');
  // El SO ya muestra la notificación visual — no hace falta llamar _showLocal.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase — DEBE ir antes de cualquier uso de Firebase ──────────────
  await Firebase.initializeApp();

  // ── 2. Registrar handler de mensajes en background ─────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── 3. Localización ────────────────────────────────────────────────────────
  await initializeDateFormatting('es', null);

  // ── 4. UI del sistema ──────────────────────────────────────────────────────
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── 5. Provider + handler de push ─────────────────────────────────────────
  final notificationProvider = NotificationProvider();
  await PushNotificationHandler.instance.init(notificationProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => GiveawayProvider()),
        ChangeNotifierProvider.value(value: notificationProvider),
      ],
      child: KolektaApp(),
    ),
  );
}