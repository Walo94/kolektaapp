import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kolekta/feactures/profile/services/push_notification_handler.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  String? _token;
  String? _errorMessage;
  bool _loading = false;
  bool _biometricEnabled = false;
  String? _biometricEmail;
  String? _biometricPassword;

  // Claves de persistencia
  static const _keyBiometricEnabled  = 'biometric_enabled';
  static const _keyBiometricEmail    = 'biometric_email';
  static const _keyBiometricPassword = 'biometric_password';

  AuthProvider() {
    _loadBiometricPrefs();
  }

  // ── Getters ──────────────────────────────────────────────
  AuthUser? get user        => _user;
  String?   get token       => _token;
  bool get isAuthenticated  => _token != null && _user != null;
  bool get loading          => _loading;
  String? get errorMessage  => _errorMessage;
  bool get biometricEnabled => _biometricEnabled;

  String get displayName    => _user?.fullName ?? 'Usuario';
  String get displayEmail   => _user?.email ?? '';
  String get displayPhone   => _user?.phone ?? '';
  String get displayInitial => _user?.fullName.isNotEmpty == true
      ? _user!.fullName[0].toUpperCase()
      : 'U';

  bool get needsProfileCompletion =>
      _user?.googleProfileIncomplete == true && _token != null;

  // ── Persistencia biométrica ───────────────────────────────

  Future<void> _loadBiometricPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled  = prefs.getBool(_keyBiometricEnabled)   ?? false;
    _biometricEmail    = prefs.getString(_keyBiometricEmail);
    _biometricPassword = prefs.getString(_keyBiometricPassword);
    notifyListeners();
  }

  Future<void> _saveBiometricPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, _biometricEnabled);
    if (_biometricEmail != null) {
      await prefs.setString(_keyBiometricEmail, _biometricEmail!);
    }
    if (_biometricPassword != null) {
      await prefs.setString(_keyBiometricPassword, _biometricPassword!);
    }
  }

  Future<void> _clearBiometricPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keyBiometricEmail);
    await prefs.remove(_keyBiometricPassword);
  }

  // ── LOGIN ─────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
  _setLoading(true);
  _errorMessage = null;
  try {
    final result = await AuthService.login(email: email, password: password);
    _user  = result.user;
    _token = result.token;
 
    // ── NUEVO: registrar FCM token en el backend ──────────────────────────
    // setAuthToken guarda el auth token y envía el FCM token al backend.
    await PushNotificationHandler.instance.setAuthToken(result.token);
    // ─────────────────────────────────────────────────────────────────────
 
    notifyListeners();
    return true;
  } catch (e) {
    _errorMessage = _parseError(e);
    notifyListeners();
    return false;
  } finally {
    _setLoading(false);
  }
}

  // ── REGISTER ─────────────────────────────────────────────
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.register(
        fullName: fullName, email: email,
        phone: phone, password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── FORGOT PASSWORD ──────────────────────────────────────
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.forgotPassword(email: email);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── CHANGE PASSWORD ──────────────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      _errorMessage = 'No hay sesión activa';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── RESEND EMAIL VERIFICATION ────────────────────────────
  Future<bool> resendVerificationEmail() async {
    if (_token == null) {
      _errorMessage = 'No hay sesión activa';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.resendVerificationEmail(token: _token!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── PHONE VERIFICATION ───────────────────────────────────

  /// Solicita el envío del OTP por WhatsApp.
  Future<bool> sendPhoneVerificationCode() async {
    if (_token == null) {
      _errorMessage = 'No hay sesión activa';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.sendPhoneVerificationCode(token: _token!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verifica el OTP ingresado y actualiza el estado local del usuario.
  Future<bool> verifyPhoneCode(String code) async {
    if (_token == null) {
      _errorMessage = 'No hay sesión activa';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await AuthService.verifyPhoneCode(token: _token!, code: code);

      // Actualizar el estado local del usuario sin necesidad de re-login
      if (_user != null) {
        _user = AuthUser(
          id: _user!.id,
          fullName: _user!.fullName,
          email: _user!.email,
          phone: _user!.phone,
          userAccount: _user!.userAccount,
          emailVerified: _user!.emailVerified,
          phoneVerified: true, // ← marcar como verificado localmente
          googleProfileIncomplete: _user!.googleProfileIncomplete,
          profilePicture: _user!.profilePicture,
          createdAt: _user!.createdAt,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── BIOMETRIC LOGIN ───────────────────────────────────────
  Future<void> saveBiometricCredentials(String email, String password) async {
    _biometricEmail    = email;
    _biometricPassword = password;
    _biometricEnabled  = true;
    await _saveBiometricPrefs();
    notifyListeners();
  }

  Future<bool> loginWithBiometrics() async {
    if (_biometricEmail == null || _biometricPassword == null) {
      _errorMessage = 'No hay credenciales biométricas guardadas';
      notifyListeners();
      return false;
    }
    return login(_biometricEmail!, _biometricPassword!);
  }

  Future<void> disableBiometrics() async {
    _biometricEnabled  = false;
    _biometricEmail    = null;
    _biometricPassword = null;
    await _clearBiometricPrefs();
    notifyListeners();
  }

  // ── LOGOUT ───────────────────────────────────────────────
  void logout() {
  // ── NUEVO: limpiar el auth token del handler ──────────────────────────
  PushNotificationHandler.instance.clearAuthToken();
  // ─────────────────────────────────────────────────────────────────────
 
  _user  = null;
  _token = null;
  _errorMessage = null;
  notifyListeners();
}

  // ── Helpers ──────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  String _parseError(Object e) {
    final msg = e.toString();
    return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
  }
}