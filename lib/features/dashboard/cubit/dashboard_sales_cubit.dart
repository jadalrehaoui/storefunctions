import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.toInt() ?? 0);
  return 0;
}

class DashboardSalesData {
  final double brutTotal;
  final double totalBonos;
  final double totalDiscount;
  final int clientCount;
  final double averageSpentPerClient;

  const DashboardSalesData({
    required this.brutTotal,
    required this.totalBonos,
    required this.totalDiscount,
    required this.clientCount,
    required this.averageSpentPerClient,
  });

  double get netSales => brutTotal - totalBonos - totalDiscount;

  factory DashboardSalesData.fromResponse(Map<String, dynamic> data) {
    final general = data['general'] is Map
        ? Map<String, dynamic>.from(data['general'] as Map)
        : <String, dynamic>{};
    final clients = data['clients'] is Map
        ? Map<String, dynamic>.from(data['clients'] as Map)
        : <String, dynamic>{};
    return DashboardSalesData(
      brutTotal: _toDouble(general['BrutTotal']),
      totalBonos: _toDouble(general['TotalBonos']),
      totalDiscount: _toDouble(general['TotalDiscount']),
      clientCount: _toInt(clients['ClientCount']),
      averageSpentPerClient: _toDouble(clients['AverageSpentPerClient']),
    );
  }

  static const empty = DashboardSalesData(
    brutTotal: 0,
    totalBonos: 0,
    totalDiscount: 0,
    clientCount: 0,
    averageSpentPerClient: 0,
  );
}

class WorkdbSalesData {
  final double total;
  final double totalDiscount;
  final double netTotal;
  final int itemsCount;
  final int invoiceCount;

  const WorkdbSalesData({
    required this.total,
    required this.totalDiscount,
    required this.netTotal,
    required this.itemsCount,
    required this.invoiceCount,
  });

  factory WorkdbSalesData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    return WorkdbSalesData(
      total: _toDouble(data['total']),
      totalDiscount: _toDouble(data['total_discount']),
      netTotal: _toDouble(data['net_total']),
      itemsCount: _toInt(data['items_count']),
      invoiceCount: _toInt(data['invoice_count']),
    );
  }

  static const empty = WorkdbSalesData(
    total: 0,
    totalDiscount: 0,
    netTotal: 0,
    itemsCount: 0,
    invoiceCount: 0,
  );
}

class MikailSalesData {
  final double total;
  final int totalItems;

  const MikailSalesData({required this.total, required this.totalItems});

  factory MikailSalesData.fromJson(Map<String, dynamic> json) {
    final total = _toDouble(json['total']);
    final detail = (json['detail'] as List?) ?? const [];
    final items = detail.fold<double>(
        0, (acc, e) => acc + _toDouble((e as Map)['Cantidad']));
    return MikailSalesData(total: total, totalItems: items.round());
  }

  static const empty = MikailSalesData(total: 0, totalItems: 0);
}

sealed class DashboardSalesState {}

class DashboardSalesLoading extends DashboardSalesState {}

class DashboardSalesLoaded extends DashboardSalesState {
  final DashboardSalesData current;
  final DashboardSalesData lastYear;
  final DashboardSalesData twoYearsAgo;
  final MikailSalesData mikail;
  final WorkdbSalesData workdb;
  final DateTime startDate;
  final DateTime endDate;
  DashboardSalesLoaded(
    this.current, {
    required this.lastYear,
    required this.twoYearsAgo,
    required this.mikail,
    required this.workdb,
    required this.startDate,
    required this.endDate,
  });
}

class DashboardSalesFailure extends DashboardSalesState {
  final String error;
  final DateTime startDate;
  final DateTime endDate;
  DashboardSalesFailure(this.error,
      {required this.startDate, required this.endDate});
}

class DashboardSalesCubit extends Cubit<DashboardSalesState> {
  final ApiClient _api;
  static final _fmt = DateFormat('yyyy-MM-dd');
  Timer? _timer;
  late DateTime _startDate;
  late DateTime _endDate;

  DashboardSalesCubit(this._api) : super(DashboardSalesLoading()) {
    final today = DateTime.now();
    _startDate = today;
    _endDate = today;
  }

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  void start() {
    load();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => load());
  }

  void selectRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    load();
  }

  Map<String, String> _rangeBody(DateTime start, DateTime end) => {
        'startDate': _fmt.format(start),
        'endDate': _fmt.format(end),
      };

  Future<DashboardSalesData> _fetchSitsa(DateTime start, DateTime end) async {
    final data = await _api.post(
        '/api/sitsa/get-daily-report', _rangeBody(start, end));
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return DashboardSalesData.fromResponse(map);
  }

  Future<MikailSalesData> _fetchMikail(DateTime start, DateTime end) async {
    final data = await _api.post(
        '/api/mikail/get-daily-report', _rangeBody(start, end));
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return MikailSalesData.fromJson(map);
  }

  Future<WorkdbSalesData> _fetchWorkdb(DateTime start, DateTime end) async {
    final qs =
        'start_date=${_fmt.format(start)}&end_date=${_fmt.format(end)}';
    final data = await _api.get('/api/workdb/invoices/totals?$qs');
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return WorkdbSalesData.fromJson(map);
  }

  DateTime _shiftYears(DateTime d, int years) =>
      DateTime(d.year - years, d.month, d.day);

  Future<void> load() async {
    emit(DashboardSalesLoading());
    try {
      final start = _startDate;
      final end = _endDate;
      final lastYearStart = _shiftYears(start, 1);
      final lastYearEnd = _shiftYears(end, 1);
      final twoYearsStart = _shiftYears(start, 2);
      final twoYearsEnd = _shiftYears(end, 2);

      final results = await (
        _fetchSitsa(start, end),
        _fetchSitsa(lastYearStart, lastYearEnd),
        _fetchSitsa(twoYearsStart, twoYearsEnd),
        _fetchMikail(start, end),
        _fetchWorkdb(start, end),
      ).wait;

      emit(DashboardSalesLoaded(
        results.$1,
        lastYear: results.$2,
        twoYearsAgo: results.$3,
        mikail: results.$4,
        workdb: results.$5,
        startDate: start,
        endDate: end,
      ));
    } catch (e) {
      emit(DashboardSalesFailure(e.toString(),
          startDate: _startDate, endDate: _endDate));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
