import 'package:flutter/material.dart';
import 'package:kolekta/core/utils/error_parser.dart';
import '../services/catalog_service.dart';

class CatalogProvider extends ChangeNotifier {
  List<Sale> _sales = [];
  Sale? _selectedSale;
  int _total = 0;
  bool _loading = false;
  bool _actionLoading = false;
  String? _errorMessage;

  SaleStatus? _statusFilter;

  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Sale> get sales => _sales;
  Sale? get selectedSale => _selectedSale;
  int get total => _total;
  bool get loading => _loading;
  bool get actionLoading => _actionLoading;
  String? get errorMessage => _errorMessage;
  SaleStatus? get statusFilter => _statusFilter;
  bool get hasMore => _hasMore;
  bool get isEmpty => !_loading && _sales.isEmpty;

  double get pendingBalance => _sales
      .where((s) => s.status == SaleStatus.pending)
      .fold(0.0, (sum, s) => sum + s.balance);

  int get pendingCount =>
      _sales.where((s) => s.status == SaleStatus.pending).length;

  // ── Cargar ventas ─────────────────────────────────────────────────────────

  Future<void> loadSales(String token, {bool silent = false}) async {
    _currentOffset = 0;
    _hasMore = true;
    if (!silent) {
      _loading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await CatalogService.listSales(
        token: token,
        status: _statusFilter,
        limit: _pageSize,
        offset: 0,
      );

      final list = (result['sales'] as List<dynamic>)
          .map((e) => Sale.fromJson(e as Map<String, dynamic>))
          .toList();

      _sales = list;
      _total = result['total'] as int;
      _hasMore = list.length >= _pageSize;
      _currentOffset = list.length;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Cargar más ────────────────────────────────────────────────────────────

  Future<void> loadMore(String token) async {
    if (!_hasMore || _loading) return;

    try {
      final result = await CatalogService.listSales(
        token: token,
        status: _statusFilter,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final list = (result['sales'] as List<dynamic>)
          .map((e) => Sale.fromJson(e as Map<String, dynamic>))
          .toList();

      _sales.addAll(list);
      _total = result['total'] as int;
      _hasMore = list.length >= _pageSize;
      _currentOffset += list.length;
      notifyListeners();
    } catch (_) {}
  }

  // ── Filtro de status ──────────────────────────────────────────────────────

  Future<void> setStatusFilter(String token, SaleStatus? status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    await loadSales(token);
  }

  // ── Detalle ───────────────────────────────────────────────────────────────

  Future<bool> loadSaleDetail(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedSale = await CatalogService.getSale(token: token, id: id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Crear venta ───────────────────────────────────────────────────────────

  Future<Sale?> createSale({
    required String token,
    required String clientName,
    String? clientPhone,
    required String title,
    required String date,
    required List<Map<String, dynamic>> items,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final sale = await CatalogService.createSale(
        token: token,
        clientName: clientName,
        clientPhone: clientPhone,
        title: title,
        date: date,
        items: items,
      );
      _sales.insert(0, sale);
      _total++;
      notifyListeners();
      return sale;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Editar venta ──────────────────────────────────────────────────────────

  Future<bool> updateSale({
    required String token,
    required String id,
    String? title,
    String? clientPhone,
    List<Map<String, dynamic>>? items,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await CatalogService.updateSale(
        token: token,
        id: id,
        title: title,
        clientPhone: clientPhone,
        items: items,
      );
      _replaceSale(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Cancelar venta ────────────────────────────────────────────────────────

  Future<bool> cancelSale(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await CatalogService.cancelSale(token: token, id: id);
      _replaceSale(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Eliminar venta ────────────────────────────────────────────────────────

  Future<bool> deleteSale(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await CatalogService.deleteSale(token: token, id: id);
      _sales.removeWhere((s) => s.id == id);
      if (_selectedSale?.id == id) _selectedSale = null;
      _total = _total > 0 ? _total - 1 : 0;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Registrar pago ────────────────────────────────────────────────────────

  Future<bool> createPayment({
    required String token,
    required String saleId,
    required double amount,
    required DateTime date,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await CatalogService.createPayment(
        token: token,
        saleId: saleId,
        amount: amount,
        date: date,
      );
      final updatedSale =
          Sale.fromJson(result['sale'] as Map<String, dynamic>);
      _replaceSale(updatedSale);
      if (_selectedSale?.id == saleId) {
        _selectedSale = await CatalogService.getSale(token: token, id: saleId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Cancelar pago ─────────────────────────────────────────────────────────

  Future<bool> cancelPayment({
    required String token,
    required String paymentId,
    required String saleId,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await CatalogService.cancelPayment(token: token, paymentId: paymentId);
      final updated = await CatalogService.getSale(token: token, id: saleId);
      _replaceSale(updated);
      if (_selectedSale?.id == saleId) _selectedSale = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Eliminar pago ─────────────────────────────────────────────────────────

  Future<bool> deletePayment({
    required String token,
    required String paymentId,
    required String saleId,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await CatalogService.deletePayment(token: token, paymentId: paymentId);
      final updated = await CatalogService.getSale(token: token, id: saleId);
      _replaceSale(updated);
      if (_selectedSale?.id == saleId) _selectedSale = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _replaceSale(Sale updated) {
    final idx = _sales.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _sales[idx] = updated;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSelected() {
    _selectedSale = null;
    notifyListeners();
  }

   String _parseError(Object e) => AppErrorParser.parse(e);
}