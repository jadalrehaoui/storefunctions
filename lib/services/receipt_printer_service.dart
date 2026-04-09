import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterKind { receipt, report }

/// Persists the user's preferred printers (one for receipts, one for reports)
/// and exposes helpers to list system printers + push raw PDFs to them.
class ReceiptPrinterService {
  static const _receiptKey = 'receipt_printer_url';
  static const _reportKey = 'report_printer_url';

  String _key(PrinterKind kind) =>
      kind == PrinterKind.receipt ? _receiptKey : _reportKey;

  /// All printers known to the OS.
  Future<List<Printer>> listPrinters() => Printing.listPrinters();

  /// Returns the saved printer URL for the given kind, or null.
  Future<String?> getSavedPrinterUrl(PrinterKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(kind));
  }

  /// Resolves the saved selection back to a [Printer] object, or null if it
  /// no longer exists on the system.
  Future<Printer?> getSavedPrinter(PrinterKind kind) async {
    final url = await getSavedPrinterUrl(kind);
    if (url == null) return null;
    final all = await listPrinters();
    for (final p in all) {
      if (p.url == url) return p;
    }
    return null;
  }

  Future<void> savePrinter(PrinterKind kind, Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(kind), printer.url);
  }

  Future<void> clearPrinter(PrinterKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(kind));
  }

  /// Sends [bytes] to the saved printer for [kind]. Returns false if no
  /// printer is configured for that kind.
  Future<bool> printPdf(
    Uint8List bytes, {
    PrinterKind kind = PrinterKind.receipt,
    String name = 'document',
  }) async {
    final printer = await getSavedPrinter(kind);
    if (printer == null) return false;
    return Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => bytes,
      name: name,
    );
  }
}
