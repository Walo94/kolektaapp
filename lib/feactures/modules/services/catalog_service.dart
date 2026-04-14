import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Enums ────────────────────────────────────────────────────────────────────

enum SaleStatus { pending, paid, cancelled }

extension SaleStatusX on SaleStatus {
  String get label {
    switch (this) {
      case SaleStatus.pending:
        return 'Pendiente';
      case SaleStatus.paid:
        return 'Pagado';
      case SaleStatus.cancelled:
        return 'Cancelado';
    }
  }

  String get apiValue {
    switch (this) {
      case SaleStatus.pending:
        return 'pending';
      case SaleStatus.paid:
        return 'paid';
      case SaleStatus.cancelled:
        return 'cancelled';
    }
  }
}

enum PaymentStatus { paid, cancelled }

// ─── Modelos ──────────────────────────────────────────────────────────────────

class SalePayment {
  final String id;
  final String saleId;
  final DateTime date;
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;

  const SalePayment({
    required this.id,
    required this.saleId,
    required this.date,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
        id: json['id'] as String,
        saleId: json['saleId'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: double.parse(json['amount'].toString()),
        status: json['status'] == 'cancelled'
            ? PaymentStatus.cancelled
            : PaymentStatus.paid,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Sale {
  final String id;
  final String userId;
  final int orderNum;
  final String clientName;
  final String? clientPhone;
  final String title;
  final String description;
  final double totalAmount;
  final double balance;
  final String date;
  final SaleStatus status;
  final List<SalePayment> payments;
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.userId,
    required this.orderNum,
    required this.clientName,
    this.clientPhone,
    required this.title,
    required this.description,
    required this.totalAmount,
    required this.balance,
    required this.date,
    required this.status,
    this.payments = const [],
    required this.createdAt,
  });

  /// Monto ya cobrado = total - balance
  double get collected => totalAmount - balance;

  factory Sale.fromJson(Map<String, dynamic> json) {
    SaleStatus parseStatus(String s) {
      switch (s) {
        case 'paid':
          return SaleStatus.paid;
        case 'cancelled':
          return SaleStatus.cancelled;
        default:
          return SaleStatus.pending;
      }
    }

    final paymentsJson = json['payments'] as List<dynamic>? ?? [];

    return Sale(
      id: json['id'] as String,
      userId: json['userId'] as String,
      orderNum: json['orderNum'] as int,
      clientName: json['clientName'] as String,
      clientPhone: json['clientPhone'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      totalAmount: double.parse(json['totalAmount'].toString()),
      balance: double.parse(json['balance'].toString()),
      date: json['date'] as String,
      status: parseStatus(json['status'] as String),
      payments: paymentsJson
          .map((p) => SalePayment.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CatalogStats {
  final double pendingBalance;
  final int pendingCount;
  final int totalCount;

  const CatalogStats({
    required this.pendingBalance,
    required this.pendingCount,
    required this.totalCount,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class CatalogService {
  static const String _base = 'http://192.168.70.108:4000/kolekta-api/modules';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Listar ventas ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listSales({
    required String token,
    SaleStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status.apiValue,
    };

    final uri =
        Uri.parse('$_base/catalog/sales').replace(queryParameters: params);

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error al cargar ventas');
  }

  // ── Obtener una venta ─────────────────────────────────────────────────────

  static Future<Sale> getSale({
    required String token,
    required String id,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/catalog/sales/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Sale.fromJson(body['sale'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cargar la venta');
  }

  // ── Crear venta ───────────────────────────────────────────────────────────

  static Future<Sale> createSale({
    required String token,
    required String clientName,
    String? clientPhone,
    required String title,
    required String description,
    required double totalAmount,
    required String date,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/catalog/sales'),
          headers: _headers(token),
          body: jsonEncode({
            'clientName': clientName,
            if (clientPhone != null && clientPhone.isNotEmpty)
              'clientPhone': clientPhone,
            'title': title,
            'description': description,
            'totalAmount': totalAmount,
            'date': date,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return Sale.fromJson(body['sale'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al crear la venta');
  }

  // ── Editar venta ──────────────────────────────────────────────────────────

  static Future<Sale> updateSale({
    required String token,
    required String id,
    String? title,
    String? description,
    String? clientPhone,
    double? totalAmount,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/catalog/sales/$id'),
          headers: _headers(token),
          body: jsonEncode({
            if (title != null) 'title': title,
            if (description != null) 'description': description,
            if (clientPhone != null) 'clientPhone': clientPhone,
            if (totalAmount != null) 'totalAmount': totalAmount,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Sale.fromJson(body['sale'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al actualizar la venta');
  }

  // ── Cancelar venta ────────────────────────────────────────────────────────

  static Future<Sale> cancelSale({
    required String token,
    required String id,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/catalog/sales/$id/cancel'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Sale.fromJson(body['sale'] as Map<String, dynamic>);
    }
    throw Exception(body['error'] ?? 'Error al cancelar la venta');
  }

  // ── Eliminar venta ────────────────────────────────────────────────────────

  static Future<void> deleteSale({
    required String token,
    required String id,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/catalog/sales/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Error al eliminar la venta');
    }
  }

  // ── Registrar pago ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createPayment({
    required String token,
    required String saleId,
    required double amount,
    required DateTime date,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/catalog/sales/$saleId/payments'),
          headers: _headers(token),
          body: jsonEncode({
            'amount': amount,
            'date': date.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body;
    throw Exception(body['error'] ?? 'Error al registrar el pago');
  }

  // ── Listar pagos de una venta ─────────────────────────────────────────────

  static Future<List<SalePayment>> listPayments({
    required String token,
    required String saleId,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/catalog/sales/$saleId/payments'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final list = body['payments'] as List<dynamic>;
      return list
          .map((p) => SalePayment.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['error'] ?? 'Error al cargar pagos');
  }

  // ── Cancelar pago ─────────────────────────────────────────────────────────

  static Future<void> cancelPayment({
    required String token,
    required String paymentId,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_base/catalog/payments/$paymentId/cancel'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Error al cancelar el pago');
    }
  }

  // ── Eliminar pago ─────────────────────────────────────────────────────────

  static Future<void> deletePayment({
    required String token,
    required String paymentId,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/catalog/payments/$paymentId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Error al eliminar el pago');
    }
  }

  // ── Descargar PDF del comprobante de pago ─────────────────────────────────

  static Future<List<int>> getPaymentReceiptPdf({
    required String token,
    required String paymentId,
  }) async {
    final response = await http
        .get(
          Uri.parse('$_base/catalog/payments/$paymentId/receipt'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) return response.bodyBytes;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'Error al generar el comprobante');
  }
}
