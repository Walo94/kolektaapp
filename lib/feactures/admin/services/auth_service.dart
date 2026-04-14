import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo de respuesta del usuario devuelto por la API
class AuthUser {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String userAccount;
  final bool emailVerified;
  final bool phoneVerified;
  final bool googleProfileIncomplete;
  final String? profilePicture;
  final String? createdAt;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.userAccount,
    required this.emailVerified,
    this.phoneVerified = false,
    this.googleProfileIncomplete = false,
    this.profilePicture,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        userAccount: json['userAccount'] ?? 'free',
        emailVerified: json['emailVerified'] ?? false,
        phoneVerified: json['phoneVerified'] ?? false,
        googleProfileIncomplete: json['googleProfileIncomplete'] ?? false,
        profilePicture: json['profilePicture'],
        createdAt: json['createdAt'],
      );
}

/// Resultado exitoso de login
class LoginResult {
  final AuthUser user;
  final String token;

  /// true cuando el usuario debe completar su perfil (nombre/teléfono)
  final bool requiresProfile;

  const LoginResult({
    required this.user,
    required this.token,
    this.requiresProfile = false,
  });
}

/// Centraliza todas las llamadas HTTP a /kolekta-api/auth
class AuthService {
  static const String _base = 'http://192.168.70.108:4000/kolekta-api/auth';

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
  /// Solicita al backend que genere un OTP y lo envíe por WhatsApp.
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
  /// Envía el OTP ingresado por el usuario para verificarlo.
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
}
