import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/inventory_service.dart';
import 'sales_by_codes_state.dart';

export 'sales_by_codes_state.dart';

class SalesByCodesCubit extends Cubit<SalesByCodesState> {
  final InventoryService _inventoryService;
  String? _filePath;

  SalesByCodesCubit(this._inventoryService)
      : super(const SalesByCodesInitial());

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) {
      emit(const SalesByCodesFailure('No se pudo leer el archivo.'));
      return;
    }
    _filePath = file.path;
    emit(SalesByCodesInitial(selectedFileName: file.name));
  }

  void clearFile() {
    _filePath = null;
    emit(const SalesByCodesInitial());
  }

  Future<void> run() async {
    final path = _filePath;
    final name = state.selectedFileName;
    if (path == null || name == null) {
      emit(const SalesByCodesFailure('Selecciona un archivo primero.'));
      return;
    }

    try {
      final input = await _readCsv(path);
      if (input.rows.isEmpty) {
        emit(SalesByCodesFailure('El archivo está vacío.',
            selectedFileName: name));
        return;
      }

      final total = input.rows.length;
      emit(SalesByCodesRunning(
          processed: 0, total: total, selectedFileName: name));

      final outputRows = <List<String>>[];
      int notFound = 0;

      for (var i = 0; i < input.rows.length; i++) {
        final row = input.rows[i];
        final code = row.isNotEmpty ? row.first.trim() : '';
        final stats = code.isEmpty
            ? _ItemStats.empty
            : await _fetchStats(code);
        if (!stats.found) notFound++;

        outputRows.add([
          ...row,
          _formatNum(stats.vendidoSitsa),
          _formatNum(stats.vendidoMikail),
          _formatNum(stats.vendidoParallel),
          _formatNum(stats.ingresadoSitsa),
        ]);

        if (i % 5 == 0 || i == input.rows.length - 1) {
          emit(SalesByCodesRunning(
              processed: i + 1, total: total, selectedFileName: name));
        }
      }

      final headers = [
        ...input.headers,
        if (input.headers.length < input.rows.first.length)
          ...List.generate(
              input.rows.first.length - input.headers.length, (_) => ''),
        'Vendido_SITSA',
        'Vendido_Mikail',
        'Vendido_Parallel',
        'Ingresado_SITSA',
      ];

      final csv = _buildCsv(headers, outputRows);
      final filePath = await _saveCsv(csv);
      emit(SalesByCodesSuccess(
        filePath: filePath,
        rowCount: outputRows.length,
        notFoundCount: notFound,
        selectedFileName: name,
      ));
    } on DioException catch (e) {
      emit(SalesByCodesFailure(e.message ?? 'Error de conexión',
          selectedFileName: name));
    } catch (e) {
      emit(SalesByCodesFailure(e.toString(), selectedFileName: name));
    }
  }

  Future<_ItemStats> _fetchStats(String code) async {
    try {
      final data = await _inventoryService.getItemCombined(code);
      if (data is! Map) return _ItemStats.empty;

      double pick(dynamic node, List<String> keys) {
        if (node is! Map) return 0;
        for (final k in keys) {
          final v = node[k];
          if (v is num) return v.toDouble();
          if (v != null) {
            final parsed = double.tryParse(v.toString());
            if (parsed != null) return parsed;
          }
        }
        return 0;
      }

      final found = data['sitsa'] is Map ||
          data['mikail'] is Map ||
          data['workdb'] is Map;
      return _ItemStats(
        vendidoSitsa: pick(data['sitsa'], const ['VendidoEnSitsa']),
        vendidoMikail: pick(data['mikail'], const ['VendidoEnMikail']),
        vendidoParallel: pick(data['workdb'], const ['VendidoEnWorkdb']),
        ingresadoSitsa: pick(data['sitsa'], const ['Ingresado']),
        found: found,
      );
    } catch (_) {
      return _ItemStats.empty;
    }
  }

  Future<_ParsedCsv> _readCsv(String path) async {
    final bytes = await File(path).readAsBytes();
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }

    final lines = const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const _ParsedCsv(headers: [], rows: []);

    final delim = _detectDelim(lines.first);
    final firstRow = _splitCsvLine(lines.first, delim);
    final firstCell = firstRow.isNotEmpty ? firstRow.first.trim() : '';
    final hasHeader = !RegExp(r'^[0-9]+$').hasMatch(firstCell);

    final headers = hasHeader ? firstRow : ['Codigo_Barras'];
    final dataLines = hasHeader ? lines.skip(1) : lines;
    final rows = dataLines.map((l) => _splitCsvLine(l, delim)).toList();
    return _ParsedCsv(headers: headers, rows: rows);
  }

  String _detectDelim(String line) {
    final commas = ','.allMatches(line).length;
    final semis = ';'.allMatches(line).length;
    final tabs = '\t'.allMatches(line).length;
    if (semis > commas && semis >= tabs) return ';';
    if (tabs > commas && tabs > semis) return '\t';
    return ',';
  }

  List<String> _splitCsvLine(String line, String delim) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delim && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  String _buildCsv(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  Future<String> _saveCsv(String csv) async {
    final downloadsDir = _getDownloadsPath();
    await Directory(downloadsDir).create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath =
        '$downloadsDir${Platform.pathSeparator}ventas_por_codigos_$timestamp.csv';
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

class _ItemStats {
  final double vendidoSitsa;
  final double vendidoMikail;
  final double vendidoParallel;
  final double ingresadoSitsa;
  final bool found;

  const _ItemStats({
    required this.vendidoSitsa,
    required this.vendidoMikail,
    required this.vendidoParallel,
    required this.ingresadoSitsa,
    required this.found,
  });

  static const _ItemStats empty = _ItemStats(
    vendidoSitsa: 0,
    vendidoMikail: 0,
    vendidoParallel: 0,
    ingresadoSitsa: 0,
    found: false,
  );
}

class _ParsedCsv {
  final List<String> headers;
  final List<List<String>> rows;
  const _ParsedCsv({required this.headers, required this.rows});
}
