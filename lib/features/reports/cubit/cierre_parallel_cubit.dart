import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';
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

  /// SITSA-sourced items (from `items_sold`).
  final List<ParallelItemSold> itemsSold;

  /// WorkDB-sourced items (from `items_sold_workdb`). Never summed with [itemsSold].
  final List<ParallelItemSold> itemsSoldWorkdb;

  const ParallelDailySummary({
    required this.date,
    required this.invoices,
    required this.voidedInvoices,
    required this.itemsSold,
    this.itemsSoldWorkdb = const [],
  });

  // SITSA totals.
  double get totalGross => itemsSold.fold(0, (s, i) => s + i.gross);
  double get totalDiscount => itemsSold.fold(0, (s, i) => s + i.discount);
  double get totalNet => itemsSold.fold(0, (s, i) => s + i.net);

  // WorkDB totals (independent — never added to the SITSA totals).
  double get totalGrossWorkdb => itemsSoldWorkdb.fold(0, (s, i) => s + i.gross);
  double get totalDiscountWorkdb =>
      itemsSoldWorkdb.fold(0, (s, i) => s + i.discount);
  double get totalNetWorkdb => itemsSoldWorkdb.fold(0, (s, i) => s + i.net);

  factory ParallelDailySummary.fromJson(Map<String, dynamic> json) {
    List<InvoiceSummary> parseInvoices(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(InvoiceSummary.fromJson)
          .toList();
    }

    List<ParallelItemSold> parseItems(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ParallelItemSold.fromJson)
          .toList();
    }

    return ParallelDailySummary(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      invoices: parseInvoices(json['invoices']),
      voidedInvoices: parseInvoices(json['voided_invoices']),
      itemsSold: parseItems(json['items_sold']),
      itemsSoldWorkdb: parseItems(json['items_sold_workdb']),
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
  final ApiClient _api;
  final String? username;
  DateTime _date;
  String? _closureId;

  CierreParallelCubit(this._service, this._api, {this.username})
      : _date = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day),
        super(CierreParallelInitial());

  DateTime get date => _date;
  String? get closureId => _closureId;
  bool get isSaved => _closureId != null;

  void setDate(DateTime d) {
    _date = DateTime(d.year, d.month, d.day);
    _closureId = null;
  }

  Future<void> generate() async {
    emit(CierreParallelLoading());
    _closureId = null;
    try {
      final data = await _service.dailySummary(_date, user: username);
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

  /// Saves the current summary as a cierre parallel.
  /// Returns null on success, or an error message to surface in a snackbar.
  Future<String?> save(
    ParallelDailySummary summary, {
    required String usuario,
    String? createdBy,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(summary.date);
    final payload = _buildPayload(
      summary: summary,
      usuario: usuario,
      createdBy: createdBy,
      dateStr: dateStr,
    );
    try {
      if (_closureId != null) {
        await _api.put('/api/workdb/cierre-parallel/$_closureId', payload);
      } else {
        try {
          final res =
              await _api.post('/api/workdb/cierre-parallel', payload);
          final resData = res is Map ? res['data'] : null;
          _closureId = resData is Map ? resData['id']?.toString() : null;
        } on DioException catch (e) {
          if (e.response?.statusCode == 409) {
            final existing = await _api.get(
                '/api/workdb/cierre-parallel?date=$dateStr&usuario=${Uri.encodeQueryComponent(usuario)}');
            final id = (existing is Map)
                ? (existing['data']?['id'] ??
                        existing['data']?[0]?['id'] ??
                        existing['id'])
                    ?.toString()
                : null;
            if (id == null) rethrow;
            await _api.put('/api/workdb/cierre-parallel/$id', payload);
            _closureId = id;
          } else {
            rethrow;
          }
        }
      }
      return null;
    } on DioException catch (e) {
      return 'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Saves the whole-day Parallel cierre (non-personal flow) via the
  /// upsert-by-date endpoint. Returns null on success, or an error message.
  Future<String?> saveGeneral(ParallelDailySummary summary) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(summary.date);
    final payload = {
      'date': dateStr,
      'summary': _summaryJson(summary),
      'total_net': summary.totalNet,
      'total_gross': summary.totalGross,
      'total_discount': summary.totalDiscount,
    };
    try {
      await _api.post('/api/workdb/closures-parallel', payload);
      return null;
    } on DioException catch (e) {
      return 'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}';
    } catch (e) {
      return e.toString();
    }
  }

  Map<String, dynamic> _summaryJson(ParallelDailySummary summary) {
    Map<String, dynamic> invoiceJson(InvoiceSummary inv) => {
          'id': inv.id,
          'date': inv.date.toIso8601String(),
          'client_name': inv.clientName,
          'created_by': inv.createdBy,
          'subtotal': inv.subtotal,
          'discount': inv.discount,
          'total': inv.total,
          'status': inv.status,
        };

    return {
      'date': DateFormat('yyyy-MM-dd').format(summary.date),
      'total_gross': summary.totalGross,
      'total_discount': summary.totalDiscount,
      'total_net': summary.totalNet,
      // Independent WorkDB totals (additive keys — old rows without them still
      // read fine).
      'total_gross_workdb': summary.totalGrossWorkdb,
      'total_discount_workdb': summary.totalDiscountWorkdb,
      'total_net_workdb': summary.totalNetWorkdb,
      'active_invoices_count': summary.invoices.length,
      'voided_invoices_count': summary.voidedInvoices.length,
      'invoices': summary.invoices.map(invoiceJson).toList(),
      'voided_invoices': summary.voidedInvoices.map(invoiceJson).toList(),
      'items_sold': summary.itemsSold.map(_itemJson).toList(),
      'items_sold_workdb': summary.itemsSoldWorkdb.map(_itemJson).toList(),
    };
  }

  Map<String, dynamic> _itemJson(ParallelItemSold i) => {
        'sitsa_code': i.sitsaCode,
        'description': i.description,
        'total_quantity': i.quantity,
        'total_gross': i.gross,
        'total_discount': i.discount,
        'total_net': i.net,
      };

  Map<String, dynamic> _buildPayload({
    required ParallelDailySummary summary,
    required String usuario,
    required String? createdBy,
    required String dateStr,
  }) {
    Map<String, dynamic> invoiceJson(InvoiceSummary inv) => {
          'id': inv.id,
          'date': inv.date.toIso8601String(),
          'client_name': inv.clientName,
          'created_by': inv.createdBy,
          'subtotal': inv.subtotal,
          'discount': inv.discount,
          'total': inv.total,
          'status': inv.status,
        };

    return {
      'date': dateStr,
      'usuario': usuario,
      'created_by': createdBy,
      'totals': {
        'total_gross': summary.totalGross,
        'total_discount': summary.totalDiscount,
        'total_net': summary.totalNet,
        'total_gross_workdb': summary.totalGrossWorkdb,
        'total_discount_workdb': summary.totalDiscountWorkdb,
        'total_net_workdb': summary.totalNetWorkdb,
        'active_invoices_count': summary.invoices.length,
        'voided_invoices_count': summary.voidedInvoices.length,
      },
      'invoices': summary.invoices.map(invoiceJson).toList(),
      'voided_invoices':
          summary.voidedInvoices.map(invoiceJson).toList(),
      'items_sold': summary.itemsSold.map(_itemJson).toList(),
      'items_sold_workdb': summary.itemsSoldWorkdb.map(_itemJson).toList(),
    };
  }
}
