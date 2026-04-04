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
  final MikailSalesData mikail;
  final DateTimeRange range;
  DashboardSalesLoaded(this.current,
      {required this.lastYear, required this.mikail, required this.range});
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

      final lastYearStart = DateTime(
        _selectedRange.start.year - 1,
        _selectedRange.start.month,
        _selectedRange.start.day,
      );
      final lastYearEnd = DateTime(
        _selectedRange.end.year - 1,
        _selectedRange.end.month,
        _selectedRange.end.day,
      );

      final currentBody =
          isToday ? <String, dynamic>{} : {'startDate': startDate, 'endDate': endDate};
      final lastYearBody = <String, dynamic>{
        'startDate': lastYearStart.toIso8601String().substring(0, 10),
        'endDate': lastYearEnd.toIso8601String().substring(0, 10),
      };

      final results = await (
        _fetchSitsa(currentBody),
        _fetchSitsa(lastYearBody),
        _fetchMikail(currentBody),
      ).wait;

      emit(DashboardSalesLoaded(
        results.$1,
        lastYear: results.$2,
        mikail: results.$3,
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
