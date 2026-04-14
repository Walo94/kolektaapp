import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ─── Enums ────────────────────────────────────────────────────────────────────

enum GiveawayStatus { open, finished, cancelled }

extension GiveawayStatusX on GiveawayStatus {
  String get label {
    switch (this) {
      case GiveawayStatus.open:
        return 'Abierta';
      case GiveawayStatus.finished:
        return 'Finalizada';
      case GiveawayStatus.cancelled:
        return 'Cancelada';
    }
  }

  String get apiValue {
    switch (this) {
      case GiveawayStatus.open:
        return 'open';
      case GiveawayStatus.finished:
        return 'finished';
      case GiveawayStatus.cancelled:
        return 'cancelled';
    }
  }
}

enum TicketStatus { free, reserved, paid, winner, cancelled }

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.free:
        return 'Libre';
      case TicketStatus.reserved:
        return 'Apartado';
      case TicketStatus.paid:
        return 'Pagado';
      case TicketStatus.winner:
        return 'Ganador';
      case TicketStatus.cancelled:
        return 'Cancelado';
    }
  }

  String get apiValue {
    switch (this) {
      case TicketStatus.free:
        return 'free';
      case TicketStatus.reserved:
        return 'reserved';
      case TicketStatus.paid:
        return 'paid';
      case TicketStatus.winner:
        return 'winner';
      case TicketStatus.cancelled:
        return 'cancelled';
    }
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────

/// Descripción e imagen de un lugar de premio (1°, 2°, …)
class GiveawayPrize {
  final String id;
  final int prizePlace;
  final String description;
  final String? imageUrl;

  const GiveawayPrize({
    required this.id,
    required this.prizePlace,
    required this.description,
    this.imageUrl,
  });

  factory GiveawayPrize.fromJson(Map<String, dynamic> json) {
    return GiveawayPrize(
      id: json['id'] as String? ?? '',
      prizePlace: json['prizePlace'] as int,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'prizePlace': prizePlace,
        'description': description,
      };
}

/// DTO para enviar un premio al servidor (puede incluir imagen en base64)
class PrizeInput {
  final int prizePlace;
  final String description;
  final File? imageFile;

  const PrizeInput({
    required this.prizePlace,
    required this.description,
    this.imageFile,
  });

  Future<Map<String, dynamic>> toJson() async {
    final map = <String, dynamic>{
      'prizePlace': prizePlace,
      'description': description,
    };
    if (imageFile != null) {
      final bytes = await imageFile!.readAsBytes();
      map['imageBase64'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
    return map;
  }
}

class GiveawayTicket {
  final String id;
  final String giveawayId;
  final int ticketNumber;
  final double price;
  final TicketStatus status;
  final int? prizePlace;
  final String? clientName;
  final String? clientPhone;
  final DateTime? soldAt;
  final DateTime createdAt;

  const GiveawayTicket({
    required this.id,
    required this.giveawayId,
    required this.ticketNumber,
    required this.price,
    required this.status,
    this.prizePlace,
    this.clientName,
    this.clientPhone,
    this.soldAt,
    required this.createdAt,
  });

  factory GiveawayTicket.fromJson(Map<String, dynamic> json) {
    TicketStatus parseStatus(String s) {
      switch (s) {
        case 'reserved':
          return TicketStatus.reserved;
        case 'paid':
          return TicketStatus.paid;
        case 'winner':
          return TicketStatus.winner;
        case 'cancelled':
          return TicketStatus.cancelled;
        default:
          return TicketStatus.free;
      }
    }

    return GiveawayTicket(
      id: json['id'] as String,
      giveawayId: json['giveawayId'] as String,
      ticketNumber: json['ticketNumber'] as int,
      price: double.parse(json['price'].toString()),
      status: parseStatus(json['status'] as String),
      prizePlace: json['prizePlace'] as int?,
      clientName: json['clientName'] as String?,
      clientPhone: json['clientPhone'] as String?,
      soldAt: json['soldAt'] != null
          ? DateTime.parse(json['soldAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Giveaway {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String drawDate;

  /// Fecha/hora del sorteo automático. Null = desactivado.
  final DateTime? autoDrawAt;
  final double ticketPrice;
  final int totalTickets;
  final int soldTickets;
  final int prizeCount;
  final String? coverImage;
  final String publicToken;
  final GiveawayStatus status;
  final List<GiveawayTicket> details;

  /// Descripciones e imágenes de premios por lugar.
  final List<GiveawayPrize> prizes;
  final DateTime createdAt;

  const Giveaway({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.drawDate,
    this.autoDrawAt,
    required this.ticketPrice,
    required this.totalTickets,
    required this.soldTickets,
    required this.prizeCount,
    this.coverImage,
    required this.publicToken,
    required this.status,
    this.details = const [],
    this.prizes = const [],
    required this.createdAt,
  });

  double get totalPotential => ticketPrice * totalTickets;
  double get totalCollected => details
      .where((t) =>
          t.status == TicketStatus.paid || t.status == TicketStatus.winner)
      .fold(0.0, (sum, t) => sum + t.price);
  double get soldPercentage =>
      totalTickets == 0 ? 0 : soldTickets / totalTickets;

  factory Giveaway.fromJson(Map<String, dynamic> json) {
    GiveawayStatus parseStatus(String s) {
      switch (s) {
        case 'finished':
          return GiveawayStatus.finished;
        case 'cancelled':
          return GiveawayStatus.cancelled;
        default:
          return GiveawayStatus.open;
      }
    }

    final detailsRaw = json['details'];
    final detailsList = detailsRaw is List ? detailsRaw : <dynamic>[];

    final prizesRaw = json['prizes'];
    final prizesList = prizesRaw is List ? prizesRaw : <dynamic>[];

    return Giveaway(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      drawDate: json['drawDate'] as String,
      autoDrawAt: json['autoDrawAt'] != null
          ? DateTime.tryParse(json['autoDrawAt'] as String)
          : null,
      ticketPrice: double.parse(json['ticketPrice'].toString()),
      totalTickets: json['totalTickets'] as int,
      soldTickets: json['soldTickets'] as int,
      prizeCount: json['prizeCount'] as int,
      coverImage: json['coverImage'] as String?,
      publicToken: json['publicToken'] as String,
      status: parseStatus(json['status'] as String),
      details: detailsList
          .map((d) => GiveawayTicket.fromJson(d as Map<String, dynamic>))
          .toList(),
      prizes: prizesList
          .map((p) => GiveawayPrize.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class GiveawayService {
  static const String _base = 'http://192.168.70.108:4000/kolekta-api/modules';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decodeBody(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      throw Exception(
          'El servidor devolvió una respuesta vacía (HTTP ${response.statusCode})');
    }
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      throw Exception('Error del servidor (HTTP ${response.statusCode}). '
          'Verifica que el servidor esté corriendo y la URL sea correcta.');
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  static Future<int> getOpenGiveawaysCount({required String token}) async {
    final response = await http
        .get(Uri.parse('$_base/giveaways/stats'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      return body['openGiveaways'] as int? ?? 0;
    }
    throw Exception(body['error'] ?? 'Error al obtener estadísticas');
  }

  // ── Listar rifas ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listGiveaways({
    required String token,
    GiveawayStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status.apiValue,
    };
    final uri = Uri.parse('$_base/giveaways').replace(queryParameters: params);
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    final body = _decodeBody(response);
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error al cargar rifas');
  }

  // ── Obtener rifa ──────────────────────────────────────────────────────────

  static Future<Giveaway> getGiveaway({
    required String token,
    required String id,
  }) async {
    final response = await http
        .get(Uri.parse('$_base/giveaways/$id'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      return Giveaway.fromJson(body['giveaway'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cargar la rifa');
  }

  // ── Crear rifa ────────────────────────────────────────────────────────────

  static Future<Giveaway> createGiveaway({
    required String token,
    required String title,
    String? description,
    required String drawDate,
    DateTime? autoDrawAt,
    required double ticketPrice,
    required int totalTickets,
    int prizeCount = 1,
    File? coverImageFile,
    List<PrizeInput> prizes = const [],
  }) async {
    String? coverImageBase64;
    if (coverImageFile != null) {
      final bytes = await coverImageFile.readAsBytes();
      coverImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    // Serializar premios con sus imágenes
    final prizesJson = await Future.wait(prizes.map((p) => p.toJson()));

    final response = await http
        .post(
          Uri.parse('$_base/giveaways'),
          headers: _headers(token),
          body: jsonEncode({
            'title': title,
            if (description != null && description.isNotEmpty)
              'description': description,
            'drawDate': drawDate,
            if (autoDrawAt != null) 'autoDrawAt': autoDrawAt.toIso8601String(),
            'ticketPrice': ticketPrice,
            'totalTickets': totalTickets,
            'prizeCount': prizeCount,
            if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
            if (prizesJson.isNotEmpty) 'prizes': prizesJson,
          }),
        )
        .timeout(const Duration(seconds: 60));

    final body = _decodeBody(response);
    if (response.statusCode == 201) {
      return Giveaway.fromJson(body['giveaway'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al crear la rifa');
  }

  // ── Editar rifa ───────────────────────────────────────────────────────────

  static Future<Giveaway> updateGiveaway({
    required String token,
    required String id,
    String? title,
    String? description,
    String? drawDate,

    /// null desactiva el sorteo automático; valor activa/modifica.
    /// Usa _sentinel para no enviar el campo.
    DateTime? autoDrawAt,
    bool clearAutoDraw = false,
    double? ticketPrice,
    int? prizeCount,
    File? coverImageFile,
    bool removeCoverImage = false,
    List<PrizeInput> prizes = const [],
  }) async {
    String? coverImageBase64;
    if (coverImageFile != null) {
      final bytes = await coverImageFile.readAsBytes();
      coverImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final prizesJson = await Future.wait(prizes.map((p) => p.toJson()));

    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (drawDate != null) 'drawDate': drawDate,
      if (ticketPrice != null) 'ticketPrice': ticketPrice,
      if (prizeCount != null) 'prizeCount': prizeCount,
      if (coverImageBase64 != null) 'coverImageBase64': coverImageBase64,
      if (removeCoverImage) 'removeCoverImage': true,
      if (prizesJson.isNotEmpty) 'prizes': prizesJson,
    };

    // Manejo de autoDrawAt: null explícito desactiva; valor lo activa/modifica
    if (clearAutoDraw) {
      body['autoDrawAt'] = null;
    } else if (autoDrawAt != null) {
      body['autoDrawAt'] = autoDrawAt.toIso8601String();
    }

    final response = await http
        .patch(
          Uri.parse('$_base/giveaways/$id'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    final responseBody = _decodeBody(response);
    if (response.statusCode == 200) {
      return Giveaway.fromJson(
          responseBody['giveaway'] as Map<String, dynamic>);
    }
    throw Exception(responseBody['error'] ?? 'Error al actualizar la rifa');
  }

  // ── Cancelar rifa ─────────────────────────────────────────────────────────

  static Future<void> cancelGiveaway({
    required String token,
    required String id,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/giveaways/$id/cancel'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      final body = _decodeBody(response);
      throw Exception(body['error'] ?? 'Error al cancelar la rifa');
    }
  }

  // ── Eliminar rifa ─────────────────────────────────────────────────────────

  static Future<void> deleteGiveaway({
    required String token,
    required String id,
  }) async {
    final response = await http
        .delete(Uri.parse('$_base/giveaways/$id'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      final body = _decodeBody(response);
      throw Exception(body['error'] ?? 'Error al eliminar la rifa');
    }
  }

  // ── Asignar boleto ────────────────────────────────────────────────────────

  static Future<GiveawayTicket> assignTicket({
    required String token,
    required String giveawayId,
    required int ticketNumber,
    required String clientName,
    String? clientPhone,
    bool paid = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/giveaways/$giveawayId/tickets'),
          headers: _headers(token),
          body: jsonEncode({
            'ticketNumber': ticketNumber,
            'clientName': clientName,
            if (clientPhone != null && clientPhone.isNotEmpty)
              'clientPhone': clientPhone,
            'paid': paid,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response);
    if (response.statusCode == 201) {
      return GiveawayTicket.fromJson(body['detail'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al asignar el boleto');
  }

  // ── Actualizar boleto ─────────────────────────────────────────────────────

  static Future<GiveawayTicket> updateTicket({
    required String token,
    required String giveawayId,
    required String ticketId,
    String? clientName,
    String? clientPhone,
    bool? paid,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/giveaways/$giveawayId/tickets/$ticketId'),
          headers: _headers(token),
          body: jsonEncode({
            if (clientName != null) 'clientName': clientName,
            if (clientPhone != null) 'clientPhone': clientPhone,
            if (paid != null) 'paid': paid,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      return GiveawayTicket.fromJson(body['detail'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al actualizar el boleto');
  }

  // ── Cancelar boleto ───────────────────────────────────────────────────────

  static Future<GiveawayTicket> cancelTicket({
    required String token,
    required String giveawayId,
    required String ticketId,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/giveaways/$giveawayId/tickets/$ticketId/cancel'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      return GiveawayTicket.fromJson(body['detail'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cancelar el boleto');
  }

  // ── Sorteo aleatorio ──────────────────────────────────────────────────────

  static Future<List<GiveawayTicket>> drawRandom({
    required String token,
    required String giveawayId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/giveaways/$giveawayId/draw/random'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      final list = body['winners'] as List<dynamic>;
      return list
          .map((w) => GiveawayTicket.fromJson(w as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['error'] ?? 'Error al realizar el sorteo');
  }

  // ── Sorteo manual ─────────────────────────────────────────────────────────

  static Future<List<GiveawayTicket>> drawManual({
    required String token,
    required String giveawayId,
    required List<int> winnerTicketNumbers,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/giveaways/$giveawayId/draw/manual'),
          headers: _headers(token),
          body: jsonEncode({'winnerTicketNumbers': winnerTicketNumbers}),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response);
    if (response.statusCode == 200) {
      final list = body['winners'] as List<dynamic>;
      return list
          .map((w) => GiveawayTicket.fromJson(w as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['error'] ?? 'Error al registrar el sorteo');
  }

  // ── PDF del boleto ────────────────────────────────────────────────────────

  static Future<List<int>> getTicketReceiptPdf({
    required String token,
    required String giveawayId,
    required String ticketId,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/giveaways/$giveawayId/tickets/$ticketId/receipt'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) return response.bodyBytes;

    final body = _decodeBody(response);
    throw Exception(
        body['error'] ?? 'Error al generar el comprobante del boleto');
  }
}
