import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';
import '../../../services/inventory_service.dart';

sealed class ManualPlState {}

class ManualPlInitial extends ManualPlState {}

class ManualPlLoading extends ManualPlState {}

class ManualPlLoaded extends ManualPlState {
  final List<dynamic> rows;
  ManualPlLoaded(this.rows);
}

class ManualPlFailure extends ManualPlState {
  final String error;
  ManualPlFailure(this.error);
}

class ManualPlCubit extends Cubit<ManualPlState> {
  final ApiClient _api;
  final InventoryService _inventoryService;
  static final _fmt = DateFormat('yyyy-MM-dd');
  static const _bodega = 'B-01';

  List<Map<String, dynamic>> clasificaciones = [];

  ManualPlCubit(this._api, this._inventoryService)
      : super(ManualPlInitial());

  Future<void> loadClasificaciones() async {
    try {
      final data = await _inventoryService.getClasificaciones();
      final list = data is List
          ? data
          : (data is Map ? (data['data'] ?? []) as List : []);
      clasificaciones =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (state is ManualPlInitial) emit(ManualPlInitial());
    } catch (_) {}
  }

  Future<void> generate({
    required DateTime startDate,
    required DateTime endDate,
    String? clasificacion,
    String mode = 'sold',
  }) async {
    emit(ManualPlLoading());
    try {
      final body = <String, dynamic>{
        'salesStartDate': _fmt.format(startDate),
        'salesEndDate': _fmt.format(endDate),
        'bodega': _bodega,
        'mode': mode,
      };
      if (clasificacion != null) {
        body['clasificacion'] = int.parse(clasificacion);
      }
      final data =
          await _api.post('/api/sitsa/get-sales-report-by-clasificacion', body);
      final rows = data is Map
          ? ((data['data'] ?? []) as List)
          : (data is List ? data : []);
      emit(ManualPlLoaded(rows));
    } on DioException catch (e) {
      emit(ManualPlFailure(
          'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}'));
    } catch (e) {
      emit(ManualPlFailure(e.toString()));
    }
  }
}
