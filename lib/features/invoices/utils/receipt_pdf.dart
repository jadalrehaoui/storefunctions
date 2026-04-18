import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/invoice_models.dart';

/// Builds an 80mm wide receipt PDF for the given invoice data.
/// When [voided] is true a diagonal "NULA" watermark is overlaid.
Future<Uint8List> buildReceiptPdf({
  required String invoiceId,
  required DateTime date,
  required String clientName,
  required String clientId,
  required String notes,
  required List<InvoiceLineItem> items,
  required String? createdBy,
  bool voided = false,
}) async {
  final pdf = pw.Document();
  final colones = NumberFormat.currency(symbol: '', decimalDigits: 0);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle s({bool b = false, double size = 8}) => pw.TextStyle(
        font: b ? bold : regular,
        fontSize: size,
      );

  final subtotal =
      items.fold<double>(0, (sum, i) => sum + (i.unitPrice * i.quantity));
  final discount = items.fold<double>(
      0, (sum, i) => sum + (i.unitPrice * i.quantity * (i.discountPct / 100)));
  final total = subtotal - discount;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        74 * PdfPageFormat.mm,
        double.infinity,
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 8 * PdfPageFormat.mm,
        marginTop: 6 * PdfPageFormat.mm,
        marginBottom: 6 * PdfPageFormat.mm,
      ),
      build: (ctx) {
        final content = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
                voided ? 'TIQUETE — NULA' : 'TIQUETE',
                style: s(b: true, size: 14)),
          ),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text('#$invoiceId', style: s(b: true, size: 12))),
          pw.SizedBox(height: 6),
          pw.Text(dateFmt.format(date), style: s()),
          if (createdBy != null && createdBy.isNotEmpty)
            pw.Text('Cajero: $createdBy', style: s()),
          pw.Divider(thickness: 0.5),
          if (clientName.isNotEmpty) pw.Text('Cliente: $clientName', style: s()),
          if (clientId.isNotEmpty) pw.Text('Cédula: $clientId', style: s()),
          if (clientName.isNotEmpty || clientId.isNotEmpty)
            pw.SizedBox(height: 4),

          // Items
          for (final i in items) ...[
            pw.Text(i.description, style: s(b: true)),
            pw.Text('Cód: ${i.sitsaCode}', style: s(size: 7)),
            if (i.barcode != null && i.barcode!.isNotEmpty)
              pw.Text('CB: ${i.barcode}', style: s(size: 7)),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${i.quantity.toStringAsFixed(0)} x ${colones.format(i.unitPrice)}'
                  '${i.discountPct > 0 ? '  -${i.discountPct.toStringAsFixed(0)}%' : ''}',
                  style: s(size: 7),
                ),
                pw.Text(colones.format(i.lineTotal), style: s()),
              ],
            ),
            pw.SizedBox(height: 3),
          ],

          pw.Divider(thickness: 0.5),
          _kv('Subtotal', colones.format(subtotal), s),
          if (discount > 0) _kv('Descuento', '-${colones.format(discount)}', s),
          pw.SizedBox(height: 2),
          _kv('TOTAL', colones.format(total), s, bold: true, size: 11),

          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(notes, style: s(size: 7)),
          ],
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('Tiquete de entrega', style: s(b: true))),
        ],
        );

        if (!voided) return content;

        return pw.Stack(
          children: [
            content,
            pw.Positioned.fill(
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: -math.pi / 4,
                  child: pw.Text(
                    'NULA',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 38,
                      color: PdfColor.fromInt(0x44FF0000),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _kv(String k, String v, pw.TextStyle Function({bool b, double size}) s,
    {bool bold = false, double size = 8}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: s(b: bold, size: size)),
      pw.Text(v, style: s(b: bold, size: size)),
    ],
  );
}

/// Writes the PDF to ~/Downloads (macOS/Linux) and opens it. Used as the
/// fallback when no receipt printer is configured.
Future<String> openReceiptPdf(Uint8List bytes, String invoiceId) async {
  final dir = Platform.isWindows
      ? '${Platform.environment['USERPROFILE']}\\Downloads'
      : '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sep = Platform.isWindows ? '\\' : '/';
  final path = '$dir${sep}receipt_${invoiceId}_$timestamp.pdf';
  await File(path).writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else {
    await Process.run('open', [path]);
  }
  return path;
}
