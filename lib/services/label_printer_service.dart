import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

enum LabelPrinterMode { ip, system }

class LabelPrinterConfig {
  final LabelPrinterMode mode;
  final String host;
  final int port;
  final String? systemPrinterUrl;

  const LabelPrinterConfig({
    required this.mode,
    required this.host,
    required this.port,
    required this.systemPrinterUrl,
  });

  static const defaults = LabelPrinterConfig(
    mode: LabelPrinterMode.ip,
    host: '10.10.0.144',
    port: 9100,
    systemPrinterUrl: null,
  );
}

/// Reads the user's label-printer config and sends raw ZPL to it.
/// Two modes:
///   - [LabelPrinterMode.ip]: TCP socket to host:port (Zebra network protocol).
///   - [LabelPrinterMode.system]: raw pass-through to an OS printer.
///     On Windows that's the Print Spooler ("RAW" datatype). On macOS/Linux
///     it's `lp -o raw`.
class LabelPrinterService {
  static const _modeKey = 'label_printer_mode';
  static const _hostKey = 'label_printer_host';
  static const _portKey = 'label_printer_port';
  static const _urlKey = 'label_printer_url';

  Future<LabelPrinterConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_modeKey);
    final mode = modeStr == 'system'
        ? LabelPrinterMode.system
        : LabelPrinterMode.ip;
    return LabelPrinterConfig(
      mode: mode,
      host: prefs.getString(_hostKey) ?? LabelPrinterConfig.defaults.host,
      port: prefs.getInt(_portKey) ?? LabelPrinterConfig.defaults.port,
      systemPrinterUrl: prefs.getString(_urlKey),
    );
  }

  Future<void> saveIp({required String host, required int port}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, 'ip');
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
  }

  Future<void> saveSystemPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, 'system');
    await prefs.setString(_urlKey, printer.url);
  }

  Future<List<Printer>> listPrinters() => Printing.listPrinters();

  Future<Printer?> getSavedSystemPrinter() async {
    final cfg = await getConfig();
    if (cfg.systemPrinterUrl == null) return null;
    final all = await listPrinters();
    for (final p in all) {
      if (p.url == cfg.systemPrinterUrl) return p;
    }
    return null;
  }

  Future<void> printZpl(String zpl) async {
    final cfg = await getConfig();
    if (cfg.mode == LabelPrinterMode.ip) {
      await _printViaSocket(zpl, cfg.host, cfg.port);
      return;
    }
    final printer = await getSavedSystemPrinter();
    if (printer == null) {
      throw StateError(
          'No system printer selected. Configure it in Settings → Impresora de Etiquetas.');
    }
    await _printRawToSystem(zpl, printer);
  }

  Future<void> _printViaSocket(String zpl, String host, int port) async {
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 5));
    try {
      socket.write(zpl);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  Future<void> _printRawToSystem(String zpl, Printer printer) async {
    if (Platform.isWindows) {
      _printRawWindows(zpl, printer.name);
      return;
    }
    // macOS / Linux: shell out to CUPS' lp with raw mode.
    final process = await Process.start('lp',
        ['-d', printer.name, '-o', 'raw'], runInShell: false);
    process.stdin.add(utf8.encode(zpl));
    await process.stdin.close();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final err = await process.stderr.transform(utf8.decoder).join();
      throw Exception('lp exited with $exitCode: $err');
    }
  }

  /// Sends raw bytes to a Windows printer via the Win32 Print Spooler API
  /// with datatype "RAW", so the bytes (ZPL) reach the Zebra untouched.
  void _printRawWindows(String zpl, String printerName) {
    final namePtr = printerName.toNativeUtf16();
    final hPrinterPtr = calloc<IntPtr>();
    final docInfo = calloc<DOC_INFO_1>();
    final rawTypePtr = 'RAW'.toNativeUtf16();
    final docNamePtr = 'Storefunctions Label'.toNativeUtf16();
    final bytes = utf8.encode(zpl);
    final dataPtr = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      dataPtr[i] = bytes[i];
    }
    final writtenPtr = calloc<Uint32>();

    try {
      if (OpenPrinter(namePtr, hPrinterPtr, nullptr) == 0) {
        throw Exception(
            'OpenPrinter("$printerName") failed: ${GetLastError()}');
      }
      final hPrinter = hPrinterPtr.value;
      try {
        docInfo.ref.pDocName = docNamePtr;
        docInfo.ref.pOutputFile = nullptr;
        docInfo.ref.pDatatype = rawTypePtr;
        if (StartDocPrinter(hPrinter, 1, docInfo) == 0) {
          throw Exception('StartDocPrinter failed: ${GetLastError()}');
        }
        try {
          if (StartPagePrinter(hPrinter) == 0) {
            throw Exception('StartPagePrinter failed: ${GetLastError()}');
          }
          try {
            if (WritePrinter(hPrinter, dataPtr, bytes.length, writtenPtr) ==
                0) {
              throw Exception('WritePrinter failed: ${GetLastError()}');
            }
          } finally {
            EndPagePrinter(hPrinter);
          }
        } finally {
          EndDocPrinter(hPrinter);
        }
      } finally {
        ClosePrinter(hPrinter);
      }
    } finally {
      calloc.free(namePtr);
      calloc.free(hPrinterPtr);
      calloc.free(docInfo);
      calloc.free(rawTypePtr);
      calloc.free(docNamePtr);
      calloc.free(dataPtr);
      calloc.free(writtenPtr);
    }
  }
}
