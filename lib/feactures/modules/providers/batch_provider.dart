import 'dart:io';
import 'package:flutter/material.dart';
import '../services/batch_service.dart';

class BatchProvider extends ChangeNotifier {
  List<Batch> _batchs = [];
  Batch? _selectedBatch;
  int _activeBatchsCount = 0;
  bool _loading = false;
  String? _errorMessage;

  // Filtro por status
  BatchStatus? _statusFilter;

  // Paginación
  int _total = 0;
  int _currentOffset = 0;
  bool _hasMore = true;
  static const int _pageSize = 20;

  // ── Getters ──────────────────────────────────────────────
  List<Batch> get batchs => _batchs;
  Batch? get selectedBatch => _selectedBatch;
  int get activeBatchsCount => _activeBatchsCount;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  BatchStatus? get statusFilter => _statusFilter;
  int get total => _total;
  bool get hasMore => _hasMore;

  // Listas filtradas por status actual (usadas en los tabs)
  List<Batch> get activeBatchs =>
      _batchs.where((b) => b.status == BatchStatus.active).toList();
  List<Batch> get finishedBatchs =>
      _batchs.where((b) => b.status == BatchStatus.finished).toList();
  List<Batch> get cancelledBatchs =>
      _batchs.where((b) => b.status == BatchStatus.cancelled).toList();

  // ── Cargar lista ─────────────────────────────────────────
  Future<void> loadBatchs(String token, {bool silent = false}) async {
  _currentOffset = 0;
  _hasMore = true;

  if (!silent) {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
  }

  try {
    final result = await BatchService.listBatchs(
      token: token,
      status: _statusFilter,
      limit: _pageSize,
      offset: 0,
    );

    final list = (result['batchs'] as List<dynamic>)
        .map((e) => Batch.fromJson(e as Map<String, dynamic>))
        .toList();

    _batchs = list;
    _total = result['total'] as int? ?? list.length;   // ← más seguro
    _hasMore = list.length >= _pageSize;
    _currentOffset = list.length;

    // Solo actualizar conteo activo cuando sea necesario
    if (_statusFilter == null || _statusFilter == BatchStatus.active) {
      try {
        _activeBatchsCount = await BatchService.getActiveBatchsCount(token: token);
      } catch (_) {
        // no romper el flujo
      }
    }

    notifyListeners();
  } catch (e) {
    _errorMessage = _parse(e);
    notifyListeners();
  } finally {
    _loading = false;
    notifyListeners();
  }
}

// ── Cargar más ───────────────────────────────────────────────────────
  Future<void> loadMore(String token) async {
    if (!_hasMore || _loading) return;

    try {
      final result = await BatchService.listBatchs(
        token: token,
        status: _statusFilter,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final list = (result['batchs'] as List<dynamic>)
          .map((e) => Batch.fromJson(e as Map<String, dynamic>))
          .toList();

      _batchs.addAll(list);
      _total = result['total'] as int;
      _hasMore = list.length >= _pageSize;
      _currentOffset += list.length;

      notifyListeners();
    } catch (_) {
      // silencioso
    }
  }

  // ── Cambiar filtro de status (llamado desde el TabBar) ─────────────────
  Future<void> setStatusFilter(String token, BatchStatus? status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    await loadBatchs(token);
  }
  // ── Cargar conteo para home ──────────────────────────────
  Future<void> loadActiveBatchsCount(String token) async {
    try {
      _activeBatchsCount =
          await BatchService.getActiveBatchsCount(token: token);
      notifyListeners();
    } catch (_) {
      // silencioso: no bloquear home si falla
    }
  }

  // ── Cargar detalle ───────────────────────────────────────
  Future<bool> loadBatchDetail(String token, String id) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _selectedBatch = await BatchService.getBatch(token: token, id: id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Crear tanda ──────────────────────────────────────────
  Future<Batch?> createBatch({
    required String token,
    required String name,
    required double entryPrice,
    required int totalSlots,
    required BatchFrequency frequency,
    required String startDate,
    String? notes,
    List<ParticipantInput> participants = const [],
    bool randomize = false,
    File? coverImageFile,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final batch = await BatchService.createBatch(
        token: token,
        name: name,
        entryPrice: entryPrice,
        totalSlots: totalSlots,
        frequency: frequency,
        startDate: startDate,
        notes: notes,
        participants: participants,
        randomize: randomize,
        coverImageFile: coverImageFile,
      );
      _batchs.insert(0, batch);
      _activeBatchsCount++;
      notifyListeners();
      return batch;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ── Actualizar tanda (nombre, notas, imagen) ─────────────
  Future<bool> updateBatch({
    required String token,
    required String batchId,
    String? name,
    String? notes,
    File? coverImageFile,
    bool removeCoverImage = false,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final updated = await BatchService.updateBatch(
        token: token,
        batchId: batchId,
        name: name,
        notes: notes,
        coverImageFile: coverImageFile,
        removeCoverImage: removeCoverImage,
      );
      // Actualizar en la lista general
      final idx = _batchs.indexWhere((b) => b.id == batchId);
      if (idx != -1) _batchs[idx] = updated;
      // Si es la tanda seleccionada, actualizar también
      if (_selectedBatch?.id == batchId) _selectedBatch = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Registrar entrega ────────────────────────────────────
  Future<bool> registerDelivery({
    required String token,
    required String batchId,
    required String detailId,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await BatchService.registerDelivery(
        token: token,
        batchId: batchId,
        detailId: detailId,
      );
      // Recargar detalle actualizado (para batch_detail_screen)
      _selectedBatch = await BatchService.getBatch(token: token, id: batchId);
      // Actualizar en la lista general (para batchs_home_screen)
      final idx = _batchs.indexWhere((b) => b.id == batchId);
      if (idx != -1) _batchs[idx] = _selectedBatch!;
      // Recalcular conteo de activas (puede haber terminado la tanda)
      _activeBatchsCount =
          _batchs.where((b) => b.status == BatchStatus.active).length;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Cancelar tanda ───────────────────────────────────────
  Future<bool> cancelBatch({
    required String token,
    required String batchId,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await BatchService.cancelBatch(token: token, batchId: batchId);
      await loadBatchs(token); // refrescar lista completa
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Eliminar tanda ───────────────────────────────────
  Future<bool> deleteBatch({
    required String token,
    required String batchId,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await BatchService.deleteBatch(token: token, batchId: batchId);
      _batchs.removeWhere((b) => b.id == batchId);
      if (_selectedBatch?.id == batchId) _selectedBatch = null;
      _activeBatchsCount =
          _batchs.where((b) => b.status == BatchStatus.active).length;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSelected() {
    _selectedBatch = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _parse(Object e) {
    final msg = e.toString();
    return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
  }
}
