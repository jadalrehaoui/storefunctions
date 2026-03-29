import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<String> generateAndOpenMikail(
    Map<String, dynamic> data, DateTime date) async {
  final pdf = pw.Document();

  final colones = NumberFormat.currency(symbol: 'CRC ', decimalDigits: 0);
  final dateFmt = DateFormat('MMM d, yyyy');
  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle style({bool b = false, double size = 10, PdfColor? color}) =>
      pw.TextStyle(
        font: b ? bold : regular,
        fontSize: size,
        color: color ?? PdfColors.black,
      );

  final total = (data['total'] as num?)?.toDouble() ?? 0.0;
  final invoices = ((data['invoices'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final detail = ((data['detail'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  pw.Widget table(List<String> headers, List<List<String>> rows) {
    pw.Widget cell(String text, {bool header = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(text,
              style: style(
                  b: header,
                  size: 8,
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
            pw.Text('Cierre Mikail', style: style(b: true, size: 20)),
            pw.Text(dateFmt.format(date), style: style(b: true, size: 12)),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),

        // Total
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total del Día',
                  style: style(b: true, size: 11, color: PdfColors.grey700)),
              pw.Text(colones.format(total),
                  style: style(b: true, size: 11)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Invoices
        pw.Text('Facturas',
            style: style(b: true, size: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        table(
          ['Factura', 'Fecha', 'Cliente', 'Monto'],
          invoices.map((inv) {
            String fmtDate(dynamic v) {
              try {
                return DateFormat('dd/MM/yyyy').format(DateTime.parse('$v'));
              } catch (_) {
                return '$v';
              }
            }

            return [
              '${inv['Factura'] ?? '—'}',
              fmtDate(inv['Fecha']),
              (inv['Cliente01'] as String? ?? '—').trim(),
              colones.format((inv['Monto'] as num?)?.toDouble() ?? 0),
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 14),

        // Detail
        pw.Text('Detalle',
            style: style(b: true, size: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        table(
          ['Factura', 'Artículo', 'Descripción', 'Modelo', 'Cant.'],
          detail.map((d) => [
                '${d['Factura'] ?? '—'}',
                (d['Articulo'] as String? ?? '—').trim(),
                (d['Descripcion'] as String? ?? '—').trim(),
                (d['Modelo'] as String? ?? '—').trim(),
                '${d['Cantidad'] ?? '—'}',
              ]).toList(),
        ),
      ],
    ),
  );

  if (Platform.isWindows) {
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'cierre_mikail_${DateFormat('yyyyMMdd').format(date)}',
    );
    return 'printed';
  }

  final dir = '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final path = '$dir/cierre_mikail_$timestamp.pdf';
  await File(path).writeAsBytes(await pdf.save());
  await Process.run('open', [path]);
  return path;
}
