import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  List<NotificationPreferenceModel> _preferences = [];
  int _unreadCount = 0;
  bool _loading = false;
  bool _prefsLoading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<NotificationModel> get notifications => _notifications;
  List<NotificationPreferenceModel> get preferences => _preferences;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get prefsLoading => _prefsLoading;
  String? get error => _error;
  bool get hasUnread => _unreadCount > 0;

  // ── Cargar lista ──────────────────────────────────────────────────────────

  Future<void> loadNotifications(String token, {bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final result = await NotificationService.getAll(token: token);
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Solo refresca el badge de no leídas (llamado desde MainShell / HomeScreen).
  Future<void> refreshUnreadCount(String token) async {
    try {
      final result = await NotificationService.getAll(token: token, limit: 1);
      _unreadCount = result.unreadCount;
      notifyListeners();
    } catch (_) {}
  }

  // ── Marcar ────────────────────────────────────────────────────────────────

  Future<void> markAsRead(String token, String id) async {
    try {
      await NotificationService.markAsRead(token: token, id: id);
      _notifications = _notifications.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String token) async {
    try {
      await NotificationService.markAllAsRead(token: token);
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  Future<void> delete(String token, String id) async {
    try {
      await NotificationService.delete(token: token, id: id);
      _notifications.removeWhere((n) => n.id == id);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  Future<void> deleteAll(String token) async {
    try {
      await NotificationService.deleteAll(token: token);
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  // ── Preferencias ──────────────────────────────────────────────────────────

  Future<void> loadPreferences(String token) async {
    _prefsLoading = true;
    notifyListeners();
    try {
      _preferences = await NotificationService.getPreferences(token: token);
    } catch (e) {
      _error = _msg(e);
    } finally {
      _prefsLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreference(
    String token,
    String type, {
    bool? enabled,
    int? daysBeforeDelivery,
  }) async {
    try {
      final updated = await NotificationService.updatePreference(
        token: token,
        type: type,
        enabled: enabled,
        daysBeforeDelivery: daysBeforeDelivery,
      );
      _preferences = _preferences.map((p) {
        return p.rawType == type ? updated : p;
      }).toList();
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  /// Inyecta una notificación recibida por push sin necesidad de reload completo.
  void injectPushNotification(NotificationModel notif) {
    _notifications = [notif, ..._notifications];
    _unreadCount++;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}
