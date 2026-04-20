import 'package:flutter/material.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  int _total = 0;
  bool _loading = false;
  bool _actionLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Product> get products => _products;
  int get total => _total;
  bool get loading => _loading;
  bool get actionLoading => _actionLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get hasMore => _hasMore;
  bool get isEmpty => !_loading && _products.isEmpty;

  // ── Cargar productos ──────────────────────────────────────────────────────

  Future<void> loadProducts(String token, {bool silent = false}) async {
    _currentOffset = 0;
    _hasMore = true;
    if (!silent) {
      _loading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await ProductService.listProducts(
        token: token,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: 0,
      );

      final list = (result['products'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();

      _products = list;
      _total = result['total'] as int;
      _hasMore = list.length >= _pageSize;
      _currentOffset = list.length;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _parse(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Cargar más ────────────────────────────────────────────────────────────

  Future<void> loadMore(String token) async {
    if (!_hasMore || _loading) return;

    try {
      final result = await ProductService.listProducts(
        token: token,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final list = (result['products'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();

      _products.addAll(list);
      _total = result['total'] as int;
      _hasMore = list.length >= _pageSize;
      _currentOffset += list.length;
      notifyListeners();
    } catch (_) {
      // silencioso en paginación
    }
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  Future<void> setSearch(String token, String query) async {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
    await loadProducts(token);
  }

  // ── Crear producto ────────────────────────────────────────────────────────

  Future<Product?> createProduct({
    required String token,
    required String description,
    required double price,
    String? imageBase64,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final product = await ProductService.createProduct(
        token: token,
        description: description,
        price: price,
        imageBase64: imageBase64,
      );
      _products.insert(0, product);
      _total++;
      notifyListeners();
      return product;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Editar producto ───────────────────────────────────────────────────────

  Future<bool> updateProduct({
    required String token,
    required String id,
    String? description,
    double? price,
    String? imageBase64,
    bool removeImage = false,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await ProductService.updateProduct(
        token: token,
        id: id,
        description: description,
        price: price,
        imageBase64: imageBase64,
        removeImage: removeImage,
      );
      final idx = _products.indexWhere((p) => p.id == updated.id);
      if (idx != -1) _products[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Eliminar producto ─────────────────────────────────────────────────────

  Future<bool> deleteProduct(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ProductService.deleteProduct(token: token, id: id);
      _products.removeWhere((p) => p.id == id);
      _total = _total > 0 ? _total - 1 : 0;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parse(e);
      notifyListeners();
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parse(Object e) {
    final msg = e.toString();
    return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
  }
}
