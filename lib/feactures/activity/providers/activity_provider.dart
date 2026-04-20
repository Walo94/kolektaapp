import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import 'package:kolekta/core/utils/error_parser.dart';
import '../services/activity_service.dart';

enum ActivityPeriod { week, month, all }

extension ActivityPeriodExt on ActivityPeriod {
  String get apiValue {
    switch (this) {
      case ActivityPeriod.week:
        return 'week';
      case ActivityPeriod.month:
        return 'month';
      case ActivityPeriod.all:
        return 'all';
    }
  }

  String get label {
    switch (this) {
      case ActivityPeriod.week:
        return 'Esta semana';
      case ActivityPeriod.month:
        return 'Este mes';
      case ActivityPeriod.all:
        return 'Todo';
    }
  }
}

class ActivityProvider extends ChangeNotifier {
  List<ActivityModel> _activities = [];
  int _total = 0;
  bool _loading = false;
  bool _deleting = false;
  String? _errorMessage;

  // Filtros activos
  ActivityModule? _moduleFilter;
  ActivityPeriod _period = ActivityPeriod.all;

  // ── Getters ──────────────────────────────────────────────────────────────

  List<ActivityModel> get activities => _activities;
  int get total => _total;
  bool get loading => _loading;
  bool get deleting => _deleting;
  String? get errorMessage => _errorMessage;
  ActivityModule? get moduleFilter => _moduleFilter;
  ActivityPeriod get period => _period;
  bool get isEmpty => !_loading && _activities.isEmpty;

  // ── Cargar actividades ───────────────────────────────────────────────────

  Future<void> loadActivities(String token, {bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await ActivityService.list(
        token: token,
        period: _period.apiValue,
        module: _moduleFilter,
      );
      _activities = result.activities;
      _total = result.total;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Cambiar filtro de módulo ─────────────────────────────────────────────

  Future<void> setModuleFilter(
    String token,
    ActivityModule? module,
  ) async {
    if (_moduleFilter == module) return;
    _moduleFilter = module;
    notifyListeners();
    await loadActivities(token);
  }

  // ── Cambiar período ──────────────────────────────────────────────────────

  Future<void> setPeriod(String token, ActivityPeriod period) async {
    if (_period == period) return;
    _period = period;
    notifyListeners();
    await loadActivities(token);
  }

  // ── Eliminar una actividad ───────────────────────────────────────────────

  Future<bool> deleteOne(String token, String id) async {
    _deleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ActivityService.deleteOne(token: token, id: id);
      _activities.removeWhere((a) => a.id == id);
      _total = _total > 0 ? _total - 1 : 0;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  // ── Limpiar historial completo ────────────────────────────────────────────

  /// Si [module] es null, borra TODO el historial del usuario.
  /// Si [module] tiene valor, borra solo ese módulo.
  Future<bool> clearAll(String token, {ActivityModule? module}) async {
    _deleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ActivityService.clearAll(token: token, module: module);

      if (module == null) {
        _activities = [];
        _total = 0;
      } else {
        _activities.removeWhere((a) => a.module == module);
        _total = _activities.length;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  // ── Limpiar error ─────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  String _parseError(Object e) => AppErrorParser.parse(e);
}