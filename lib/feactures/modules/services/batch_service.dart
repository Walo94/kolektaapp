import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ── Modelos ───────────────────────────────────────────────

enum BatchStatus { active, finished, cancelled }

enum BatchFrequency { weekly, biweekly, monthly }

enum BatchDetailStatus { pending, delivered, cancelled }

extension BatchStatusX on BatchStatus {
  String get label {
    switch (this) {
      case BatchStatus.active:
        return 'Activa';
      case BatchStatus.finished:
        return 'Completada';
      case BatchStatus.cancelled:
        return 'Cancelada';
    }
  }

  String get apiValue {
    switch (this) {
      case BatchStatus.active:
        return 'active';
      case BatchStatus.finished:
        return 'finished';
      case BatchStatus.cancelled:
        return 'cancelled';
    }
  }
}

extension BatchFrequencyX on BatchFrequency {
  String get label {
    switch (this) {
      case BatchFrequency.weekly:
        return 'Semanal';
      case BatchFrequency.biweekly:
        return 'Quincenal';
      case BatchFrequency.monthly:
        return 'Mensual';
    }
  }

  String get apiValue {
    switch (this) {
      case BatchFrequency.weekly:
        return 'weekly';
      case BatchFrequency.biweekly:
        return 'biweekly';
      case BatchFrequency.monthly:
        return 'monthly';
    }
  }
}

class BatchDetail {
  final String id;
  final int row;
  final int assignedNumber;
  final String contactName;
  final String? phone;
  final String? email;
  final String? notes;
  final String deliveryDate;
  final double payoutAmount;
  final BatchDetailStatus status;
  final String? deliveredAt;

  const BatchDetail({
    required this.id,
    required this.row,
    required this.assignedNumber,
    required this.contactName,
    this.phone,
    this.email,
    this.notes,
    required this.deliveryDate,
    required this.payoutAmount,
    required this.status,
    this.deliveredAt,
  });

  factory BatchDetail.fromJson(Map<String, dynamic> json) {
    BatchDetailStatus parseStatus(String s) {
      switch (s) {
        case 'delivered':
          return BatchDetailStatus.delivered;
        case 'cancelled':
          return BatchDetailStatus.cancelled;
        default:
          return BatchDetailStatus.pending;
      }
    }

    return BatchDetail(
      id: json['id'].toString(),
      row: json['row'] as int,
      assignedNumber: json['assignedNumber'] as int,
      contactName: json['contactName'] ?? '',
      phone: json['phone'],
      email: json['email'],
      notes: json['notes'],
      deliveryDate: json['deliveryDate'] ?? '',
      payoutAmount: double.tryParse(json['payoutAmount'].toString()) ?? 0,
      status: parseStatus(json['status'] ?? 'pending'),
      deliveredAt: json['deliveredAt'],
    );
  }
}

class Batch {
  final String id;
  final String name;
  final double entryPrice;
  final int totalSlots;
  final BatchFrequency frequency;
  final BatchStatus status;
  final int currentTurn;
  final String startDate;
  final String? nextDeliveryDate;
  final String? notes;
  final String publicToken;
  final List<BatchDetail> details;
  final String createdAt;

  /// URL pública de la imagen de portada almacenada en Cloudinary. Puede ser null.
  final String? coverImage;

  const Batch({
    required this.id,
    required this.name,
    required this.entryPrice,
    required this.totalSlots,
    required this.frequency,
    required this.status,
    required this.currentTurn,
    required this.startDate,
    this.nextDeliveryDate,
    this.notes,
    required this.publicToken,
    this.details = const [],
    required this.createdAt,
    this.coverImage,
  });

  double get payoutAmount => entryPrice * totalSlots;

  factory Batch.fromJson(Map<String, dynamic> json) {
    BatchFrequency parseFreq(String f) {
      switch (f) {
        case 'biweekly':
          return BatchFrequency.biweekly;
        case 'monthly':
          return BatchFrequency.monthly;
        default:
          return BatchFrequency.weekly;
      }
    }

    BatchStatus parseStatus(String s) {
      switch (s) {
        case 'finished':
          return BatchStatus.finished;
        case 'cancelled':
          return BatchStatus.cancelled;
        default:
          return BatchStatus.active;
      }
    }

    final detailsJson = json['details'] as List<dynamic>? ?? [];

    return Batch(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      entryPrice: double.tryParse(json['entryPrice'].toString()) ?? 0,
      totalSlots: json['totalSlots'] as int,
      frequency: parseFreq(json['frequency'] ?? 'weekly'),
      status: parseStatus(json['status'] ?? 'active'),
      currentTurn: json['currentTurn'] as int? ?? 0,
      startDate: json['startDate'] ?? '',
      nextDeliveryDate: json['nextDeliveryDate'],
      notes: json['notes'],
      publicToken: json['publicToken'] ?? '',
      details: detailsJson
          .map((d) => BatchDetail.fromJson(d as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] ?? '',
      coverImage: json['coverImage'],
    );
  }
}

class ParticipantInput {
  final String contactName;
  final String? phone;
  final String? email;
  final String? notes;
  final int? assignedNumber;

  const ParticipantInput({
    required this.contactName,
    this.phone,
    this.email,
    this.notes,
    this.assignedNumber,
  });

  Map<String, dynamic> toJson() => {
        'contactName': contactName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (notes != null) 'notes': notes,
        if (assignedNumber != null) 'assignedNumber': assignedNumber,
      };
}

// ── Servicio ──────────────────────────────────────────────

class BatchService {
  static const String _base = 'http://192.168.70.108:4000/kolekta-api/modules';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── GET /batchs/stats ─────────────────────────────────
  static Future<int> getActiveBatchsCount({required String token}) async {
    final response = await http
        .get(Uri.parse('$_base/batchs/stats'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['activeBatchs'] as int? ?? 0;
    }
    throw Exception(body['error'] ?? 'Error al obtener estadísticas');
  }

  // ── GET /batchs ───────────────────────────────────────
  static Future<Map<String, dynamic>> listBatchs({
    required String token,
    BatchStatus? status,        // ← NUEVO: filtro por status
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status.apiValue,   // ← se usará el apiValue
    };

    final uri = Uri.parse('$_base/batchs').replace(queryParameters: params);

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body; // se espera { "batchs": [...], "total": int }
    }
    throw Exception(body['error'] ?? 'Error al cargar tandas');
  }

  // ── GET /batchs/:id ───────────────────────────────────
  static Future<Batch> getBatch({
    required String token,
    required String id,
  }) async {
    final response = await http
        .get(Uri.parse('$_base/batchs/$id'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Batch.fromJson(body['batch'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cargar la tanda');
  }

  // ── POST /batchs ──────────────────────────────────────
  static Future<Batch> createBatch({
    required String token,
    required String name,
    required double entryPrice,
    required int totalSlots,
    required BatchFrequency frequency,
    required String startDate,
    String? notes,
    List<ParticipantInput> participants = const [],
    bool randomize = false,

    /// Imagen de portada: puede ser un File (cámara/galería) o null
    File? coverImageFile,
  }) async {
    // Convertir imagen a base64 si se proporcionó
    String? coverImageBase64;
    if (coverImageFile != null) {
      final bytes = await coverImageFile.readAsBytes();
      coverImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final response = await http
        .post(
          Uri.parse('$_base/batchs'),
          headers: _headers(token),
          body: jsonEncode({
            'name': name,
            'entryPrice': entryPrice,
            'totalSlots': totalSlots,
            'frequency': frequency.apiValue,
            'startDate': startDate,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            if (participants.isNotEmpty)
              'participants': participants.map((p) => p.toJson()).toList(),
            'randomize': randomize,
            if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
          }),
        )
        .timeout(const Duration(seconds: 30)); // más tiempo por la subida

    final body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Batch.fromJson(body['batch'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al crear la tanda');
  }

  // ── PATCH /batchs/:id ─────────────────────────────────
  static Future<Batch> updateBatch({
    required String token,
    required String batchId,
    String? name,
    String? notes,
    File? coverImageFile,
    bool removeCoverImage = false,
  }) async {
    String? coverImageBase64;
    if (coverImageFile != null) {
      final bytes = await coverImageFile.readAsBytes();
      coverImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final response = await http
        .patch(
          Uri.parse('$_base/batchs/$batchId'),
          headers: _headers(token),
          body: jsonEncode({
            if (name != null) 'name': name,
            if (notes != null) 'notes': notes,
            if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
            if (removeCoverImage) 'removeCoverImage': true,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Batch.fromJson(body['batch'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al actualizar la tanda');
  }

  // ── POST /batchs/:id/participants ─────────────────────
  static Future<BatchDetail> addParticipant({
    required String token,
    required String batchId,
    required int row,
    required String contactName,
    String? phone,
    String? email,
    String? notes,
    int? assignedNumber,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/batchs/$batchId/participants'),
          headers: _headers(token),
          body: jsonEncode({
            'row': row,
            'contactName': contactName,
            if (phone != null) 'phone': phone,
            if (email != null) 'email': email,
            if (notes != null) 'notes': notes,
            if (assignedNumber != null) 'assignedNumber': assignedNumber,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return BatchDetail.fromJson(body['detail'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al agregar participante');
  }

  // ── DELETE /batchs/:id/participants/:detailId ─────────
  static Future<void> removeParticipant({
    required String token,
    required String batchId,
    required String detailId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/batchs/$batchId/participants/$detailId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error al eliminar participante');
    }
  }

  // ── POST /batchs/:id/deliver/:detailId ───────────────
  static Future<void> registerDelivery({
    required String token,
    required String batchId,
    required String detailId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/batchs/$batchId/deliver/$detailId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error al registrar entrega');
    }
  }

  // ── DELETE /batchs/:id/cancel ────────────────────────
  static Future<void> cancelBatch({
    required String token,
    required String batchId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/batchs/$batchId/cancel'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error al cancelar la tanda');
    }
  }

  // ── DELETE /batchs/:id/delete ────────────────────────
  static Future<void> deleteBatch({
    required String token,
    required String batchId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/batchs/$batchId/delete'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error al eliminar la tanda');
    }
  }
}
