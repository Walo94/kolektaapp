import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

enum SubscriptionLoadState { idle, loading, loaded, error }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionInfo? _subscription;
  SubscriptionLoadState _state = SubscriptionLoadState.idle;
  String? _errorMessage;

  bool _checkoutLoading = false;
  bool _portalLoading = false;

  // ── Getters ──────────────────────────────────────────────
  SubscriptionInfo? get subscription => _subscription;
  SubscriptionLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == SubscriptionLoadState.loading;
  bool get checkoutLoading => _checkoutLoading;
  bool get portalLoading => _portalLoading;
  bool get hasActiveSubscription =>
      _subscription != null && _subscription!.status == 'active';

  // ── Cargar suscripción activa ─────────────────────────────
  Future<void> loadActiveSubscription({required String token}) async {
    _state = SubscriptionLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _subscription =
          await SubscriptionService.getActiveSubscription(token: token);
      _state = SubscriptionLoadState.loaded;
    } catch (e) {
      _errorMessage = _parseError(e);
      _state = SubscriptionLoadState.error;
    }

    notifyListeners();
  }

  void clear() {
    _subscription = null;
    _state = SubscriptionLoadState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Crear checkout ────────────────────────────────────────
  Future<String?> createCheckout({
    required String token,
    required String priceId,
  }) async {
    _checkoutLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await SubscriptionService.createCheckout(
          token: token, priceId: priceId);
      return result.url;
    } catch (e) {
      _errorMessage = _parseError(e);
      return null;
    } finally {
      _checkoutLoading = false;
      notifyListeners();
    }
  }

  // ── Abrir portal de Stripe ────────────────────────────────
  Future<String?> createPortalSession({required String token}) async {
    _portalLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await SubscriptionService.createPortalSession(token: token);
      return url;
    } catch (e) {
      _errorMessage = _parseError(e);
      return null;
    } finally {
      _portalLoading = false;
      notifyListeners();
    }
  }

  // ── Refrescar ─────────────────────────────────────────────
  Future<void> refresh({required String token}) async {
    await loadActiveSubscription(token: token);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(Object e) {
    final msg = e.toString();
    return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
  }
}
