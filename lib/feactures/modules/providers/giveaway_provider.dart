import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kolekta/core/utils/error_parser.dart';
import '../services/giveaway_service.dart';

class GiveawayProvider extends ChangeNotifier {
  List<Giveaway> _giveaways = [];
  Giveaway? _selectedGiveaway;
  int _openCount = 0;
  int _total = 0;
  bool _loading = false;
  bool _actionLoading = false;
  String? _errorMessage;

  GiveawayStatus? _statusFilter;

  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;

  // ── Getters ──────────────────────────────────────────────────────────────

  List<Giveaway> get giveaways => _giveaways;
  Giveaway? get selectedGiveaway => _selectedGiveaway;
  int get openCount => _openCount;
  int get total => _total;
  bool get loading => _loading;
  bool get actionLoading => _actionLoading;
  String? get errorMessage => _errorMessage;
  GiveawayStatus? get statusFilter => _statusFilter;
  bool get hasMore => _hasMore;
  bool get isEmpty => !_loading && _giveaways.isEmpty;

  // ── Cargar rifas ──────────────────────────────────────────────────────────

  Future<void> loadGiveaways(String token, {bool silent = false}) async {
    _currentOffset = 0;
    _hasMore = true;
    if (!silent) {
      _loading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final result = await GiveawayService.listGiveaways(
        token: token,
        status: _statusFilter,
        limit: _pageSize,
        offset: 0,
      );
      final list = (result['giveaways'] as List<dynamic>)
          .map((e) => Giveaway.fromJson(e as Map<String, dynamic>))
          .toList();
      _giveaways = list;
      _total = result['total'] as int? ?? list.length;
      _hasMore = list.length >= _pageSize;
      _currentOffset = list.length;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }

    if (_statusFilter == null || _statusFilter == GiveawayStatus.open) {
      try {
        _openCount = await GiveawayService.getOpenGiveawaysCount(token: token);
        notifyListeners();
      } catch (_) {}
    }
  }

  // ── Cargar más ────────────────────────────────────────────────────────────

  Future<void> loadMore(String token) async {
    if (!_hasMore || _loading) return;
    try {
      final result = await GiveawayService.listGiveaways(
        token: token,
        status: _statusFilter,
        limit: _pageSize,
        offset: _currentOffset,
      );
      final list = (result['giveaways'] as List<dynamic>)
          .map((e) => Giveaway.fromJson(e as Map<String, dynamic>))
          .toList();
      _giveaways.addAll(list);
      _total = result['total'] as int? ?? _total;
      _hasMore = list.length >= _pageSize;
      _currentOffset += list.length;
      notifyListeners();
    } catch (_) {}
  }

  // ── Filtro de status ──────────────────────────────────────────────────────

  Future<void> setStatusFilter(String token, GiveawayStatus? status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    await loadGiveaways(token);
  }

  // ── Conteo (home) ─────────────────────────────────────────────────────────

  Future<void> loadOpenCount(String token) async {
    try {
      _openCount = await GiveawayService.getOpenGiveawaysCount(token: token);
      notifyListeners();
    } catch (_) {}
  }

  // ── Detalle ───────────────────────────────────────────────────────────────

  Future<bool> loadGiveawayDetail(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: id);
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

  // ── Crear rifa ────────────────────────────────────────────────────────────

  Future<Giveaway?> createGiveaway({
    required String token,
    required String title,
    String? description,
    required String drawDate,
    DateTime? autoDrawAt,
    required double ticketPrice,
    required int totalTickets,
    int prizeCount = 1,
    File? coverImageFile,
    List<PrizeInput> prizes = const [],
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final giveaway = await GiveawayService.createGiveaway(
        token: token,
        title: title,
        description: description,
        drawDate: drawDate,
        autoDrawAt: autoDrawAt,
        ticketPrice: ticketPrice,
        totalTickets: totalTickets,
        prizeCount: prizeCount,
        coverImageFile: coverImageFile,
        prizes: prizes,
      );
      _giveaways.insert(0, giveaway);
      _total++;
      _openCount++;
      notifyListeners();
      return giveaway;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Editar rifa ───────────────────────────────────────────────────────────

  Future<bool> updateGiveaway({
    required String token,
    required String id,
    String? title,
    String? description,
    String? drawDate,
    DateTime? autoDrawAt,
    bool clearAutoDraw = false,
    double? ticketPrice,
    int? prizeCount,
    File? coverImageFile,
    bool removeCoverImage = false,
    List<PrizeInput> prizes = const [],
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await GiveawayService.updateGiveaway(
        token: token,
        id: id,
        title: title,
        description: description,
        drawDate: drawDate,
        autoDrawAt: autoDrawAt,
        clearAutoDraw: clearAutoDraw,
        ticketPrice: ticketPrice,
        prizeCount: prizeCount,
        coverImageFile: coverImageFile,
        removeCoverImage: removeCoverImage,
        prizes: prizes,
      );
      _replaceGiveaway(updated);
      if (_selectedGiveaway?.id == id) _selectedGiveaway = updated;
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

  // ── Cancelar rifa ─────────────────────────────────────────────────────────

  Future<bool> cancelGiveaway(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GiveawayService.cancelGiveaway(token: token, id: id);
      await loadGiveaways(token);
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

  // ── Eliminar rifa ─────────────────────────────────────────────────────────

  Future<bool> deleteGiveaway(String token, String id) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GiveawayService.deleteGiveaway(token: token, id: id);
      _giveaways.removeWhere((g) => g.id == id);
      if (_selectedGiveaway?.id == id) _selectedGiveaway = null;
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

  // ── Asignar boleto ────────────────────────────────────────────────────────

  Future<bool> assignTicket({
    required String token,
    required String giveawayId,
    required int ticketNumber,
    required String clientName,
    String? clientPhone,
    bool paid = false,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GiveawayService.assignTicket(
        token: token,
        giveawayId: giveawayId,
        ticketNumber: ticketNumber,
        clientName: clientName,
        clientPhone: clientPhone,
        paid: paid,
      );
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: giveawayId);
      _replaceGiveaway(_selectedGiveaway!);
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

  // ── Actualizar boleto ─────────────────────────────────────────────────────

  Future<bool> updateTicket({
    required String token,
    required String giveawayId,
    required String ticketId,
    String? clientName,
    String? clientPhone,
    bool? paid,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GiveawayService.updateTicket(
        token: token,
        giveawayId: giveawayId,
        ticketId: ticketId,
        clientName: clientName,
        clientPhone: clientPhone,
        paid: paid,
      );
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: giveawayId);
      _replaceGiveaway(_selectedGiveaway!);
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

  // ── Cancelar boleto ───────────────────────────────────────────────────────

  Future<bool> cancelTicket({
    required String token,
    required String giveawayId,
    required String ticketId,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GiveawayService.cancelTicket(
        token: token,
        giveawayId: giveawayId,
        ticketId: ticketId,
      );
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: giveawayId);
      _replaceGiveaway(_selectedGiveaway!);
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

  // ── Sorteo aleatorio ──────────────────────────────────────────────────────

  Future<List<GiveawayTicket>?> drawRandom({
    required String token,
    required String giveawayId,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final winners = await GiveawayService.drawRandom(
          token: token, giveawayId: giveawayId);
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: giveawayId);
      _replaceGiveaway(_selectedGiveaway!);
      notifyListeners();
      return winners;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Sorteo manual ─────────────────────────────────────────────────────────

  Future<List<GiveawayTicket>?> drawManual({
    required String token,
    required String giveawayId,
    required List<int> winnerTicketNumbers,
  }) async {
    _actionLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final winners = await GiveawayService.drawManual(
        token: token,
        giveawayId: giveawayId,
        winnerTicketNumbers: winnerTicketNumbers,
      );
      _selectedGiveaway =
          await GiveawayService.getGiveaway(token: token, id: giveawayId);
      _replaceGiveaway(_selectedGiveaway!);
      notifyListeners();
      return winners;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _replaceGiveaway(Giveaway updated) {
    final idx = _giveaways.indexWhere((g) => g.id == updated.id);
    if (idx != -1) _giveaways[idx] = updated;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSelected() {
    _selectedGiveaway = null;
    notifyListeners();
  }

  String _parseError(Object e) => AppErrorParser.parse(e);
}
