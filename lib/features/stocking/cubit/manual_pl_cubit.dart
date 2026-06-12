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
  List<Map<String, dynamic>> proveedores = [];

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

  Future<void> loadProveedores() async {
    try {
      final data = await _inventoryService.getProveedores();
      final list = data is List
          ? data
          : (data is Map ? (data['data'] ?? []) as List : []);
      proveedores =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (state is ManualPlInitial) emit(ManualPlInitial());
    } catch (_) {}
  }

  Future<void> generate({
    DateTime? startDate,
    DateTime? endDate,
    String? clasificacion,
    String? proveedor,
    String mode = 'sold',
    String matchMode = 'exact',
  }) async {
    emit(ManualPlLoading());
    try {
      final body = <String, dynamic>{
        'bodega': _bodega,
        'mode': mode,
        'matchMode': matchMode,
      };
      // Only send dates when BOTH are present; omit entirely for "all time".
      if (startDate != null && endDate != null) {
        body['salesStartDate'] = _fmt.format(startDate);
        body['salesEndDate'] = _fmt.format(endDate);
      }
      if (clasificacion != null) {
        body['clasificacion'] = int.parse(clasificacion);
      }
      if (proveedor != null && proveedor.isNotEmpty) {
        body['proveedor'] = proveedor;
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
