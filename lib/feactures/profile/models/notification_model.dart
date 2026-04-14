// lib/feactures/profile/models/notification_model.dart

/// Tipos de notificación — deben coincidir exactamente con el enum del backend.
enum NotificationType {
  giveawayTicketReserved('giveaway_ticket_reserved'),
  giveawayAutoDrawDone('giveaway_auto_draw_done'),
  giveawayDrawReminder('giveaway_draw_reminder'),
  batchDeliveryReminder('batch_delivery_reminder');

  const NotificationType(this.value);
  final String value;

  static NotificationType? fromValue(String v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType? type;
  final String rawType;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.rawType,
    required this.title,
    this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String? ?? '';
    return NotificationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      rawType: raw,
      type: NotificationType.fromValue(raw),
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        userId: userId,
        type: type,
        rawType: rawType,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

// ── Preferencias ──────────────────────────────────────────────────────────────

class NotificationPreferenceModel {
  final String? id;
  final String userId;
  final NotificationType? type;
  final String rawType;
  final bool enabled;
  final int? daysBeforeDelivery;

  const NotificationPreferenceModel({
    this.id,
    required this.userId,
    required this.type,
    required this.rawType,
    required this.enabled,
    this.daysBeforeDelivery,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String? ?? '';
    return NotificationPreferenceModel(
      id: json['id'] as String?,
      userId: json['userId'] as String? ?? '',
      rawType: raw,
      type: NotificationType.fromValue(raw),
      enabled: json['enabled'] as bool? ?? true,
      daysBeforeDelivery: json['daysBeforeDelivery'] as int?,
    );
  }

  NotificationPreferenceModel copyWith({
    bool? enabled,
    int? daysBeforeDelivery,
  }) =>
      NotificationPreferenceModel(
        id: id,
        userId: userId,
        type: type,
        rawType: rawType,
        enabled: enabled ?? this.enabled,
        daysBeforeDelivery: daysBeforeDelivery ?? this.daysBeforeDelivery,
      );
}
