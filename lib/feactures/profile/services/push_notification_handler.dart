import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_routes.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PushNotificationHandler {
  PushNotificationHandler._();
  static final instance = PushNotificationHandler._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static final String _base = '${dotenv.env['API_BASE_URL']}/modules';

  final _localNotifs = FlutterLocalNotificationsPlugin();
  NotificationProvider? _provider;

  // El auth token se guarda aquí una vez que el usuario hace login.
  // Se actualiza llamando a PushNotificationHandler.instance.setAuthToken(token)
  // desde AuthProvider justo después de un login exitoso.
  String? _authToken;

  // ── API pública de configuración ──────────────────────────────────────────

  /// Llama esto desde AuthProvider después de login exitoso.
  /// Registra el FCM token en el backend con el auth token del usuario.
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    // Ahora que tenemos el auth token, podemos registrar el FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _sendTokenToBackend(fcmToken);
    }
  }

  /// Llama esto desde AuthProvider en logout para limpiar el token.
  void clearAuthToken() {
    _authToken = null;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init(NotificationProvider provider) async {
    _provider = provider;
    await _initLocalNotifications();
    await _initFCM();
  }

  Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          _handleTap(jsonDecode(payload) as Map<String, dynamic>);
        }
      },
    );

    // ── Canal explícito para Android 8+ (Oreo) ─────────────────────────────
    // Sin esto Android silencia las notificaciones aunque el código sea correcto.
    const androidChannel = AndroidNotificationChannel(
      'kolekta_main', // debe coincidir con el channelId de AndroidNotificationDetails
      'Kolekta Alertas',
      description: 'Alertas de rifas, tandas y recordatorios',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // ── Permisos (iOS y Android 13+) ──────────────────────────────────────
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Estado de permisos: ${settings.authorizationStatus}');

    // ── App abierta desde estado Terminated al tocar la notificación ───────
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial.data);

    // ── Tap en notificación con app en Background ──────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleTap(msg.data));

    // ── Mensaje recibido con app en Foreground ─────────────────────────────
    FirebaseMessaging.onMessage.listen((msg) {
      handleIncoming(
        title: msg.notification?.title ?? 'Nueva notificación',
        body: msg.notification?.body,
        data: msg.data,
      );
    });

    // ── Registro del token FCM ─────────────────────────────────────────────
    // Nota: _sendTokenToBackend necesita _authToken, que se setea en setAuthToken().
    // Si el usuario ya hizo login antes de que init() corra (improbable pero posible),
    // el token se enviará en ese momento. De lo contrario, se envía al llamar setAuthToken().
    final fcmToken = await messaging.getToken();
    debugPrint('[Push] FCM token: $fcmToken');
    if (fcmToken != null && _authToken != null) {
      await _sendTokenToBackend(fcmToken);
    }

    // ── Actualizar token si FCM lo rota ───────────────────────────────────
    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[Push] FCM token actualizado: $newToken');
      _sendTokenToBackend(newToken);
    });
  }

  // ── Registro del token en el backend ─────────────────────────────────────

  Future<void> _sendTokenToBackend(String fcmToken) async {
    if (_authToken == null) {
      debugPrint('[Push] Sin auth token, no se puede registrar el FCM token.');
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_base/notifications/device-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[Push] Registro de token → ${response.statusCode}');
    } catch (e) {
      debugPrint('[Push] Error registrando FCM token: $e');
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Llamado desde onMessage (foreground). Muestra la notificación local
  /// e inyecta el modelo en el provider para actualizar la bandeja.
  void handleIncoming({
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) {
    // Mostrar la notificación visual (el SO no lo hace en foreground)
    _showLocal(title: title, body: body, payload: data);

    // Inyectar en el provider para que aparezca en la bandeja sin reload
    if (data != null && _provider != null) {
      try {
        final notif = NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: '',
          rawType: data['type'] as String? ?? '',
          type: NotificationType.fromValue(data['type'] as String? ?? ''),
          title: title,
          body: body,
          data: data,
          isRead: false,
          createdAt: DateTime.now(),
        );
        _provider!.injectPushNotification(notif);
      } catch (e) {
        debugPrint('[Push] Error inyectando notificación: $e');
      }
    }
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  Future<void> _showLocal({
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'kolekta_main', // debe coincidir con el canal creado en _initLocalNotifications
      'Kolekta Alertas',
      channelDescription: 'Alertas de rifas, tandas y recordatorios',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifs.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  void _handleTap(Map<String, dynamic> data) {
    final type = NotificationType.fromValue(data['type'] as String? ?? '');
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case NotificationType.giveawayTicketReserved:
      case NotificationType.giveawayAutoDrawDone:
      case NotificationType.giveawayDrawReminder:
        final id = data['giveawayId'] as String?;
        if (id != null) {
          context.push(AppRoutes.giveawayDetail.replaceFirst(':id', id));
        }
        break;
      case NotificationType.batchDeliveryReminder:
        final id = data['batchId'] as String?;
        if (id != null) {
          context.push(AppRoutes.batchDetail.replaceFirst(':id', id));
        }
        break;
      default:
        context.push(AppRoutes.notifications);
        break;
    }
  }
}
