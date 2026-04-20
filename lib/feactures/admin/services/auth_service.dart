import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Modelo de respuesta del usuario devuelto por la API
class AuthUser {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String subscriptionPlan;
  final DateTime? trialEndsAt;
  final DateTime?
      subscriptionExpiresAt;
  final bool emailVerified;
  final bool phoneVerified;
  final String? createdAt;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.subscriptionPlan,
    this.trialEndsAt,
    this.subscriptionExpiresAt,
    required this.emailVerified,
    this.phoneVerified = false,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        // Nuevos campos de suscripción
        subscriptionPlan: json['subscriptionPlan'] ?? 'free',
        trialEndsAt: json['trialEndsAt'] != null
            ? DateTime.tryParse(json['trialEndsAt'])
            : null,
        subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
            ? DateTime.tryParse(json['subscriptionExpiresAt'])
            : null,
        emailVerified: json['emailVerified'] ?? false,
        phoneVerified: json['phoneVerified'] ?? false,
        createdAt: json['createdAt'],
      );
}

/// Resultado exitoso de login
class LoginResult {
  final AuthUser user;
  final String token;

  const LoginResult({
    required this.user,
    required this.token,
  });
}

/// Centraliza todas las llamadas HTTP a /kolekta-api/auth
class AuthService {
  static final String _base = '${dotenv.env['API_BASE_URL']}/auth';

  static final _headers = {'Content-Type': 'application/json'};

  // ── POST /register ────────────────────────────────────
  static Future<AuthUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/register'),
          headers: _headers,
          body: jsonEncode({
            'fullName': fullName,
            'email': email,
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return AuthUser.fromJson(body['user']);
    }

    throw Exception(body['message'] ?? body['error'] ?? 'Error al registrar');
  }

  // ── POST /login ───────────────────────────────────────
  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return LoginResult(
        user: AuthUser.fromJson(body['user']),
        token: body['token'],
      );
    }

    throw Exception(
        body['message'] ?? body['error'] ?? 'Credenciales inválidas');
  }

  // ── POST /forgot-password ─────────────────────────────
  static Future<void> forgotPassword({required String email}) async {
    final response = await http
        .post(
          Uri.parse('$_base/forgot-password'),
          headers: _headers,
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ?? body['error'] ?? 'Error al enviar el correo',
      );
    }
  }

  // ── PUT /profile/change-password ──────────────────────
  static Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http
        .put(
          Uri.parse('$_base/profile/change-password'),
          headers: {
            ..._headers,
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ?? body['error'] ?? 'Error al cambiar la contraseña',
      );
    }
  }

  // ── POST /profile/resend-verification ─────────────────
  static Future<void> resendVerificationEmail({
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/profile/resend-verification'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ??
            body['error'] ??
            'Error al reenviar el correo de verificación',
      );
    }
  }

  // ── POST /profile/send-phone-code ─────────────────────
  static Future<void> sendPhoneVerificationCode({
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/profile/send-phone-code'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ??
            body['error'] ??
            'Error al enviar el código de WhatsApp',
      );
    }
  }

  // ── POST /profile/verify-phone ────────────────────────
  static Future<void> verifyPhoneCode({
    required String token,
    required String code,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/profile/verify-phone'),
          headers: {
            ..._headers,
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ?? body['error'] ?? 'Código incorrecto o expirado',
      );
    }
  }

  // ── NUEVO: Activar prueba gratis de 7 días ─────────────────────────────
  static Future<void> startFreeTrial({required String token}) async {
    final response = await http.post(
      Uri.parse('$_base/profile/start-trial'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ?? body['error'] ?? 'Error al activar la prueba gratis',
      );
    }
  }

  static Future<LoginResult> refreshUserInfo({required String token}) async {
    final response = await http.get(
      Uri.parse('$_base/profile/refresh-info'),
      headers: {
        ..._headers,
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return LoginResult(
        user: AuthUser.fromJson(body['user']),
        token: token, // mantenemos el mismo token
      );
    }

    throw Exception(
        body['message'] ?? body['error'] ?? 'Error al refrescar usuario');
  }
}
