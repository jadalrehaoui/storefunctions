import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../reports/view/cierre_sitsa_screen.dart' show CardChargeEntry;

/// Builds an 80mm wide receipt PDF for a personal (per-cashier) cierre.
Future<Uint8List> buildCierrePersonalReceiptPdf({
  required DateTime date,
  required String cashier,
  required String? createdBy,
  required Map<String, dynamic> general,
  required List<CardChargeEntry> cards,
}) async {
  final pdf = pw.Document();
  final colones = NumberFormat.currency(symbol: '', decimalDigits: 0);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final dayFmt = DateFormat('yyyy-MM-dd');

  final bold = pw.Font.helveticaBold();
  final regular = pw.Font.helvetica();

  pw.TextStyle s({bool b = false, double size = 8}) => pw.TextStyle(
        font: b ? bold : regular,
        fontSize: size,
      );

  double n(String k) => (general[k] as num?)?.toDouble() ?? 0.0;
  final brut = n('BrutTotal');
  final bonos = n('TotalBonos');
  final desc = n('TotalDiscount');
  final totalAPagar = n('SUM_TOTAL_A_PAGAR');
  final apartadosCobrados = n('APARTADOS_COBRADOS');
  final apartadosOtro = n('APARTADOS_FACTURADOS_POR_OTRO_USUARIO');
  final voided = (general['TotalVoided'] as num?)?.toInt() ?? 0;
  final cardsTotal = cards.fold<double>(
      0.0,
      (sum, c) =>
          sum + (double.tryParse(c.amount.text.replaceAll(',', '')) ?? 0.0));
  final diferencia =
      totalAPagar - cardsTotal + apartadosCobrados - apartadosOtro;

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
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(child: pw.Text('CIERRE PERSONAL', style: s(b: true, size: 13))),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text(dayFmt.format(date), style: s(b: true, size: 11))),
          pw.SizedBox(height: 6),
          pw.Text('Impreso: ${dateFmt.format(DateTime.now())}', style: s(size: 7)),
          pw.Text('Cajero: $cashier', style: s()),
          if (createdBy != null && createdBy.isNotEmpty)
            pw.Text('Generado por: $createdBy', style: s()),
          pw.Divider(thickness: 0.5),
          _kv('Venta Bruta', colones.format(brut), s),
          _kv('Bonos', colones.format(bonos), s),
          _kv('Descuentos', colones.format(desc), s),
          _kv('Facturas Anuladas', '$voided', s),
          pw.SizedBox(height: 2),
          _kv('Total a Pagar', colones.format(totalAPagar), s, bold: true, size: 10),
          pw.Divider(thickness: 0.5),
          pw.Text('Cobros con Tarjeta', style: s(b: true)),
          if (cards.isEmpty)
            pw.Text('  (sin cobros)', style: s(size: 7))
          else
            for (final c in cards)
              _kv(
                '  ${c.bankName}',
                colones.format(
                    double.tryParse(c.amount.text.replaceAll(',', '')) ?? 0.0),
                s,
              ),
          pw.SizedBox(height: 2),
          _kv('Total Tarjetas', colones.format(cardsTotal), s, bold: true),
          pw.Divider(thickness: 0.5),
          _kv('Apartados Cobrados', colones.format(apartadosCobrados), s),
          _kv('Apartados Fact. Otro', colones.format(apartadosOtro), s),
          pw.Divider(thickness: 0.5),
          _kv('Diferencia a Depositar', colones.format(diferencia), s,
              bold: true, size: 11),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5),
          _blankLine('Faltante', s),
          pw.SizedBox(height: 6),
          _blankLine('Sobrante', s),
          pw.SizedBox(height: 14),
          _blankLine('Firma', s, lineWidth: 160),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('— Fin del cierre —', style: s(size: 7))),
        ],
      ),
    ),
  );

  return pdf.save();
}

pw.Widget _kv(
    String k, String v, pw.TextStyle Function({bool b, double size}) s,
    {bool bold = false, double size = 8}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: s(b: bold, size: size)),
      pw.Text(v, style: s(b: bold, size: size)),
    ],
  );
}

pw.Widget _blankLine(
    String label, pw.TextStyle Function({bool b, double size}) s,
    {double lineWidth = 110}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text('$label:', style: s(b: true)),
      pw.SizedBox(width: 4),
      pw.Container(
        width: lineWidth,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 0.6),
          ),
        ),
        height: 12,
      ),
    ],
  );
}

Future<String> openCierrePersonalReceiptPdf(
    Uint8List bytes, String tag) async {
  final dir = Platform.isWindows
      ? '${Platform.environment['USERPROFILE']}\\Downloads'
      : '/Users/${Platform.environment['USER']}/Downloads';
  await Directory(dir).create(recursive: true);
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final sep = Platform.isWindows ? '\\' : '/';
  final path = '$dir${sep}cierre_personal_${tag}_$timestamp.pdf';
  await File(path).writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else {
    await Process.run('open', [path]);
  }
  return path;
}
