import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

class DashboardSalesData {
  final int totalCount;
  final int totalNulled;
  final double brutTotal;
  final double totalBonos;
  final double totalDiscount;
  final int clientCount;
  final double averageSpentPerClient;

  const DashboardSalesData({
    required this.totalCount,
    required this.totalNulled,
    required this.brutTotal,
    required this.totalBonos,
    required this.totalDiscount,
    required this.clientCount,
    required this.averageSpentPerClient,
  });

  double get netSales => brutTotal - totalBonos - totalDiscount;

  factory DashboardSalesData.fromJson(Map<String, dynamic> json) {
    return DashboardSalesData(
      totalCount: (json['TotalCount'] as num?)?.toInt() ?? 0,
      totalNulled: (json['TotalNulled'] as num?)?.toInt() ?? 0,
      brutTotal: (json['BrutTotal'] as num?)?.toDouble() ?? 0.0,
      totalBonos: (json['TotalBonos'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (json['TotalDiscount'] as num?)?.toDouble() ?? 0.0,
      clientCount: (json['ClientCount'] as num?)?.toInt() ?? 0,
      averageSpentPerClient:
          (json['AverageSpentPerClient'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MikailSalesData {
  final double total;
  final int totalItems;

  const MikailSalesData({required this.total, required this.totalItems});

  factory MikailSalesData.fromJson(Map<String, dynamic> json) {
    return MikailSalesData(
      total: (json['Total'] as num?)?.toDouble() ?? 0.0,
      totalItems: (json['TotalItems'] as num?)?.toInt() ?? 0,
    );
  }
}

sealed class DashboardSalesState {}

class DashboardSalesLoading extends DashboardSalesState {}

class DashboardSalesLoaded extends DashboardSalesState {
  final DashboardSalesData current;
  final DashboardSalesData lastYear;
  final DashboardSalesData twoYearsAgo;
  final MikailSalesData mikail;
  final DateTimeRange range;
  DashboardSalesLoaded(this.current,
      {required this.lastYear,
      required this.twoYearsAgo,
      required this.mikail,
      required this.range});
}

class DashboardSalesFailure extends DashboardSalesState {
  final String error;
  final DateTimeRange range;
  DashboardSalesFailure(this.error, {required this.range});
}

class DashboardSalesCubit extends Cubit<DashboardSalesState> {
  final ApiClient _api;
  Timer? _timer;
  late DateTimeRange _selectedRange;

  DashboardSalesCubit(this._api) : super(DashboardSalesLoading()) {
    final today = DateTime.now();
    _selectedRange = DateTimeRange(start: today, end: today);
  }

  DateTimeRange get selectedRange => _selectedRange;

  void start() {
    load();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => load());
  }

  void selectRange(DateTimeRange range) {
    _selectedRange = range;
    load();
  }

  Future<DashboardSalesData> _fetchSitsa(Map<String, dynamic> body) async {
    final data = await _api.post('/api/sitsa/get-dashboard-sales', body);
    final map = (data is Map && data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    return DashboardSalesData.fromJson(map);
  }

  Future<MikailSalesData> _fetchMikail(Map<String, dynamic> body) async {
    final data = await _api.post('/api/mikail/get-dashboard-sales', body);
    final map = (data is Map && data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    return MikailSalesData.fromJson(map);
  }

  Future<void> load() async {
    emit(DashboardSalesLoading());
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final startDate =
          _selectedRange.start.toIso8601String().substring(0, 10);
      final endDate = _selectedRange.end.toIso8601String().substring(0, 10);
      final isToday = startDate == today && endDate == today;

      Map<String, dynamic> _yearBody(int yearsBack) {
        final s = DateTime(
          _selectedRange.start.year - yearsBack,
          _selectedRange.start.month,
          _selectedRange.start.day,
        );
        final e = DateTime(
          _selectedRange.end.year - yearsBack,
          _selectedRange.end.month,
          _selectedRange.end.day,
        );
        return {
          'startDate': s.toIso8601String().substring(0, 10),
          'endDate': e.toIso8601String().substring(0, 10),
        };
      }

      final currentBody =
          isToday ? <String, dynamic>{} : {'startDate': startDate, 'endDate': endDate};

      final results = await (
        _fetchSitsa(currentBody),
        _fetchSitsa(_yearBody(1)),
        _fetchSitsa(_yearBody(2)),
        _fetchMikail(currentBody),
      ).wait;

      emit(DashboardSalesLoaded(
        results.$1,
        lastYear: results.$2,
        twoYearsAgo: results.$3,
        mikail: results.$4,
        range: _selectedRange,
      ));
    } catch (e) {
      emit(DashboardSalesFailure(e.toString(), range: _selectedRange));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
