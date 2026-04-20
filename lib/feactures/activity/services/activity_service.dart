import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Filtro de módulo para mapear desde ActivityModule al string que espera el backend
extension ActivityModuleExt on ActivityModule {
  String get apiValue {
    switch (this) {
      case ActivityModule.batch:
        return 'batch';
      case ActivityModule.giveaway:
        return 'giveaway';
      case ActivityModule.catalog:
        return 'catalog';
    }
  }
}

class ActivityService {
  static final String _base =
      '${dotenv.env['API_BASE_URL']}/modules/activities';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── GET /activities ───────────────────────────────────────────────────────

  /// Lista las actividades del usuario con filtros opcionales.
  ///
  /// [period] puede ser "week", "month" o "all" (default "all").
  /// [module] filtra por módulo (batch | giveaway | catalog).
  /// [limit] y [offset] para paginación.
  static Future<ActivityListResult> list({
    required String token,
    String period = 'all',
    ActivityModule? module,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = {
      'period': period,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (module != null) 'module': module.apiValue,
    };

    final uri = Uri.parse('$_base/activities')
        .replace(queryParameters: params);

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return ActivityListResult.fromJson(body);
    }

    throw Exception(body['error'] ?? 'Error al cargar actividades');
  }

  // ── GET /activities/summary ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSummary({
    required String token,
    String period = 'month',
  }) async {
    final uri = Uri.parse('$_base/activities/summary')
        .replace(queryParameters: {'period': period});

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) return body;

    throw Exception(body['error'] ?? 'Error al cargar resumen');
  }

  // ── DELETE /activities/:id ────────────────────────────────────────────────

  static Future<void> deleteOne({
    required String token,
    required String id,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_base/activities/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Error al eliminar actividad');
    }
  }

  // ── DELETE /activities ────────────────────────────────────────────────────

  /// Borra todo el historial del usuario.
  /// Opcionalmente puede filtrar por módulo.
  static Future<int> clearAll({
    required String token,
    ActivityModule? module,
  }) async {
    final params = <String, String>{
      if (module != null) 'module': module.apiValue,
    };

    final uri = Uri.parse('$_base/activities')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    final response = await http
        .delete(
          uri,
          headers: {
            ..._headers(token),
            // Header requerido por el backend para confirmar la operación
            'X-Confirm-Clear': 'true',
          },
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return (body['deleted'] as int?) ?? 0;
    }

    throw Exception(body['error'] ?? 'Error al limpiar historial');
  }
}