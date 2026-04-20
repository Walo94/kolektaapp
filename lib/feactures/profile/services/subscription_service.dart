import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Modelo de suscripción activa (único que necesitamos ahora)
class SubscriptionInfo {
  final String id;
  final String status;
  final DateTime currentPeriodEnd;
  final String planType; // 'monthly' | 'annual'
  final bool cancelAtPeriodEnd;

  const SubscriptionInfo({
    required this.id,
    required this.status,
    required this.currentPeriodEnd,
    required this.planType,
    required this.cancelAtPeriodEnd,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      // ← FIX PRINCIPAL
      currentPeriodEnd: json['currentPeriodEnd'] != null
          ? DateTime.parse(json['currentPeriodEnd'] as String)
          : DateTime.now().add(const Duration(days: 30)), // fallback seguro
      planType: json['planType'] ?? 'unknown',
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] ?? false,
    );
}

class CheckoutResult {
  final String url;
  final String sessionId;

  const CheckoutResult({required this.url, required this.sessionId});
}

/// Centraliza todas las llamadas a /kolekta-api/subscription
class SubscriptionService {
  static final String _base = '${dotenv.env['API_BASE_URL']}/subscription';

  static Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static const String priceMonthly = 'price_1TMFcWCb8MmMUGadm6DFlrc5';
  static const String priceAnnual = 'price_1TMrpHCb8MmMUGadrW2U59Jd';

  // ── GET /active ────────────────────────────────────────────
  static Future<SubscriptionInfo?> getActiveSubscription({required String token}) async {
    final response = await http
        .get(Uri.parse('$_base/active'), headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (body['subscription'] == null) return null;
      return SubscriptionInfo.fromJson(body['subscription']);
    }

    throw Exception(body['error'] ?? 'Error al obtener la suscripción activa');
  }

  // ── POST /checkout ─────────────────────────────────────────
  static Future<CheckoutResult> createCheckout({
    required String token,
    required String priceId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/checkout'),
          headers: _authHeaders(token),
          body: jsonEncode({'priceId': priceId}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return CheckoutResult(url: body['url'], sessionId: body['sessionId']);
    }

    throw Exception(body['error'] ?? 'Error al crear la sesión de pago');
  }

  // ── POST /portal ───────────────────────────────────────────
  static Future<String> createPortalSession({required String token}) async {
    final response = await http
        .post(Uri.parse('$_base/portal'), headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return body['url'] as String;
    }

    throw Exception(body['error'] ?? 'Error al abrir el portal de suscripción');
  }
}