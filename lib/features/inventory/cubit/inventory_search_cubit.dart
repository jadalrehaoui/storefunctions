// ignore_for_file: avoid_print
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/combined_item.dart';
import '../../../services/inventory_service.dart';
import 'inventory_search_state.dart';

export 'inventory_search_state.dart';

class InventorySearchCubit extends Cubit<InventorySearchState> {
  final InventoryService _inventoryService;

  InventorySearchCubit(this._inventoryService)
      : super(InventorySearchInitial());

  bool _includeZero = false;
  bool get includeZero => _includeZero;

  InventorySearchDescriptionResults? _previousResults;
  bool get hasPreviousResults => _previousResults != null;
  String? get previousQuery => _previousResults?.query;

  Future<void> setIncludeZero(bool value) async {
    if (_includeZero == value) return;
    _includeZero = value;
    final s = state;
    if (s is InventorySearchDescriptionResults) {
      if (s.query.startsWith('/')) {
        await _searchByModelo(s.query.substring(1));
      } else {
        await _searchByDescription(s.query);
      }
    } else if (s is InventorySearchSuccess && s.modeloItems != null) {
      final modelo = s.item.sitsa?.model;
      if (modelo != null) await loadModeloItems(modelo);
    }
  }

  void backToResults() {
    final prev = _previousResults;
    if (prev == null) return;
    _previousResults = null;
    emit(prev);
  }

  Future<void> search(String input) async {
    final c = input.trim();
    if (c.isEmpty) return;

    if (c.startsWith('/')) {
      final modelo = c.substring(1).trim();
      if (modelo.isEmpty) return;
      await _searchByModelo(modelo);
      return;
    }

    final hasLetter = c.contains(RegExp(r'[a-zA-Z]'));
    if (hasLetter) {
      await _searchByDescription(c);
    } else {
      await _searchByCode(c);
    }
  }

  Future<void> _searchByModelo(String modelo) async {
    _previousResults = null;
    emit(InventorySearchLoading());
    try {
      final data = await _inventoryService.getItemsByModelo(modelo,
          includeZero: _includeZero);
      final items = (data is Map && data['data'] is List)
          ? data['data'] as List<dynamic>
          : <dynamic>[];
      emit(InventorySearchDescriptionResults(
          query: '/$modelo', items: items, raw: data));
    } on DioException catch (e) {
      emit(InventorySearchFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(InventorySearchFailure(e.toString()));
    }
  }

  Future<void> _searchByDescription(String description) async {
    _previousResults = null;
    emit(InventorySearchLoading());
    try {
      final data = await _inventoryService.searchByDescripcion(description,
          includeZero: _includeZero);
      final items = (data is Map && data['data'] is List)
          ? data['data'] as List<dynamic>
          : <dynamic>[];
      emit(InventorySearchDescriptionResults(
          query: description, items: items, raw: data));
    } on DioException catch (e) {
      emit(InventorySearchFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(InventorySearchFailure(e.toString()));
    }
  }

  Future<void> _searchByCode(String code) async {
    final prior = state;
    if (prior is InventorySearchDescriptionResults) {
      _previousResults = prior;
    }
    emit(InventorySearchLoading());
    try {
      final data = await _inventoryService.getItemCombined(code);
      print('==== COMBINED GET-ITEM RAW RESPONSE ($code) ====');
      print(data);
      print('================================================');
      final item = CombinedItem.fromJson(data);
      emit(InventorySearchSuccess(item));

      final barcode = item.sitsa?.codigoBarras;
      if (barcode != null && barcode.isNotEmpty) {
        final tica = await _fetchTica(barcode);
        if (!isClosed) {
          final current = state;
          if (current is InventorySearchSuccess &&
              current.item.code == item.code) {
            emit(current.copyWith(item: current.item.withTica(tica)));
          }
        }
      }
    } on DioException catch (e) {
      emit(InventorySearchFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(InventorySearchFailure(e.toString()));
    }
  }

  Future<void> loadModeloItems(String modelo) async {
    final current = state;
    if (current is! InventorySearchSuccess) return;

    emit(current.copyWith(modeloLoading: true, clearModeloItems: true));
    try {
      final data = await _inventoryService.getItemsByModelo(modelo,
          includeZero: _includeZero);
      final items = (data is Map && data['data'] is List)
          ? data['data'] as List<dynamic>
          : <dynamic>[];
      if (!isClosed) {
        final s = state;
        if (s is InventorySearchSuccess) {
          emit(s.copyWith(modeloLoading: false, modeloItems: items));
        }
      }
    } catch (_) {
      if (!isClosed) {
        final s = state;
        if (s is InventorySearchSuccess) {
          emit(s.copyWith(modeloLoading: false));
        }
      }
    }
  }

  Future<String?> _fetchTica(String barcode) async {
    try {
      final data = await _inventoryService.getTicaData(barcode);
      if (data is Map && data['success'] == true) {
        return data['tica'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
