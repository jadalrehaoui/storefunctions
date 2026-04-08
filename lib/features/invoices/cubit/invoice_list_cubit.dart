import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/invoice_service.dart';
import '../model/invoice_models.dart';

sealed class InvoiceListState {}

class InvoiceListInitial extends InvoiceListState {}

class InvoiceListLoading extends InvoiceListState {}

class InvoiceListSuccess extends InvoiceListState {
  final List<InvoiceSummary> invoices;
  final DateTime? from;
  final DateTime? to;
  final String clientFilter;
  InvoiceListSuccess({
    required this.invoices,
    this.from,
    this.to,
    this.clientFilter = '',
  });

  InvoiceListSuccess copyWith({
    List<InvoiceSummary>? invoices,
    DateTime? from,
    DateTime? to,
    String? clientFilter,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return InvoiceListSuccess(
      invoices: invoices ?? this.invoices,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      clientFilter: clientFilter ?? this.clientFilter,
    );
  }
}

class InvoiceListFailure extends InvoiceListState {
  final String error;
  InvoiceListFailure(this.error);
}

class InvoiceListCubit extends Cubit<InvoiceListState> {
  final InvoiceService _service;
  DateTime? _from;
  DateTime? _to;
  String _client = '';

  InvoiceListCubit(this._service) : super(InvoiceListInitial()) {
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = _from;
  }

  DateTime? get from => _from;
  DateTime? get to => _to;

  Future<void> load() async {
    emit(InvoiceListLoading());
    try {
      final data = await _service.listInvoices(
        from: _from,
        to: _to,
        clientName: _client,
      );
      final raw = (data is Map && data['data'] is List)
          ? data['data'] as List
          : (data is List ? data : const []);
      final invoices = raw
          .whereType<Map<String, dynamic>>()
          .map(InvoiceSummary.fromJson)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      emit(InvoiceListSuccess(
        invoices: invoices,
        from: _from,
        to: _to,
        clientFilter: _client,
      ));
    } on DioException catch (e) {
      emit(InvoiceListFailure(e.message ?? 'error'));
    } catch (e) {
      emit(InvoiceListFailure(e.toString()));
    }
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _from = from;
    _to = to;
  }

  void setClientFilter(String client) {
    _client = client;
  }

  Future<void> generate() => load();

  Future<void> voidInvoice(String id) async {
    try {
      await _service.voidInvoice(id);
      await load();
    } catch (_) {
      // surface via snackbar from view
      rethrow;
    }
  }
}
