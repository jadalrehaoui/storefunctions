import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<String> generateAndOpenClosure(Map<String, dynamic> closure, {bool showCosts = true}) async {
  final pdf = pw.Document();

  final colones = NumberFormat.currency(symbol: 'CRC ', decimalDigits: 2);
  final pctFmt = NumberFormat('0.00');
  final dateFmt = DateFormat('MMM d, yyyy');

  double n(dynamic v) => num.tryParse('$v')?.toDouble() ?? 0.0;
  String c(dynamic v) => colones.format(n(v));

  final dateRaw = closure['date'] as String?;
  final date = dateRaw != null ? dateFmt.format(DateTime.parse(dateRaw)) : '—';
  final createdBy = closure['created_by'] as String? ?? '—';

  final general = Map<String, dynamic>.from(closure['general'] as Map? ?? {});
  final calc = Map<String, dynamic>.from(closure['calculations'] as Map? ?? {});
  final invoices = ((closure['invoices'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final deposits = ((closure['deposits'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final cards = ((closure['card_charges'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final prevInv = num.tryParse('${closure['prev_inventory_cost'] ?? ''}')?.toDouble();
  final invCost = num.tryParse('${closure['inventory_cost'] ?? ''}')?.toDouble();
  final rawTc = closure['bccrtc'];
  final tcVenta = rawTc is num
      ? rawTc.toDouble()
      : double.tryParse(rawTc?.toString() ?? '');
  final usdFmt = NumberFormat.currency(symbol: '\$ ', decimalDigits: 2);

  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle style({bool b = false, double size = 10, PdfColor? color}) =>
      pw.TextStyle(
        font: b ? bold : regular,
        fontSize: size,
        color: color ?? PdfColors.black,
      );

  pw.Widget sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t, style: style(b: true, size: 11, color: PdfColors.grey700)),
      );

  pw.Widget sectionTitleWithTotal(String t, String total) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(t, style: style(b: true, size: 11, color: PdfColors.grey700)),
            pw.Text(total, style: style(b: true, size: 11, color: PdfColors.grey700)),
          ],
        ),
      );

  pw.Widget kv(String label, String value, {bool highlight = false}) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: pw.BoxDecoration(
          color: highlight ? PdfColors.blue50 : PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style(size: 9, color: PdfColors.grey600)),
            pw.Text(value, style: style(b: true, size: 9)),
          ],
        ),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) {
    pw.Widget cell(String text, {bool header = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(text,
              style: style(b: header, size: 8,
                  color: header ? PdfColors.grey700 : PdfColors.black)),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => cell(h, header: true)).toList(),
        ),
        ...rows.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: e.key.isOdd ? PdfColors.grey50 : PdfColors.white),
              children: e.value.map((v) => cell(v)).toList(),
            )),
      ],
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Cierre Diario', style: style(b: true, size: 20)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(date, style: style(b: true, size: 12)),
                pw.SizedBox(height: 2),
                pw.Text('Por: $createdBy',
                    style: style(size: 10, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),

        // General
        sectionTitle('General'),
        pw.Wrap(spacing: 8, runSpacing: 0, children: [
          if (general['BrutTotal'] != null)
            pw.SizedBox(width: 250, child: kv('Venta Bruta', c(general['BrutTotal']))),
          if (general['TotalBonos'] != null)
            pw.SizedBox(width: 250, child: kv('Bonos', c(general['TotalBonos']))),
          if (general['TotalDiscount'] != null)
            pw.SizedBox(width: 250, child: kv('Descuentos', c(general['TotalDiscount']))),
          if (general['Venta_Licor'] != null)
            pw.SizedBox(width: 250, child: kv('Venta Licor', c(general['Venta_Licor']))),
          if (general['TotalVoided'] != null)
            pw.SizedBox(width: 250, child: kv('Facturas Anuladas', '${(general['TotalVoided'] as num).toInt()}')),
          if (invCost != null && showCosts)
            pw.SizedBox(width: 250, child: kv('Inventario Actual', colones.format(invCost))),
          if (prevInv != null && showCosts)
            pw.SizedBox(width: 250, child: kv('Inventario Anterior', colones.format(prevInv))),
          if (invCost != null && tcVenta != null && tcVenta > 0 && showCosts)
            pw.SizedBox(width: 250, child: kv('Inventario Actual (\$)', usdFmt.format(invCost / tcVenta), highlight: true)),
          if (tcVenta != null)
            pw.SizedBox(width: 250, child: kv('T/C Venta USD', 'CRC ${tcVenta.toStringAsFixed(2)}')),
        ]),

        // Calculations
        sectionTitle('Calculos'),
        pw.Wrap(spacing: 8, runSpacing: 0, children: [
          if (calc['ventaNeta'] != null)
            pw.SizedBox(width: 250, child: kv('Venta Neta', c(calc['ventaNeta']), highlight: true)),
          if (calc['discountPct'] != null)
            pw.SizedBox(width: 250, child: kv('% Descuento', '${pctFmt.format(n(calc['discountPct']))}%')),
          if (calc['diferenciaADepositar'] != null)
            pw.SizedBox(width: 250, child: kv('Dif. a Depositar', c(calc['diferenciaADepositar']), highlight: true)),
        ]),

        // Deposits
        if (deposits.isNotEmpty) ...[
          sectionTitleWithTotal(
            'Depositos Bancarios',
            colones.format(deposits.fold(0.0, (s, d) => s + n(d['amount']))),
          ),
          table(
            ['No. Deposito', 'Banco', 'Moneda', 'T/C', 'Monto', 'Colones'],
            deposits.map((d) {
              final amount = n(d['amount']);
              final rate = n(d['exchangeRate']);
              final currency = d['currency'] as String? ?? 'CRC';
              final colonesVal = currency == 'USD' && rate > 0
                  ? colones.format(amount * rate)
                  : colones.format(amount);
              return [
                '${d['depositNo'] ?? '—'}',
                '${d['bank'] ?? '—'}',
                currency,
                rate > 0 ? '${d['exchangeRate']}' : '—',
                amount > 0
                    ? (currency == 'USD' ? usdFmt.format(amount) : c(d['amount']))
                    : '—',
                colonesVal,
              ];
            }).toList(),
          ),
        ],

        // Card charges
        if (cards.isNotEmpty) ...[
          sectionTitleWithTotal(
            'Cobros con Tarjeta',
            colones.format(cards.fold(0.0, (s, cd) => s + n(cd['amount']))),
          ),
          table(
            ['Banco', 'Monto'],
            cards.map((cd) => [
              '${cd['bank'] ?? '—'}',
              cd['amount'] != null ? c(cd['amount']) : '—',
            ]).toList(),
          ),
        ],

        // Invoices
        if (invoices.isNotEmpty) ...[
          sectionTitle('Rangos de Facturas'),
          table(
            ['Rango Inicio', 'Rango Fin', 'Total'],
            invoices.map((inv) => [
              '${inv['RangeStart'] ?? '—'}',
              '${inv['RangeEnd'] ?? '—'}',
              '${inv['Total'] ?? '—'}',
            ]).toList(),
          ),
        ],
      ],
    ),
  );

  if (Platform.isWindows) {
    // Use native print dialog on Windows
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'cierre_$date',
    );
    return 'printed';
  }

  // macOS: save to Downloads and open with Preview
  final dir = '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final path = '$dir/cierre_$timestamp.pdf';
  await File(path).writeAsBytes(await pdf.save());
  await Process.run('open', [path]);
  return path;
}
