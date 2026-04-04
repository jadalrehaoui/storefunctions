import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';
import '../view/cierre_sitsa_screen.dart';

class CierreSitsaData {
  final List<Map<String, dynamic>> invoices;
  final Map<String, dynamic> general;
  final double inventoryCost;

  const CierreSitsaData({
    required this.invoices,
    required this.general,
    required this.inventoryCost,
  });
}

sealed class CierreSitsaState {}

class CierreSitsaInitial extends CierreSitsaState {}

class CierreSitsaLoading extends CierreSitsaState {}

class CierreSitsaLoaded extends CierreSitsaState {
  final CierreSitsaData data;
  CierreSitsaLoaded(this.data);
}

class CierreSitsaFailure extends CierreSitsaState {
  final String error;
  CierreSitsaFailure(this.error);
}

class CierreSitsaCubit extends Cubit<CierreSitsaState> {
  final ApiClient _api;
  static final _fmt = DateFormat('yyyy-MM-dd');

  CierreSitsaCubit(this._api) : super(CierreSitsaInitial());

  Future<void> load(DateTime date) async {
    emit(CierreSitsaLoading());
    try {
      final data = await _api.post('/api/sitsa/get-daily-report', {
        'date': _fmt.format(date),
      });

      print('[CierreSitsa] raw response: $data');

      final invoices = (data['invoices'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final general = Map<String, dynamic>.from(data['general'] as Map);
      print('[CierreSitsa] general: $general');
      final inventoryCost =
          (data['inventory_cost']['Total_Costo_Inventario'] as num).toDouble();

      emit(CierreSitsaLoaded(CierreSitsaData(
        invoices: invoices,
        general: general,
        inventoryCost: inventoryCost,
      )));
    } catch (e) {
      emit(CierreSitsaFailure(e.toString()));
    }
  }

  Future<String> download(
    CierreSitsaData data,
    DateTime date,
    List<DepositEntry> deposits,
    List<CardChargeEntry> cards,
    String prevInventory, {
    bool showCosts = true,
  }) async {
    // Columns: A=Label | B=₡ | C=Value | D=gap | E=Label | F=₡ | G=Value
    final numFmt = NumberFormat('#,##0', 'en_US');
    final pctFmt = NumberFormat('0.00');
    final dateFmt = DateFormat('d/M/yyyy');

    final brutTotal = (data.general['BrutTotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (data.general['TotalDiscount'] as num?)?.toDouble() ?? 0.0;
    final bonos = (data.general['TotalBonos'] as num?)?.toDouble() ?? 0.0;
    final ventaNeta = brutTotal - discount - bonos;
    final pctDesc = brutTotal > 0 ? (discount + bonos) / brutTotal * 100 : 0.0;

    String n(double v) => numFmt.format(v.round());
    String dash(double v) => v == 0 ? '-' : n(v);

    // A, B, C, D, E, F, G
    final rows = [
      ['INVERSIONES HAMBURGO PLAZA', '', '', '', '', '', ''],
      ['', '', '', '', '', '', ''],
      ['', '', '', '', 'FECHA  ${dateFmt.format(date)}', '', ''],
      ['', '', '', '', '', '', ''],
      ['VENTA BRUTA',       '₡', n(brutTotal),          '', 'TTL INVEN. ANTER.',  '₡', showCosts ? (prevInventory.isEmpty ? '' : n((double.tryParse(prevInventory.replaceAll(',', '')) ?? 0))) : ''],
      ['DESCUENTO',         '₡', n(discount.round().toDouble()), '', 'DIF. A DEPOSITAR',   '₡', '-'],
      ['OTROS DESCUENTO',   '₡', n(bonos.round().toDouble()),    '', '% DESC',             '',  pctFmt.format(pctDesc)],
      ['VENTA NETA',        '₡', n(ventaNeta),          '', '',                   '',  ''],
      ['TOTAL INVENTARIO',  '₡', showCosts ? n(data.inventoryCost) : '', '', '',                   '',  ''],
      ['', '', '', '', '', '', ''],
      ['', '', '', '', '', '', ''],
      ['RANGO INICIO', 'RANGO FIN', 'TOTAL', '', '', '', ''],
      ...data.invoices.map((inv) => [
            '${inv['RangeStart']}', '${inv['RangeEnd']}',
            '${inv['Total']}', '', '', '', '',
          ]),
    ];

    // Deposits section
    if (deposits.isNotEmpty) {
      rows.add(['', '', '', '', '', '', '']);
      rows.add(['DEPÓSITOS BANCARIOS', '', '', '', '', '', '']);
      rows.add(['No. Depósito', 'Banco', 'Moneda', 'T/C', 'Monto', '', '']);
      for (final d in deposits) {
        rows.add([
          d.depositNo.text,
          d.bankName,
          d.currency,
          d.currency == 'USD' ? d.exchangeRate.text : '-',
          d.amount.text,
          '',
          '',
        ]);
      }
    }

    // Card charges section
    if (cards.isNotEmpty) {
      rows.add(['', '', '', '', '', '', '']);
      rows.add(['COBROS CON TARJETA', '', '', '', '', '', '']);
      rows.add(['Banco', 'Monto', '', '', '', '', '']);
      for (final c in cards) {
        rows.add([c.bankName, c.amount.text, '', '', '', '', '']);
      }
    }

    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }

    final dir = Platform.isMacOS
        ? '/Users/${Platform.environment['USER']}/Downloads'
        : '${Platform.environment['USERPROFILE']}\\Downloads';
    await Directory(dir).create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '$dir${Platform.pathSeparator}cierre_sitsa_$timestamp.csv';
    await File(path).writeAsString(buffer.toString());
    return path;
  }

  /// Returns the closure id (create → POST, update → PUT).
  Future<String> saveOrUpdate(
    Map<String, dynamic> payload, {
    String? closureId,
  }) async {
    if (closureId != null) {
      final result = await _api.put('/api/workdb/closures/$closureId', payload);
      print('[CierreSitsa] update response: $result');
      return closureId;
    } else {
      try {
        final result = await _api.post('/api/workdb/closures', payload);
        print('[CierreSitsa] save response: $result');
        return result['data']['id'].toString();
      } catch (e) {
        // 409 = closure for this date already exists → find it and update
        if (e is DioException && e.response?.statusCode == 409) {
          final date = payload['date'] as String;
          final list = await _api.get('/api/workdb/closures');
          final all = (list['data'] as List).cast<Map<String, dynamic>>();
          final existing = all.firstWhere(
            (c) => (c['date'] as String).startsWith(date),
          );
          final existingId = existing['id'].toString();
          final result = await _api.put('/api/workdb/closures/$existingId', payload);
          print('[CierreSitsa] upsert update response: $result');
          return existingId;
        }
        rethrow;
      }
    }
  }

  String _escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
