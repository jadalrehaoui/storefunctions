import 'dart:io';

import 'package:intl/intl.dart';

/// Builds a CSV (Excel-compatible) of the inventory search results and saves
/// it to ~/Downloads. Returns the saved path. Includes UTF-8 BOM so Excel
/// renders accents correctly on Windows.
Future<String> exportInventorySearchToExcel({
  required String query,
  required List<dynamic> items,
  required bool showProfit,
}) async {
  final fobFmt = NumberFormat('0.00', 'en_US');
  final priceFmt = NumberFormat('0.00', 'en_US');
  final now = DateTime.now();

  final headers = <String>[
    'Código',
    'Barras',
    'Descripción',
    'Modelo',
    if (showProfit) 'FOB',
    if (showProfit) 'Costo',
    if (showProfit) 'Ganancia%',
    'Precio',
    'Disponible',
    'Reservada',
    'Ingresado',
  ];

  final buf = StringBuffer();
  buf.write('﻿'); // UTF-8 BOM for Excel
  buf.writeln(headers.map(_escape).join(','));

  for (final raw in items) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final costo = (m['Costo'] as num?)?.toDouble() ?? 0;
    final utilidad =
        ((m['UTILIDAD'] ?? m['Ganancia']) as num?)?.toDouble() ?? 0;
    final precio = (m['Precio'] as num?)?.toDouble() ??
        costo + costo * utilidad / 100;
    final ingresado = m['Ingresado'] ?? 0;

    final row = <String>[
      '${m['PK_FK_Articulo'] ?? ''}',
      '${m['Codigo_Barras'] ?? ''}',
      '${m['Articulo_Descripcion'] ?? ''}',
      '${m['MODELO'] ?? ''}',
      if (showProfit) fobFmt.format((m['FOB'] as num?)?.toDouble() ?? 0),
      if (showProfit) priceFmt.format(costo),
      if (showProfit) utilidad.toStringAsFixed(0),
      priceFmt.format(precio),
      '${m['Cantidad_Disponible'] ?? 0}',
      '${m['Cantidad_Reservada'] ?? 0}',
      '$ingresado',
    ];
    buf.writeln(row.map(_escape).join(','));
  }

  final dir = Platform.isMacOS
      ? '/Users/${Platform.environment['USER']}/Downloads'
      : '${Platform.environment['USERPROFILE']}\\Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
  final safeQuery = query
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final path =
      '$dir${Platform.pathSeparator}inventario_buscar_${safeQuery}_$ts.csv';
  await File(path).writeAsString(buf.toString());

  if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  }
  return path;
}

String _escape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
