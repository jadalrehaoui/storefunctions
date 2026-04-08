import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/invoice_service.dart';
import '../../invoices/model/invoice_models.dart';

class ParallelItemSold {
  final String sitsaCode;
  final String description;
  final double quantity;
  final double gross;
  final double discount;
  final double net;

  const ParallelItemSold({
    required this.sitsaCode,
    required this.description,
    required this.quantity,
    required this.gross,
    required this.discount,
    required this.net,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ParallelItemSold.fromJson(Map<String, dynamic> json) =>
      ParallelItemSold(
        sitsaCode: json['sitsa_code']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        quantity: _d(json['total_quantity']),
        gross: _d(json['total_gross']),
        discount: _d(json['total_discount']),
        net: _d(json['total_net']),
      );
}

class ParallelDailySummary {
  final DateTime date;
  final List<InvoiceSummary> invoices;
  final List<InvoiceSummary> voidedInvoices;
  final List<ParallelItemSold> itemsSold;

  const ParallelDailySummary({
    required this.date,
    required this.invoices,
    required this.voidedInvoices,
    required this.itemsSold,
  });

  double get totalGross => itemsSold.fold(0, (s, i) => s + i.gross);
  double get totalDiscount => itemsSold.fold(0, (s, i) => s + i.discount);
  double get totalNet => itemsSold.fold(0, (s, i) => s + i.net);

  factory ParallelDailySummary.fromJson(Map<String, dynamic> json) {
    List<InvoiceSummary> parseInvoices(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(InvoiceSummary.fromJson)
          .toList();
    }

    final rawItems = (json['items_sold'] as List?) ?? const [];
    return ParallelDailySummary(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      invoices: parseInvoices(json['invoices']),
      voidedInvoices: parseInvoices(json['voided_invoices']),
      itemsSold: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ParallelItemSold.fromJson)
          .toList(),
    );
  }
}

sealed class CierreParallelState {}

class CierreParallelInitial extends CierreParallelState {}

class CierreParallelLoading extends CierreParallelState {}

class CierreParallelSuccess extends CierreParallelState {
  final ParallelDailySummary summary;
  CierreParallelSuccess(this.summary);
}

class CierreParallelFailure extends CierreParallelState {
  final String error;
  CierreParallelFailure(this.error);
}

class CierreParallelCubit extends Cubit<CierreParallelState> {
  final InvoiceService _service;
  DateTime _date;

  CierreParallelCubit(this._service)
      : _date = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day),
        super(CierreParallelInitial());

  DateTime get date => _date;

  void setDate(DateTime d) {
    _date = DateTime(d.year, d.month, d.day);
  }

  Future<void> generate() async {
    emit(CierreParallelLoading());
    try {
      final data = await _service.dailySummary(_date);
      final map = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>);
      emit(CierreParallelSuccess(ParallelDailySummary.fromJson(map)));
    } on DioException catch (e) {
      emit(CierreParallelFailure(
          'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}'));
    } catch (e) {
      emit(CierreParallelFailure(e.toString()));
    }
  }
}
