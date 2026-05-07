import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/inventory_service.dart';

sealed class StagnantItemsState {}

class StagnantItemsInitial extends StagnantItemsState {}

class StagnantItemsLoading extends StagnantItemsState {}

class StagnantItemsLoaded extends StagnantItemsState {
  final List<Map<String, dynamic>> rows;
  StagnantItemsLoaded(this.rows);
}

class StagnantItemsFailure extends StagnantItemsState {
  final String error;
  StagnantItemsFailure(this.error);
}

class StagnantItemsCubit extends Cubit<StagnantItemsState> {
  final InventoryService _inventoryService;

  List<Map<String, dynamic>> clasificaciones = [];

  StagnantItemsCubit(this._inventoryService) : super(StagnantItemsInitial());

  Future<void> loadClasificaciones() async {
    try {
      final data = await _inventoryService.getClasificaciones();
      final list = data is List
          ? data
          : (data is Map ? (data['data'] ?? []) as List : []);
      clasificaciones =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (state is StagnantItemsInitial) emit(StagnantItemsInitial());
    } catch (_) {}
  }

  Future<void> generate({
    int days = 90,
    int? clasificacion,
    int limit = 500,
  }) async {
    emit(StagnantItemsLoading());
    try {
      final data = await _inventoryService.getStagnantItems(
        days: days,
        clasificacion: clasificacion,
        limit: limit,
      );
      final rows = (data is Map && data['data'] is List)
          ? (data['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      emit(StagnantItemsLoaded(rows));
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = body is Map ? body['error']?.toString() : null;
      emit(StagnantItemsFailure(
          msg ?? 'HTTP ${e.response?.statusCode}: ${e.message}'));
    } catch (e) {
      emit(StagnantItemsFailure(e.toString()));
    }
  }
}
