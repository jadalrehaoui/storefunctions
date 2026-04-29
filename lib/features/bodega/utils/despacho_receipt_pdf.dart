import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../cubit/despacho_cubit.dart' show DespachoChannel;
import '../model/ferreteria_invoice.dart';

/// Builds an 80mm-wide receipt PDF for a despacho invoice — used to
/// auto-print on the despacho machine when a new invoice arrives.
Future<Uint8List> buildDespachoReceiptPdf({
  required FerreteriaInvoice invoice,
  required DateTime now,
  String title = 'DESPACHO',
}) async {
  final pdf = pw.Document();
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle s({bool b = false, double size = 9}) =>
      pw.TextStyle(font: b ? bold : regular, fontSize: size);

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
        pw.Center(
          child: pw.Text(title, style: s(b: true, size: 14)),
        ),
        pw.SizedBox(height: 4),
        pw.Text(dateFmt.format(now), style: s()),
        pw.SizedBox(height: 6),
        if (invoice.cliente != null)
          pw.Text(invoice.cliente!, style: s(b: true, size: 11)),
        if (invoice.clienteCodigo != null)
          pw.Text('Código: ${invoice.clienteCodigo}', style: s()),
        pw.Divider(thickness: 0.5),
        for (final i in invoice.items) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 32,
                child: pw.Text(
                  '${_qty.format(i.qty)}x',
                  style: s(b: true, size: 12),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(i.codigo, style: s(b: true, size: 10)),
                    if (i.detalle.isNotEmpty)
                      pw.Text(i.detalle, style: s(size: 8)),
                    if (i.existencia != null)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Existencia: ', style: s(size: 8)),
                          pw.Text(
                            _qty.format(i.existencia!),
                            style: s(b: true, size: 8),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total líneas', style: s()),
            pw.Text('${invoice.items.length}', style: s(b: true)),
          ],
        ),
      ],
    ),
  );

  return pdf.save();
}

final _qty = NumberFormat.decimalPattern('es_CR');

/// Writes [bytes] to the user's Downloads folder and opens it with the OS
/// default viewer. Returns the file path. Used as a fallback preview when
/// no receipt printer is configured.
Future<String> openDespachoPdf(
  Uint8List bytes, {
  DespachoChannel channel = DespachoChannel.bodega,
}) async {
  final dir = Platform.isWindows
      ? '${Platform.environment['USERPROFILE']}\\Downloads'
      : '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sep = Platform.isWindows ? '\\' : '/';
  final prefix =
      channel == DespachoChannel.tec ? 'despacho_tec' : 'despacho_bodega';
  final path = '$dir$sep${prefix}_$ts.pdf';
  await File(path).writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else {
    await Process.run('open', [path]);
  }
  return path;
}
