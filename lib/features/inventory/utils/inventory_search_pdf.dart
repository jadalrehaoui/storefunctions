import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<String> generateAndOpenInventorySearch({
  required String query,
  required List<dynamic> items,
  required bool showProfit,
}) async {
  final pdf = pw.Document();
  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();
  final fobFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final costFmt = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

  pw.TextStyle style({bool b = false, double size = 7, PdfColor? color}) =>
      pw.TextStyle(
          font: b ? bold : regular,
          fontSize: size,
          color: color ?? PdfColors.black);

  pw.Widget cell(String text,
          {bool header = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(text,
            style: style(
                b: header,
                color: header ? PdfColors.grey700 : PdfColors.black),
            textAlign: align),
      );

  final cols = <String>[
    'Código',
    'Barras',
    'Descripción',
    'Modelo',
    if (showProfit) 'FOB',
    if (showProfit) 'Costo',
    if (showProfit) 'G%',
    'Precio',
    'Disp.',
    'Res.',
  ];

  final widths = <pw.TableColumnWidth>[
    const pw.FlexColumnWidth(1.4),
    const pw.FlexColumnWidth(1.6),
    const pw.FlexColumnWidth(4),
    const pw.FlexColumnWidth(1.6),
    if (showProfit) const pw.FlexColumnWidth(1),
    if (showProfit) const pw.FlexColumnWidth(1.2),
    if (showProfit) const pw.FlexColumnWidth(0.6),
    const pw.FlexColumnWidth(1.2),
    const pw.FlexColumnWidth(0.7),
    const pw.FlexColumnWidth(0.7),
  ];

  pw.TableRow buildRow(Map<String, dynamic> m, bool odd) {
    final costo = (m['Costo'] as num?)?.toDouble() ?? 0;
    final utilidad = ((m['UTILIDAD'] ?? m['Ganancia']) as num?)?.toDouble() ?? 0;
    final precioValue = (m['Precio'] as num?)?.toDouble() ??
        costo + costo * utilidad / 100;
    final precio = costFmt.format(precioValue);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
          color: odd ? PdfColors.grey50 : PdfColors.white),
      children: [
        cell('${m['PK_FK_Articulo'] ?? ''}'),
        cell('${m['Codigo_Barras'] ?? ''}'),
        cell('${m['Articulo_Descripcion'] ?? ''}'),
        cell('${m['MODELO'] ?? ''}'),
        if (showProfit) cell(fobFmt.format(m['FOB'] ?? 0), align: pw.TextAlign.right),
        if (showProfit) cell(costFmt.format(costo), align: pw.TextAlign.right),
        if (showProfit) cell('${utilidad.toStringAsFixed(0)}%', align: pw.TextAlign.right),
        cell(precio, align: pw.TextAlign.right),
        cell('${m['Cantidad_Disponible'] ?? 0}', align: pw.TextAlign.right),
        cell('${m['Cantidad_Reservada'] ?? 0}', align: pw.TextAlign.right),
      ],
    );
  }

  final now = DateTime.now();
  final dateFmt = DateFormat('MMM d, yyyy HH:mm');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Búsqueda de Inventario',
                style: style(b: true, size: 16)),
            pw.Text(dateFmt.format(now), style: style(b: true, size: 11)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Query: $query  •  ${items.length} items',
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
            ...items.asMap().entries.map(
                (e) => buildRow(e.value as Map<String, dynamic>, e.key.isOdd)),
          ],
        ),
      ],
    ),
  );

  if (Platform.isWindows) {
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'inventory_search_${DateFormat('yyyyMMdd_HHmmss').format(now)}',
    );
    return 'printed';
  }

  final dir = '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
  final path = '$dir/inventory_search_$ts.pdf';
  await File(path).writeAsBytes(await pdf.save());
  await Process.run('open', [path]);
  return path;
}
