import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<String> generateAndOpenRestock(
    List<Map<String, dynamic>> items, DateTime date) async {
  final pdf = pw.Document();
  final dateFmt = DateFormat('MMM d, yyyy');
  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle style({bool b = false, double size = 9, PdfColor? color}) =>
      pw.TextStyle(
          font: b ? bold : regular,
          fontSize: size,
          color: color ?? PdfColors.black);

  pw.Widget cell(String text, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(text,
            style: style(
                b: header,
                size: 7,
                color: header ? PdfColors.grey700 : PdfColors.black),
            textAlign: align),
      );

  const cols = ['Código', 'Modelo', 'Clasificación', 'Descripción', 'Disp.', 'Reserv.'];
  const widths = [
    pw.FlexColumnWidth(1.5),
    pw.FlexColumnWidth(1.5),
    pw.FlexColumnWidth(1.5),
    pw.FlexColumnWidth(4),
    pw.FlexColumnWidth(0.8),
    pw.FlexColumnWidth(0.8),
  ];

  pw.TableRow buildRow(Map<String, dynamic> item, bool odd) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(
            color: odd ? PdfColors.grey50 : PdfColors.white),
        children: [
          cell('${item['PK_Articulo'] ?? ''}'),
          cell((item['MODELO'] as String? ?? '').trim()),
          cell('${item['Clasificacion_Descripcion'] ?? ''}'),
          cell('${item['DETALLE'] ?? ''}'),
          cell('${item['Disponible'] ?? 0}',
              align: pw.TextAlign.right),
          cell('${item['Reservado'] ?? 0}',
              align: pw.TextAlign.right),
        ],
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Restock List', style: style(b: true, size: 16)),
            pw.Text(dateFmt.format(date), style: style(b: true, size: 11)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('${items.length} items',
            style: style(size: 9, color: PdfColors.grey600)),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 6),
        pw.Table(
          columnWidths: {for (var i = 0; i < widths.length; i++) i: widths[i]},
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: cols.map((c) => cell(c, header: true)).toList(),
            ),
            ...items.asMap().entries.map((e) => buildRow(e.value, e.key.isOdd)),
          ],
        ),
      ],
    ),
  );

  if (Platform.isWindows) {
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'restock_${DateFormat('yyyyMMdd').format(date)}',
    );
    return 'printed';
  }

  final dir = '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final path = '$dir/restock_$ts.pdf';
  await File(path).writeAsBytes(await pdf.save());
  await Process.run('open', [path]);
  return path;
}

Future<String> exportRestockCsv(
    List<Map<String, dynamic>> items, DateTime date) async {
  final buf = StringBuffer();

  String esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  buf.writeln(['Código', 'Modelo', 'Clasificación', 'Descripción', 'Disponible', 'Reservado']
      .map(esc)
      .join(','));

  for (final item in items) {
    buf.writeln([
      '${item['PK_Articulo'] ?? ''}',
      (item['MODELO'] as String? ?? '').trim(),
      '${item['Clasificacion_Descripcion'] ?? ''}',
      '${item['DETALLE'] ?? ''}',
      '${item['Disponible'] ?? 0}',
      '${item['Reservado'] ?? 0}',
    ].map(esc).join(','));
  }

  final dir = Platform.isMacOS
      ? '/Users/${Platform.environment['USER']}/Downloads'
      : '${Platform.environment['USERPROFILE']}\\Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final path = '$dir${Platform.pathSeparator}restock_$ts.csv';
  await File(path).writeAsString(buf.toString());

  if (Platform.isMacOS) await Process.run('open', [path]);

  return path;
}
