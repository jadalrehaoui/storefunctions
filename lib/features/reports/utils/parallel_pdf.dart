import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../cubit/cierre_parallel_cubit.dart';

Future<String> generateAndOpenParallel(
    ParallelDailySummary summary, DateTime date) async {
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
            pw.Text('Cierre Parallel', style: style(b: true, size: 20)),
            pw.Text(dateFmt.format(date), style: style(b: true, size: 12)),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),

        // Total tile
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
              pw.Text(colones.format(summary.totalNet),
                  style: style(b: true, size: 11)),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // Counts row
        pw.Row(
          children: [
            pw.Text('Facturas activas: ${summary.invoices.length}   ',
                style: style(size: 9, color: PdfColors.grey700)),
            pw.Text('Anuladas: ${summary.voidedInvoices.length}   ',
                style: style(size: 9, color: PdfColors.red700)),
            pw.Text('Bruto: ${colones.format(summary.totalGross)}   ',
                style: style(size: 9, color: PdfColors.grey700)),
            pw.Text('Descuento: ${colones.format(summary.totalDiscount)}',
                style: style(size: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 14),

        // Active invoices
        pw.Text('Facturas',
            style: style(b: true, size: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        table(
          ['Factura', 'Cliente', 'Creada por', 'Subtotal', 'Descuento', 'Total'],
          summary.invoices
              .map((inv) => [
                    '#${inv.id}',
                    inv.clientName ?? '',
                    inv.createdBy ?? '',
                    colones.format(inv.subtotal),
                    colones.format(inv.discount),
                    colones.format(inv.total),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 14),

        // Items sold
        pw.Text('Artículos Vendidos',
            style: style(b: true, size: 11, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        table(
          ['Código', 'Descripción', 'Cant.', 'Bruto', 'Descuento', 'Neto'],
          summary.itemsSold
              .map((i) => [
                    i.sitsaCode,
                    i.description,
                    i.quantity.toStringAsFixed(0),
                    colones.format(i.gross),
                    colones.format(i.discount),
                    colones.format(i.net),
                  ])
              .toList(),
        ),

        if (summary.voidedInvoices.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('Facturas Anuladas',
              style: style(b: true, size: 11, color: PdfColors.red700)),
          pw.SizedBox(height: 6),
          table(
            ['Factura', 'Cliente', 'Creada por', 'Total'],
            summary.voidedInvoices
                .map((inv) => [
                      '#${inv.id}',
                      inv.clientName ?? '',
                      inv.createdBy ?? '',
                      colones.format(inv.total),
                    ])
                .toList(),
          ),
        ],
      ],
    ),
  );

  if (Platform.isWindows) {
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'cierre_parallel_${DateFormat('yyyyMMdd').format(date)}',
    );
    return 'printed';
  }

  final dir = '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final path = '$dir/cierre_parallel_$timestamp.pdf';
  await File(path).writeAsBytes(await pdf.save());
  await Process.run('open', [path]);
  return path;
}
