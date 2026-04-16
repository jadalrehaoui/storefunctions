import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

enum LabelPrinterMode { ip, system }

/// The ZPL template in `label_printer.dart` was tuned for a 300 dpi Zebra.
/// When a system printer runs at a different DPI (e.g. ZD421 at 203 dpi),
/// the same ZPL comes out too large. We scale all dot-based coordinates
/// by `targetDpi / templateDpi` before sending.
const int _templateDpi = 300;

class LabelPrinterConfig {
  final LabelPrinterMode mode;
  final String host;
  final int port;
  final String? systemPrinterUrl;
  final int systemDpi;

  const LabelPrinterConfig({
    required this.mode,
    required this.host,
    required this.port,
    required this.systemPrinterUrl,
    required this.systemDpi,
  });

  static const defaults = LabelPrinterConfig(
    mode: LabelPrinterMode.ip,
    host: '10.10.0.144',
    port: 9100,
    systemPrinterUrl: null,
    systemDpi: 203,
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
  static const _dpiKey = 'label_printer_system_dpi';

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
      systemDpi:
          prefs.getInt(_dpiKey) ?? LabelPrinterConfig.defaults.systemDpi,
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

  Future<void> saveSystemDpi(int dpi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dpiKey, dpi);
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
    final scaled = cfg.systemDpi == _templateDpi
        ? zpl
        : _scaleZpl(zpl, cfg.systemDpi / _templateDpi);
    await _printRawToSystem(scaled, printer);
  }

  /// Scales dot-based coordinates in the ZPL template so the same label
  /// prints at the correct physical size on a printer with a different DPI.
  /// Only numeric params known to represent dots are scaled — counts,
  /// orientations, ratios, and data fields are left alone.
  String _scaleZpl(String zpl, double scale) {
    int s(int v) => (v * scale).round();
    return zpl
        // ^PW<n>, ^LL<n>, ^LS<signed n>
        .replaceAllMapped(RegExp(r'\^(PW|LL|LS)(-?\d+)'), (m) {
          return '^${m.group(1)}${s(int.parse(m.group(2)!))}';
        })
        // ^FT<x>,<y>
        .replaceAllMapped(RegExp(r'\^FT(\d+),(\d+)'), (m) {
          return '^FT${s(int.parse(m.group(1)!))},${s(int.parse(m.group(2)!))}';
        })
        // ^FB<width>,<lines>,<line-space>,<align>
        .replaceAllMapped(RegExp(r'\^FB(\d+),(\d+),(\d+),(\w)'), (m) {
          return '^FB${s(int.parse(m.group(1)!))},'
              '${m.group(2)},${s(int.parse(m.group(3)!))},${m.group(4)}';
        })
        // ^BY<narrow>,<ratio>,<height>
        .replaceAllMapped(RegExp(r'\^BY(\d+),(\d+(?:\.\d+)?),(\d+)'),
            (m) {
          final narrow =
              (int.parse(m.group(1)!) * scale).round().clamp(1, 10);
          return '^BY$narrow,${m.group(2)},${s(int.parse(m.group(3)!))}';
        })
        // ^A0B,<h>,<w> or ^A0N,<h>,<w>
        .replaceAllMapped(RegExp(r'\^A0([BN]),(\d+),(\d+)'), (m) {
          return '^A0${m.group(1)},'
              '${s(int.parse(m.group(2)!))},${s(int.parse(m.group(3)!))}';
        });
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
