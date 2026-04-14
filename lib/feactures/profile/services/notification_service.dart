// lib/feactures/profile/services/notification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class NotificationsListResult {
  final List<NotificationModel> notifications;
  final int total;
  final int unreadCount;

  const NotificationsListResult({
    required this.notifications,
    required this.total,
    required this.unreadCount,
  });
}

class NotificationService {
  static const String _base = 'http://192.168.70.108:4000/kolekta-api/modules';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Listar ────────────────────────────────────────────────────────────────

  static Future<NotificationsListResult> getAll({
    required String token,
    int limit = 50,
    int offset = 0,
    bool onlyUnread = false,
  }) async {
    final uri = Uri.parse('$_base/notifications').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (onlyUnread) 'onlyUnread': 'true',
    });

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['notifications'] as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return NotificationsListResult(
        notifications: list,
        total: body['total'] as int? ?? list.length,
        unreadCount: body['unreadCount'] as int? ?? 0,
      );
    }
    throw Exception('Error al cargar notificaciones');
  }

  // ── Marcar como leída ─────────────────────────────────────────────────────

  static Future<void> markAsRead({
    required String token,
    required String id,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/notifications/$id/read'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al marcar la notificación');
    }
  }

  static Future<void> markAllAsRead({required String token}) async {
    final response = await http
        .patch(
          Uri.parse('$_base/notifications/read-all'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al marcar todas como leídas');
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  static Future<void> delete({
    required String token,
    required String id,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/notifications/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la notificación');
    }
  }

  static Future<void> deleteAll({required String token}) async {
    final response = await http
        .delete(
          Uri.parse('$_base/notifications'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar las notificaciones');
    }
  }

  // ── Preferencias ──────────────────────────────────────────────────────────

  static Future<List<NotificationPreferenceModel>> getPreferences({
    required String token,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/notifications/preferences'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['preferences'] as List)
          .map((e) =>
              NotificationPreferenceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar preferencias');
  }

  static Future<NotificationPreferenceModel> updatePreference({
    required String token,
    required String type,
    bool? enabled,
    int? daysBeforeDelivery,
  }) async {
    final payload = <String, dynamic>{};
    if (enabled != null) payload['enabled'] = enabled;
    if (daysBeforeDelivery != null) {
      payload['daysBeforeDelivery'] = daysBeforeDelivery;
    }

    final response = await http
        .patch(
          Uri.parse('$_base/notifications/preferences/$type'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return NotificationPreferenceModel.fromJson(
          body['preference'] as Map<String, dynamic>);
    }
    throw Exception('Error al actualizar la preferencia');
  }
}
