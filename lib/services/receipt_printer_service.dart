import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preferred receipt printer and exposes helpers to list
/// the system printers + push raw PDFs to the saved one.
class ReceiptPrinterService {
  static const _key = 'receipt_printer_url';

  /// All printers known to the OS.
  Future<List<Printer>> listPrinters() => Printing.listPrinters();

  /// Returns the saved printer URL (the stable identifier returned by
  /// `Printer.url`), or null if none has been chosen yet.
  Future<String?> getSavedPrinterUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Resolves the saved selection back to a [Printer] object, or null if it
  /// no longer exists on the system.
  Future<Printer?> getSavedPrinter() async {
    final url = await getSavedPrinterUrl();
    if (url == null) return null;
    final all = await listPrinters();
    for (final p in all) {
      if (p.url == url) return p;
    }
    return null;
  }

  Future<void> savePrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, printer.url);
  }

  Future<void> clearPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Convenience helper for future receipt-print code.
  Future<bool> printPdf(Uint8List bytes, {String name = 'receipt'}) async {
    final printer = await getSavedPrinter();
    if (printer == null) return false;
    return Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => bytes,
      name: name,
    );
  }
}
