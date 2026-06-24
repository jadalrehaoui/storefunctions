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
  final List<dynamic> parallelRows;
  final List<dynamic> parallelWorkdbRows;
  SalesReportLoaded({
    required this.sitsaRows,
    required this.mikailRows,
    required this.parallelRows,
    required this.parallelWorkdbRows,
  });
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

      final sitsaFuture = _api.post('/api/sitsa/get-sales-report', {
        'salesStartDate': start,
        'salesEndDate': end,
        'bodega': _bodega,
      });
      final mikailFuture = _api.post('/api/mikail/get-sales-report', {
        'startDate': start,
        'endDate': end,
      });
      final parallelFuture = _loadParallel(startDate, endDate);

      final sitsaRes = await sitsaFuture;
      final mikailRes = await mikailFuture;
      final parallel = await parallelFuture;

      emit(SalesReportLoaded(
        sitsaRows: _extractList(sitsaRes),
        mikailRows: _extractList(mikailRes),
        parallelRows: parallel.$1,
        parallelWorkdbRows: parallel.$2,
      ));
    } catch (e) {
      emit(SalesReportFailure(e.toString()));
    }
  }

  /// Aggregates parallel daily summaries day-by-day into a single rows list
  /// keyed by sitsa_code, summing quantity, gross, discount, net.
  /// (Backend has no range endpoint yet — looping is acceptable for typical
  /// monthly ranges. Ask backend for a range endpoint if this gets slow.)
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      _loadParallel(DateTime startDate, DateTime endDate) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final dates = <String>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      dates.add(_fmt.format(d));
    }

    final results = await Future.wait(dates.map((d) => _api
        .get('/api/workdb/invoices/daily-summary?date=$d')
        .catchError((_) => <String, dynamic>{})));

    // SITSA-sourced and WorkDB-sourced are aggregated into separate maps and
    // never summed together.
    final bySitsa = <String, Map<String, dynamic>>{};
    final byWorkdb = <String, Map<String, dynamic>>{};

    void aggregate(Map<String, Map<String, dynamic>> byCode, dynamic items) {
      if (items is! List) return;
      for (final raw in items) {
        if (raw is! Map) continue;
        final code = '${raw['sitsa_code'] ?? ''}';
        if (code.isEmpty) continue;
        final cur = byCode.putIfAbsent(
            code,
            () => {
                  'sitsa_code': code,
                  'description': raw['description']?.toString() ?? '',
                  'total_quantity': 0.0,
                  'total_gross': 0.0,
                  'total_discount': 0.0,
                  'total_net': 0.0,
                });
        double n(dynamic v) => v is num
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '') ?? 0.0;
        cur['total_quantity'] =
            (cur['total_quantity'] as double) + n(raw['total_quantity']);
        cur['total_gross'] =
            (cur['total_gross'] as double) + n(raw['total_gross']);
        cur['total_discount'] =
            (cur['total_discount'] as double) + n(raw['total_discount']);
        cur['total_net'] = (cur['total_net'] as double) + n(raw['total_net']);
      }
    }

    for (final res in results) {
      final map = (res is Map && res['data'] is Map)
          ? res['data'] as Map
          : (res is Map ? res : const {});
      aggregate(bySitsa, map['items_sold']);
      aggregate(byWorkdb, map['items_sold_workdb']);
    }

    List<Map<String, dynamic>> sorted(Map<String, Map<String, dynamic>> m) =>
        m.values.toList()
          ..sort((a, b) => (b['total_net'] as double)
              .compareTo(a['total_net'] as double));

    return (sorted(bySitsa), sorted(byWorkdb));
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

  Future<String> downloadParallel(List<dynamic> rows) =>
      _saveCsv(rows, 'sales_parallel');

  Future<String> downloadWorkdb(List<dynamic> rows) =>
      _saveCsv(rows, 'sales_parallel_workdb');

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
