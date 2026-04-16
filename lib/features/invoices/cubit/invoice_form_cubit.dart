import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/invoice_service.dart';
import '../model/invoice_models.dart';
import 'invoice_form_state.dart';

export 'invoice_form_state.dart';

class InvoiceFormCubit extends Cubit<InvoiceFormState> {
  final InvoiceService _service;

  /// If editing an existing invoice, set this — submit() will PUT instead of POST.
  final String? editingInvoiceId;

  InvoiceFormCubit(this._service, {this.editingInvoiceId})
      : super(InvoiceFormState.initial());

  void seedFromDetail(InvoiceDetail detail) {
    emit(state.copyWith(
      items: detail.items
          .map((i) => InvoiceLineItem(
                sitsaCode: i.sitsaCode,
                barcode: i.barcode,
                description: i.description,
                unitPrice: i.unitPrice,
                quantity: i.quantity,
                discountPct: i.discountPct,
              ))
          .toList(),
      clientName: detail.clientName ?? '',
      clientId: detail.clientId ?? '',
      date: detail.date,
      notes: detail.notes ?? '',
    ));
  }

  // ---------- header ----------

  void setClientName(String v) => emit(state.copyWith(clientName: v));
  void setClientId(String v) => emit(state.copyWith(clientId: v));
  void setNotes(String v) => emit(state.copyWith(notes: v));
  void setDate(DateTime d) => emit(state.copyWith(date: d));

  // ---------- item lookup ----------

  Future<void> lookupItem(String code) async {
    final c = code.trim();
    if (c.isEmpty) return;
    emit(state.copyWith(
      lookupLoading: true,
      clearLookupError: true,
      clearLookupResult: true,
    ));
    try {
      final data = await _service.lookupItem(c);

      // Reject explicit failure responses.
      if (data is Map && data['success'] == false) {
        emit(state.copyWith(lookupLoading: false, lookupError: 'not_found'));
        return;
      }

      // Server may wrap or return raw map. Accept both.
      final map = (data is Map && data['data'] is Map)
          ? data['data'] as Map
          : (data is Map ? data : null);
      if (map == null || map.isEmpty) {
        emit(state.copyWith(
          lookupLoading: false,
          lookupError: 'not_found',
        ));
        return;
      }

      // Require an actual item identity — otherwise treat as not found.
      final pk = map['PK_Articulo']?.toString();
      final desc = map['Descripcion'] as String?;
      if ((pk == null || pk.isEmpty) && (desc == null || desc.isEmpty)) {
        emit(state.copyWith(lookupLoading: false, lookupError: 'not_found'));
        return;
      }

      final costo = (map['Costo'] as num?)?.toDouble() ?? 0;
      final utilidad = (map['UTILIDAD'] as num?)?.toDouble() ??
          (map['Ganancia'] as num?)?.toDouble() ??
          0;
      final unitPrice = (map['Precio'] as num?)?.toDouble() ??
          costo + costo * utilidad / 100;
      final sitsaCode = pk ?? c;
      final barcode = map['Codigo_Barras'] as String?;
      final description = desc ?? '';
      final tica = map['tica'] as String?;

      // Merge into existing line if same item code, otherwise append.
      final existingIdx =
          state.items.indexWhere((i) => i.sitsaCode == sitsaCode);
      final newItems = List<InvoiceLineItem>.from(state.items);
      if (existingIdx >= 0) {
        newItems[existingIdx].quantity += 1;
      } else {
        newItems.add(InvoiceLineItem(
          sitsaCode: sitsaCode,
          barcode: barcode,
          description: description,
          unitPrice: unitPrice,
          tica: tica,
        ));
      }
      emit(state.copyWith(lookupLoading: false, items: newItems));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        emit(state.copyWith(lookupLoading: false, lookupError: 'not_found'));
      } else {
        emit(state.copyWith(
          lookupLoading: false,
          lookupError: e.message ?? 'error',
        ));
      }
    } catch (e) {
      emit(state.copyWith(lookupLoading: false, lookupError: e.toString()));
    }
  }

  void clearLookup() {
    emit(state.copyWith(clearLookupResult: true, clearLookupError: true));
  }

  /// Add (or merge into existing) line item from the current preview.
  void addPreviewToInvoice({
    required double quantity,
    required double discountPct,
  }) {
    final preview = state.lookupResult;
    if (preview == null) return;

    final existingIdx =
        state.items.indexWhere((i) => i.sitsaCode == preview.sitsaCode);
    final newItems = List<InvoiceLineItem>.from(state.items);
    if (existingIdx >= 0) {
      newItems[existingIdx].quantity += quantity;
    } else {
      newItems.add(InvoiceLineItem(
        sitsaCode: preview.sitsaCode,
        barcode: preview.barcode,
        description: preview.description,
        unitPrice: preview.unitPrice,
        quantity: quantity,
        discountPct: discountPct,
      ));
    }
    emit(state.copyWith(
      items: newItems,
      clearLookupResult: true,
      clearLookupError: true,
    ));
  }

  // ---------- line item edits ----------

  void updateLineQty(int index, double qty) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<InvoiceLineItem>.from(state.items);
    newItems[index].quantity = qty;
    emit(state.copyWith(items: newItems));
  }

  void updateLineUnitPrice(int index, double price) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<InvoiceLineItem>.from(state.items);
    newItems[index].unitPrice = price;
    emit(state.copyWith(items: newItems));
  }

  void updateLineDiscount(int index, double discount) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<InvoiceLineItem>.from(state.items);
    newItems[index].discountPct = discount;
    emit(state.copyWith(items: newItems));
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<InvoiceLineItem>.from(state.items)..removeAt(index);
    emit(state.copyWith(items: newItems));
  }

  // ---------- discount escalation ----------

  /// Returns null on success, otherwise an error string to display.
  Future<String?> authorizeDiscount({
    required String username,
    required String password,
    required double discount,
  }) async {
    try {
      final data = await _service.authorizeDiscount(
        username: username,
        password: password,
        discount: discount,
      );
      String? token;
      if (data is Map) {
        token = (data['discount_auth_token'] ??
                data['token'] ??
                data['authToken']) as String?;
      }
      if (token == null || token.isEmpty) {
        return 'Server did not return an authorization token (got: $data)';
      }
      emit(state.copyWith(discountAuthToken: token));
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final serverMsg = body is Map ? body['message'] ?? body['error'] : body;
      return 'HTTP $status: ${serverMsg ?? e.message ?? 'request failed'}';
    } catch (e) {
      return e.toString();
    }
  }

  // ---------- submit ----------

  Future<void> submit() async {
    if (state.items.isEmpty) return;
    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final payload = <String, dynamic>{
        'client_name': state.clientName,
        'client_id': state.clientId,
        'date':
            '${state.date.year.toString().padLeft(4, '0')}-${state.date.month.toString().padLeft(2, '0')}-${state.date.day.toString().padLeft(2, '0')}',
        'notes': state.notes,
        if (state.hasHighDiscount && state.discountAuthToken != null)
          'discount_auth_token': state.discountAuthToken,
        'items': state.items.map((i) => i.toJson()).toList(),
      };

      final dynamic data = editingInvoiceId == null
          ? await _service.createInvoice(payload)
          : await _service.updateInvoice(editingInvoiceId!, payload);

      String? extractId(dynamic d) {
        if (d is! Map) return null;
        if (d['id'] != null) return d['id'].toString();
        if (d['invoice_id'] != null) return d['invoice_id'].toString();
        if (d['data'] is Map) return extractId(d['data']);
        return null;
      }

      final id = extractId(data) ?? editingInvoiceId ?? '';
      // Keep the items/header in state so the view can build a receipt PDF
      // from them — the view is responsible for calling resetForm() afterwards.
      emit(state.copyWith(submitting: false, createdInvoiceId: id));
    } on DioException catch (e) {
      emit(state.copyWith(
        submitting: false,
        submitError: e.response?.data?.toString() ?? e.message ?? 'error',
      ));
    } catch (e) {
      emit(state.copyWith(submitting: false, submitError: e.toString()));
    }
  }

  void acknowledgeCreated() {
    emit(state.copyWith(clearCreatedInvoiceId: true));
  }

  void resetForm() {
    emit(InvoiceFormState.initial());
  }
}
