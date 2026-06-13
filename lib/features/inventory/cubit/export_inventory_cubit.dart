import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
      // Trigger a rebuild for listeners watching the cubit's state.
      if (state is ExportInventoryInitial) emit(ExportInventoryInitial());
    } catch (e) {
      print('[ExportInventory] clasificaciones error: $e');
    }
  }

  Future<void> export({
    DateTime? startingDate,
    DateTime? endingDate,
    List<String>? clasificaciones,
  }) async {
    emit(ExportInventoryLoading());
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final data = await _inventoryService.getInventory(
        startingDate: startingDate != null ? fmt.format(startingDate) : null,
        endingDate: endingDate != null ? fmt.format(endingDate) : null,
        clasificaciones: clasificaciones,
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

  /// Export limited to the chosen [columns] (each `(label, key)` where `key`
  /// is the JSON key in `get-inventory.data`). When [tica] is true the request
  /// asks the API to fetch live Tica saldos (slow).
  Future<void> exportSelected({
    DateTime? startingDate,
    DateTime? endingDate,
    List<String>? clasificaciones,
    bool tica = false,
    int? concurrency,
    required List<({String label, String key})> columns,
  }) async {
    if (columns.isEmpty) {
      emit(ExportInventoryFailure('Selecciona al menos una columna.'));
      return;
    }
    emit(ExportInventoryLoading(
        stage: tica ? 'Consultando inventario + Tica...' : null));
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final data = await _inventoryService.getInventory(
        startingDate: startingDate != null ? fmt.format(startingDate) : null,
        endingDate: endingDate != null ? fmt.format(endingDate) : null,
        clasificaciones: clasificaciones,
        tica: tica,
        concurrency: concurrency,
      );

      final items = (data is Map && data['data'] is List)
          ? (data['data'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      if (items.isEmpty) {
        emit(ExportInventoryFailure('No hay datos para exportar.'));
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln(columns.map((c) => _escapeCsv(c.label)).join(','));
      for (final row in items) {
        buffer.writeln(
            columns.map((c) => _escapeCsv('${row[c.key] ?? ''}')).join(','));
      }
      final filePath = await _saveCsv(buffer.toString());
      emit(ExportInventorySuccess(filePath: filePath, rowCount: items.length));
    } on DioException catch (e) {
      emit(ExportInventoryFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(ExportInventoryFailure(e.toString()));
    }
  }

  Future<void> exportWithTica({
    DateTime? startingDate,
    DateTime? endingDate,
    List<String>? clasificaciones,
  }) async {
    emit(ExportInventoryLoading(stage: 'Seleccionando archivo de TICA...'));
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'html', 'htm', 'txt'],
        withData: false,
      );
    } catch (e) {
      emit(ExportInventoryFailure('No se pudo abrir el selector: $e'));
      return;
    }
    if (picked == null || picked.files.isEmpty) {
      emit(ExportInventoryInitial());
      return;
    }
    final path = picked.files.single.path;
    if (path == null) {
      emit(ExportInventoryFailure('No se pudo leer el archivo de TICA.'));
      return;
    }

    emit(ExportInventoryLoading(stage: 'Leyendo archivo de TICA...'));
    try {
      final ticaMap = await _parseTicaFile(path);
      if (ticaMap.isEmpty) {
        emit(ExportInventoryFailure(
            'No se encontraron productos en el archivo de TICA.'));
        return;
      }

      emit(ExportInventoryLoading(
          stage:
              'Descargando inventario SITSA (${ticaMap.length} productos en TICA)...'));
      final fmt = DateFormat('yyyy-MM-dd');
      final data = await _inventoryService.getInventory(
        startingDate: startingDate != null ? fmt.format(startingDate) : null,
        endingDate: endingDate != null ? fmt.format(endingDate) : null,
        clasificaciones: clasificaciones,
      );
      final sitsaItems = (data is Map && data['data'] is List)
          ? (data['data'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];

      emit(ExportInventoryLoading(stage: 'Generando CSV combinado...'));
      final csv = _buildJoinedCsv(sitsaItems, ticaMap);
      final filePath = await _saveCsv(csv, prefix: 'inventario_tica');
      final rowCount = _countJoinedRows(sitsaItems, ticaMap);
      emit(ExportInventorySuccess(filePath: filePath, rowCount: rowCount));
    } on DioException catch (e) {
      emit(ExportInventoryFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(ExportInventoryFailure(e.toString()));
    }
  }

  Future<Map<String, _TicaRow>> _parseTicaFile(String path) async {
    final bytes = await File(path).readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final productoRe =
        RegExp(r'<producto>([\s\S]*?)</producto>', caseSensitive: false);
    final codigoRe = RegExp(r'<codigo>\s*([\s\S]*?)\s*</codigo>',
        caseSensitive: false);
    final descripRe = RegExp(r'<descrip>\s*([\s\S]*?)\s*</descrip>',
        caseSensitive: false);
    final saldoRe =
        RegExp(r'<saldo>\s*([\s\S]*?)\s*</saldo>', caseSensitive: false);

    final result = <String, _TicaRow>{};
    for (final match in productoRe.allMatches(content)) {
      final block = match.group(1) ?? '';
      final codigo = codigoRe.firstMatch(block)?.group(1)?.trim() ?? '';
      if (codigo.isEmpty) continue;
      final descripcion = descripRe.firstMatch(block)?.group(1)?.trim() ?? '';
      final saldo = saldoRe.firstMatch(block)?.group(1)?.trim() ?? '0';
      result[codigo] = _TicaRow(descripcion: descripcion, saldo: saldo);
    }
    return result;
  }

  String? _barcodeOf(Map<String, dynamic> row) {
    for (final key in const [
      'Codigo_Barras',
      'CodigoBarras',
      'codigoBarras',
      'codigo_barras',
      'Codigo',
      'codigo',
      'Barcode',
      'barcode',
    ]) {
      final v = row[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
  }

  int _countJoinedRows(
      List<Map<String, dynamic>> sitsa, Map<String, _TicaRow> tica) {
    final sitsaCodes = sitsa.map(_barcodeOf).whereType<String>().toSet();
    final ticaOnly = tica.keys.where((c) => !sitsaCodes.contains(c)).length;
    return sitsa.length + ticaOnly;
  }

  String _buildJoinedCsv(
      List<Map<String, dynamic>> sitsa, Map<String, _TicaRow> tica) {
    final headers = sitsa.isNotEmpty
        ? sitsa.first.keys.toList()
        : <String>['CodigoBarras', 'Descripcion'];
    if (!headers.contains('Codigo_Barras') &&
        !headers.contains('CodigoBarras') &&
        !headers.contains('codigoBarras') &&
        !headers.contains('codigo_barras')) {
      headers.add('Codigo_Barras');
    }
    if (!headers.any((h) => h.toLowerCase().contains('descrip'))) {
      headers.add('Descripcion');
    }
    headers.add('TICA_Saldo');

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));

    final matchedCodes = <String>{};
    for (final row in sitsa) {
      final code = _barcodeOf(row);
      final ticaRow = code != null ? tica[code] : null;
      if (ticaRow != null) matchedCodes.add(code!);
      final values = headers.map((h) {
        if (h == 'TICA_Saldo') return _escapeCsv(ticaRow?.saldo ?? '0');
        return _escapeCsv('${row[h] ?? ''}');
      });
      buffer.writeln(values.join(','));
    }

    final descripKey = headers.firstWhere(
      (h) => h.toLowerCase().contains('descrip'),
      orElse: () => 'Descripcion',
    );
    final codigoKey = headers.firstWhere(
      (h) =>
          h == 'Codigo_Barras' ||
          h == 'CodigoBarras' ||
          h == 'codigoBarras' ||
          h == 'codigo_barras' ||
          h == 'Codigo' ||
          h == 'codigo',
      orElse: () => 'Codigo_Barras',
    );

    for (final entry in tica.entries) {
      if (matchedCodes.contains(entry.key)) continue;
      final values = headers.map((h) {
        if (h == 'TICA_Saldo') return _escapeCsv(entry.value.saldo);
        if (h == codigoKey) return _escapeCsv(entry.key);
        if (h == descripKey) return _escapeCsv(entry.value.descripcion);
        return '';
      });
      buffer.writeln(values.join(','));
    }

    return buffer.toString();
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

  Future<String> _saveCsv(String csv, {String prefix = 'inventario'}) async {
    final downloadsDir = _getDownloadsPath();
    await Directory(downloadsDir).create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath =
        '$downloadsDir${Platform.pathSeparator}${prefix}_$timestamp.csv';
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

class _TicaRow {
  final String descripcion;
  final String saldo;
  const _TicaRow({required this.descripcion, required this.saldo});
}
