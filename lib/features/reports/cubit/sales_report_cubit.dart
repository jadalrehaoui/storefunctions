import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';

sealed class SalesReportState {}

class SalesReportInitial extends SalesReportState {}

class SalesReportLoading extends SalesReportState {}

class SalesReportLoaded extends SalesReportState {
  final List<dynamic> sitsaRows;
  final List<dynamic> mikailRows;
  SalesReportLoaded({required this.sitsaRows, required this.mikailRows});
}

class SalesReportFailure extends SalesReportState {
  final String error;
  SalesReportFailure(this.error);
}

class SalesReportCubit extends Cubit<SalesReportState> {
  final ApiClient _api;
  static const _bodega = 'B-01';
  static final _fmt = DateFormat('yyyy-MM-dd');

  SalesReportCubit(this._api) : super(SalesReportInitial());

  Future<void> load(DateTime startDate, DateTime endDate) async {
    emit(SalesReportLoading());
    try {
      final start = _fmt.format(startDate);
      final end = _fmt.format(endDate);

      final results = await Future.wait([
        _api.post('/api/sitsa/get-sales-report', {
          'salesStartDate': start,
          'salesEndDate': end,
          'bodega': _bodega,
        }),
        _api.post('/api/mikail/get-sales-report', {
          'startDate': start,
          'endDate': end,
        }),
      ]);

      emit(SalesReportLoaded(
        sitsaRows: _extractList(results[0]),
        mikailRows: _extractList(results[1]),
      ));
    } catch (e) {
      emit(SalesReportFailure(e.toString()));
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  Future<String> downloadSitsa(List<dynamic> rows) =>
      _saveCsv(rows, 'sales_sitsa');

  Future<String> downloadMikail(List<dynamic> rows) =>
      _saveCsv(rows, 'sales_mikail');

  Future<String> _saveCsv(List<dynamic> rows, String prefix) async {
    final csv = _buildCsv(rows);
    final dir = _downloadsPath();
    await Directory(dir).create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '$dir${Platform.pathSeparator}${prefix}_$timestamp.csv';
    await File(path).writeAsString(csv);
    return path;
  }

  String _buildCsv(List<dynamic> rows) {
    final headers = (rows.first as Map<String, dynamic>).keys.toList();
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escape).join(','));
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      buffer.writeln(headers.map((h) => _escape('${m[h] ?? ''}')).join(','));
    }
    return buffer.toString();
  }

  String _escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _downloadsPath() {
    if (Platform.isMacOS) {
      return '/Users/${Platform.environment['USER']}/Downloads';
    } else if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}\\Downloads';
    }
    return '.';
  }
}
