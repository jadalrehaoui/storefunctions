import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/invoice_service.dart';
import '../model/invoice_models.dart';

sealed class InvoiceDetailState {}

class InvoiceDetailLoading extends InvoiceDetailState {}

class InvoiceDetailSuccess extends InvoiceDetailState {
  final InvoiceDetail invoice;
  InvoiceDetailSuccess(this.invoice);
}

class InvoiceDetailFailure extends InvoiceDetailState {
  final String error;
  InvoiceDetailFailure(this.error);
}

class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final InvoiceService _service;
  final String invoiceId;

  InvoiceDetailCubit(this._service, this.invoiceId)
      : super(InvoiceDetailLoading());

  Future<void> load() async {
    emit(InvoiceDetailLoading());
    try {
      final data = await _service.getInvoice(invoiceId);
      final map = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map<String, dynamic>);
      emit(InvoiceDetailSuccess(InvoiceDetail.fromJson(map)));
    } on DioException catch (e) {
      emit(InvoiceDetailFailure(e.message ?? 'error'));
    } catch (e) {
      emit(InvoiceDetailFailure(e.toString()));
    }
  }

  Future<bool> voidInvoice() async {
    try {
      await _service.voidInvoice(invoiceId);
      await load();
      return true;
    } on DioException catch (e) {
      emit(InvoiceDetailFailure(
          'Void failed (HTTP ${e.response?.statusCode}): ${e.response?.data ?? e.message}'));
      return false;
    } catch (e) {
      emit(InvoiceDetailFailure('Void failed: $e'));
      return false;
    }
  }
}
