import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/inventory_service.dart';
import 'export_inventory_state.dart';

export 'export_inventory_state.dart';

class ExportInventoryCubit extends Cubit<ExportInventoryState> {
  final InventoryService _inventoryService;
  List<Map<String, dynamic>> clasificaciones = [];

  ExportInventoryCubit(this._inventoryService) : super(ExportInventoryInitial());

  Future<void> loadClasificaciones() async {
    try {
      final data = await _inventoryService.getClasificaciones();
      final list = data is List
          ? data
          : (data is Map ? (data['data'] ?? []) as List : []);
      clasificaciones = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      print('[ExportInventory] clasificaciones error: $e');
    }
  }

  Future<void> export({
    DateTime? startingDate,
    DateTime? endingDate,
    String? clasificacion,
  }) async {
    emit(ExportInventoryLoading());
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final data = await _inventoryService.getInventory(
        startingDate: startingDate != null ? fmt.format(startingDate) : null,
        endingDate: endingDate != null ? fmt.format(endingDate) : null,
        clasificacion: clasificacion,
      );

      final items = (data is Map && data['data'] is List)
          ? data['data'] as List<dynamic>
          : <dynamic>[];

      if (items.isEmpty) {
        emit(ExportInventoryFailure('No hay datos para exportar.'));
        return;
      }

      final csv = _buildCsv(items);
      final filePath = await _saveCsv(csv);
      emit(ExportInventorySuccess(filePath: filePath, rowCount: items.length));
    } on DioException catch (e) {
      emit(ExportInventoryFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(ExportInventoryFailure(e.toString()));
    }
  }

  String _buildCsv(List<dynamic> items) {
    final first = items.first as Map<String, dynamic>;
    final headers = first.keys.toList();

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));

    for (final row in items) {
      final m = row as Map<String, dynamic>;
      buffer.writeln(headers.map((h) => _escapeCsv('${m[h] ?? ''}')).join(','));
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<String> _saveCsv(String csv) async {
    final downloadsDir = _getDownloadsPath();
    await Directory(downloadsDir).create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '$downloadsDir${Platform.pathSeparator}inventario_$timestamp.csv';
    await File(filePath).writeAsString(csv);
    return filePath;
  }

  String _getDownloadsPath() {
    if (Platform.isMacOS) {
      final user = Platform.environment['USER'] ?? '';
      return '/Users/$user/Downloads';
    } else if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}\\Downloads';
    }
    return '.';
  }
}
