import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/bodega_lista_item.dart';

/// Builds an 80mm wide receipt PDF for a bodega list filtered to one creator.
/// [creator] is the username the list is filtered to.
Future<Uint8List> buildBodegaListaReceiptPdf({
  required List<BodegaListaItem> items,
  required String creator,
  required DateTime now,
}) async {
  final pdf = pw.Document();
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle s({bool b = false, double size = 8}) => pw.TextStyle(
        font: b ? bold : regular,
        fontSize: size,
      );

  final totalUnits = items.fold<int>(0, (n, i) => n + i.qty);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        74 * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 8 * PdfPageFormat.mm,
        marginTop: 6 * PdfPageFormat.mm,
        marginBottom: 6 * PdfPageFormat.mm,
      ),
      build: (ctx) => [
        pw.Center(child: pw.Text('LISTA BODEGA', style: s(b: true, size: 14))),
        pw.SizedBox(height: 4),
        pw.Text(dateFmt.format(now), style: s()),
        pw.Text('Creador: $creator', style: s(b: true)),
        pw.Divider(thickness: 0.5),
        for (final i in items) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(i.sitsaCode, style: s(b: true, size: 11)),
                    pw.Text(i.descripcion, style: s()),
                    if (i.modelo != null && i.modelo!.isNotEmpty)
                      pw.Text(i.modelo!, style: s(b: true, size: 8)),
                  ],
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text('${i.qty}', style: s(b: true, size: 16)),
            ],
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total líneas', style: s()),
            pw.Text('${items.length}', style: s(b: true)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total unidades', style: s()),
            pw.Text('$totalUnits', style: s(b: true)),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

Future<String> openBodegaListaPdf(Uint8List bytes) async {
  final dir = Platform.isWindows
      ? '${Platform.environment['USERPROFILE']}\\Downloads'
      : '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sep = Platform.isWindows ? '\\' : '/';
  final path = '$dir${sep}bodega_lista_$ts.pdf';
  await File(path).writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else {
    await Process.run('open', [path]);
  }
  return path;
}
