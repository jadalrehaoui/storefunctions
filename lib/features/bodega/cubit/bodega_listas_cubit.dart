import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/bodega_service.dart';
import 'bodega_listas_state.dart';

export 'bodega_listas_state.dart';

class BodegaListasCubit extends Cubit<BodegaListasState> {
  final BodegaService _service;

  StreamSubscription<BodegaListaEvent>? _sseSub;
  bool _closed = false;

  BodegaListasCubit(this._service) : super(BodegaListasInitial());

  Future<void> init() async {
    await _loadInitial();
    _subscribe();
  }

  Future<void> _loadInitial() async {
    emit(BodegaListasLoading());
    try {
      final items = await _service.getList();
      final prevFilter = _prevFilter();
      emit(BodegaListasReady(items: items, creatorFilter: prevFilter));
    } on DioException catch (e) {
      emit(BodegaListasFailure(_dioMessage(e)));
    } catch (e) {
      emit(BodegaListasFailure(e.toString()));
    }
  }

  String? _prevFilter() {
    final s = state;
    return s is BodegaListasReady ? s.creatorFilter : null;
  }

  void _subscribe() {
    _sseSub?.cancel();
    _sseSub = _service.subscribe().listen(
      _onEvent,
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
    final s = state;
    if (s is BodegaListasReady) {
      emit(s.copyWith(liveConnected: true));
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    final s = state;
    if (s is BodegaListasReady) {
      emit(s.copyWith(liveConnected: false));
    }
    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (_closed) return;
      // Re-fetch to catch anything missed while the stream was down, then
      // re-subscribe.
      try {
        final items = await _service.getList();
        final s2 = state;
        if (s2 is BodegaListasReady) {
          emit(s2.copyWith(items: items));
        }
      } catch (_) {
        // leave current state; next reconnect attempt will retry
      }
      if (!_closed) _subscribe();
    });
  }

  void _onEvent(BodegaListaEvent event) {
    final s = state;
    if (s is! BodegaListasReady) return;

    switch (event) {
      case BodegaItemAddedEvent(item: final item):
        final idx = s.items.indexWhere((x) => x.id == item.id);
        final next = [...s.items];
        if (idx >= 0) {
          next[idx] = item;
        } else {
          next.add(item);
        }
        emit(s.copyWith(items: next));
      case BodegaItemUpdatedEvent(item: final item):
        final idx = s.items.indexWhere((x) => x.id == item.id);
        final next = [...s.items];
        if (idx >= 0) {
          next[idx] = item;
        } else {
          next.add(item);
        }
        emit(s.copyWith(items: next));
      case BodegaItemsRemovedEvent(ids: final ids):
        final set = ids.toSet();
        final next = s.items.where((x) => !set.contains(x.id)).toList();
        emit(s.copyWith(items: next));
    }
  }

  Future<void> addByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final s = state;
    if (s is! BodegaListasReady) return;

    emit(s.copyWith(addInFlight: true, transientError: null));
    try {
      // The SSE stream will deliver the authoritative item_added/updated event;
      // we don't need to merge the POST response into local state.
      await _service.addItem(trimmed);
      final cur = state;
      if (cur is BodegaListasReady) {
        emit(cur.copyWith(addInFlight: false));
      }
    } on DioException catch (e) {
      final cur = state;
      if (cur is BodegaListasReady) {
        emit(cur.copyWith(
            addInFlight: false, transientError: _dioMessage(e)));
      }
    } catch (e) {
      final cur = state;
      if (cur is BodegaListasReady) {
        emit(cur.copyWith(
            addInFlight: false, transientError: e.toString()));
      }
    }
  }

  Future<void> removeItem(int id) async {
    try {
      await _service.removeItem(id);
    } on DioException catch (e) {
      final cur = state;
      if (cur is BodegaListasReady) {
        emit(cur.copyWith(transientError: _dioMessage(e)));
      }
    }
  }

  /// Removes the given ids in bulk. Used by the print-then-remove flow.
  /// Returns true on success so the caller can decide what to do on failure.
  Future<bool> removeItems(List<int> ids) async {
    if (ids.isEmpty) return true;
    try {
      await _service.removeItems(ids);
      return true;
    } on DioException catch (e) {
      final cur = state;
      if (cur is BodegaListasReady) {
        emit(cur.copyWith(transientError: _dioMessage(e)));
      }
      return false;
    }
  }

  void setCreatorFilter(String? username) {
    final s = state;
    if (s is! BodegaListasReady) return;
    emit(s.copyWith(creatorFilter: username));
  }

  void setPrintInFlight(bool value) {
    final s = state;
    if (s is BodegaListasReady) {
      emit(s.copyWith(printInFlight: value));
    }
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.response?.statusCode == 404) return 'Artículo no encontrado';
    if (e.response?.statusCode == 403) return 'Sin privilegio bodega_user';
    return e.message ?? 'Error de conexión';
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _sseSub?.cancel();
    return super.close();
  }
}
