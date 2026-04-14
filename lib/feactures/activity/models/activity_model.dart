// lib/features/activity/models/activity_model.dart

enum ActivityModule { batch, giveaway, catalog }

enum ActivityType {
  // Tandas
  batchCreated,
  batchCancelled,
  batchDeleted,
  batchFinished,
  batchDeliveryRegistered,
  batchParticipantAdded,
  batchParticipantRemoved,

  // Rifas
  giveawayCreated,
  giveawayCancelled,
  giveawayDeleted,
  giveawayWinnerDrawn,
  giveawayTicketSold,

  // Catálogo
  catalogSaleCreated,
  catalogPaymentRegistered,
  catalogSaleCancelled,
}

class ActivityModel {
  final String id;
  final String userId;
  final ActivityModule module;
  final ActivityType type;
  final String title;
  final String description;
  final double? amount;
  final String? referenceId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ActivityModel({
    required this.id,
    required this.userId,
    required this.module,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    this.referenceId,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      module: _moduleFromString(json['module'] as String),
      type: _typeFromString(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      amount: json['amount'] != null
          ? double.tryParse(json['amount'].toString())
          : null,
      referenceId: json['referenceId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ActivityModule _moduleFromString(String value) {
    switch (value) {
      case 'batch':
        return ActivityModule.batch;
      case 'giveaway':
        return ActivityModule.giveaway;
      case 'catalog':
        return ActivityModule.catalog;
      default:
        return ActivityModule.batch;
    }
  }

  static ActivityType _typeFromString(String value) {
    const map = {
      'batch_created': ActivityType.batchCreated,
      'batch_cancelled': ActivityType.batchCancelled,
      'batch_deleted': ActivityType.batchDeleted,
      'batch_finished': ActivityType.batchFinished,
      'batch_delivery_registered': ActivityType.batchDeliveryRegistered,
      'batch_participant_added': ActivityType.batchParticipantAdded,
      'batch_participant_removed': ActivityType.batchParticipantRemoved,
      'giveaway_created': ActivityType.giveawayCreated,
      'giveaway_cancelled': ActivityType.giveawayCancelled,
      'giveaway_deleted': ActivityType.giveawayDeleted,
      'giveaway_winner_drawn': ActivityType.giveawayWinnerDrawn,
      'giveaway_ticket_sold': ActivityType.giveawayTicketSold,
      'catalog_sale_created': ActivityType.catalogSaleCreated,
      'catalog_payment_registered': ActivityType.catalogPaymentRegistered,
      'catalog_sale_cancelled': ActivityType.catalogSaleCancelled,
    };
    return map[value] ?? ActivityType.batchCreated;
  }

  /// Determina si el movimiento representa un ingreso (positivo)
  bool get isPositive {
    switch (type) {
      case ActivityType.batchDeliveryRegistered:
      case ActivityType.giveawayTicketSold:
      case ActivityType.giveawayWinnerDrawn:
      case ActivityType.catalogPaymentRegistered:
        return true;
      default:
        return amount != null ? amount! >= 0 : true;
    }
  }

  /// Formatea el monto para mostrar en UI
  String get formattedAmount {
    if (amount == null) return '';
    final formatted =
        '\$${amount!.abs().toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return isPositive ? '+$formatted' : '-$formatted';
  }
}

class ActivityListResult {
  final List<ActivityModel> activities;
  final int total;

  const ActivityListResult({
    required this.activities,
    required this.total,
  });

  factory ActivityListResult.fromJson(Map<String, dynamic> json) {
    final list = (json['activities'] as List<dynamic>)
        .map((e) => ActivityModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ActivityListResult(
      activities: list,
      total: json['total'] as int,
    );
  }
}