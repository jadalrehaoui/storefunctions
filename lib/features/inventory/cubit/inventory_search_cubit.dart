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

  Future<void> search(String input) async {
    final c = input.trim();
    if (c.isEmpty) return;

    final hasLetter = c.contains(RegExp(r'[a-zA-Z]'));
    if (hasLetter) {
      await _searchByDescription(c);
    } else {
      await _searchByCode(c);
    }
  }

  Future<void> _searchByDescription(String description) async {
    emit(InventorySearchLoading());
    try {
      final data = await _inventoryService.searchByDescripcion(description);
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
      final data = await _inventoryService.getItemsByModelo(modelo);
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
