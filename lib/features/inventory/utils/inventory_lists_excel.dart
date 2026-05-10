import 'dart:io';

import 'package:intl/intl.dart';

/// Builds a CSV (Excel-compatible) of an item list and saves it to ~/Downloads.
/// Returns the saved path. Includes UTF-8 BOM so Excel renders accents
/// correctly on Windows.
Future<String> exportItemListToExcel({
  required String type,
  required List<Map<String, dynamic>> items,
  required bool showProfit,
}) async {
  final money = NumberFormat('0.00', 'en_US');
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final now = DateTime.now();

  final headers = <String>[
    'Lista',
    'Código',
    'Barras',
    'Descripción',
    'Modelo',
    if (showProfit) 'Costo',
    if (showProfit) 'Ganancia',
    'Precio',
    'Cantidad',
    'Agregado por',
    'Fecha',
  ];

  final buf = StringBuffer();
  buf.write('﻿'); // UTF-8 BOM for Excel
  buf.writeln(headers.map(_escape).join(','));

  for (final m in items) {
    final precio = (m['precio'] as num?)?.toDouble();
    final costo = (m['costo'] as num?)?.toDouble();
    final ganancia = (m['ganancia'] as num?)?.toDouble();
    final addedAt = m['added_at']?.toString();
    final addedAtParsed =
        addedAt == null ? null : DateTime.tryParse(addedAt)?.toLocal();

    final row = <String>[
      type,
      '${m['sitsa_code'] ?? ''}',
      '${m['barcode'] ?? ''}',
      '${m['descripcion'] ?? ''}',
      '${m['modelo'] ?? ''}',
      if (showProfit) costo != null ? money.format(costo) : '',
      if (showProfit) ganancia != null ? money.format(ganancia) : '',
      precio != null ? money.format(precio) : '',
      '${(m['qty'] as num?)?.toInt() ?? 0}',
      '${m['added_by_username'] ?? ''}',
      addedAtParsed != null ? dateFmt.format(addedAtParsed) : (addedAt ?? ''),
    ];
    buf.writeln(row.map(_escape).join(','));
  }

  final dir = Platform.isMacOS
      ? '/Users/${Platform.environment['USER']}/Downloads'
      : '${Platform.environment['USERPROFILE']}\\Downloads';
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
  final safeType = type
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final path = '$dir${Platform.pathSeparator}lista_${safeType}_$ts.csv';
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
