class FerreteriaInvoiceItem {
  final double qty;
  final String codigo;
  final String detalle;
  final double? existencia;

  const FerreteriaInvoiceItem({
    required this.qty,
    required this.codigo,
    required this.detalle,
    required this.existencia,
  });

  /// Parses a single server-formatted line of the form
  /// `{qty}x {CODIGO} - {DETALLE} (existencia: {stock})`. Falls back to a
  /// raw item with the line in `detalle` if the format doesn't match.
  static final _re = RegExp(
    r'^\s*(-?\d+(?:[.,]\d+)?)x\s+(\S+)\s+-\s+(.*?)\s+\(existencia:\s*(-?\d+(?:[.,]\d+)?)\s*\)\s*$',
  );

  factory FerreteriaInvoiceItem.parse(String line) {
    final m = _re.firstMatch(line);
    if (m == null) {
      return FerreteriaInvoiceItem(
        qty: 0,
        codigo: '',
        detalle: line,
        existencia: null,
      );
    }
    double n(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;
    return FerreteriaInvoiceItem(
      qty: n(m.group(1)!),
      codigo: m.group(2)!,
      detalle: m.group(3)!.trim(),
      existencia: n(m.group(4)!),
    );
  }
}

class FerreteriaInvoice {
  final String factura;
  final String? cliente;
  final String? clienteCodigo;
  final DateTime? primeraVenta;
  final List<FerreteriaInvoiceItem> items;
  final String dedupKey;

  const FerreteriaInvoice({
    required this.factura,
    required this.cliente,
    required this.clienteCodigo,
    required this.primeraVenta,
    required this.items,
    required this.dedupKey,
  });

  /// Parses both server payload shapes:
  /// - new (aggregated): one event per invoice with `Items` string
  /// - old (per-line): one event per line with FACTURA, C_LINEA, CODIGO, etc.
  factory FerreteriaInvoice.fromJson(Map<String, dynamic> json) {
    final lower = <String, dynamic>{
      for (final e in json.entries) e.key.toLowerCase(): e.value,
    };
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        final v = lower[k.toLowerCase()];
        if (v != null) return v;
      }
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return null;
      // The server stamps local CR time with a trailing `Z`. Treating it as
      // real UTC would shift the badge by the local offset (6h). Reinterpret
      // any UTC-tagged value as a local DateTime with the same wall clock.
      if (dt.isUtc) {
        return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute,
            dt.second, dt.millisecond);
      }
      return dt;
    }

    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    double num0(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final itemsRaw = pick(['Items']);
    final factura = '${pick(['Factura', 'FACTURA']) ?? ''}';
    final cliente = str(pick(['Cliente']));
    final clienteCodigo = str(pick(['Cliente_Codigo']));
    final fecha = parseDate(
        pick(['Primera_Venta', 'FECHA_INSERTA', 'Fecha_Inserta']));

    // New aggregated shape
    if (itemsRaw is String) {
      final lines = itemsRaw
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      return FerreteriaInvoice(
        factura: factura,
        cliente: cliente,
        clienteCodigo: clienteCodigo,
        primeraVenta: fecha,
        items: lines.map(FerreteriaInvoiceItem.parse).toList(),
        dedupKey: factura,
      );
    }

    // Old per-line shape
    final cLinea = pick(['C_LINEA']);
    final codigo = '${pick(['CODIGO']) ?? ''}';
    final detalle = '${pick(['DETALLE']) ?? ''}';
    final modelo = pick(['MODELO'])?.toString();
    final detalleConModelo = (modelo != null && modelo.isNotEmpty)
        ? '$detalle  ·  $modelo'
        : detalle;
    return FerreteriaInvoice(
      factura: factura,
      cliente: cliente,
      clienteCodigo: clienteCodigo,
      primeraVenta: fecha,
      items: [
        FerreteriaInvoiceItem(
          qty: num0(pick(['CANTIDAD'])),
          codigo: codigo,
          detalle: detalleConModelo,
          existencia: numOrNull(pick(['Existencia', 'EXISTENCIA'])),
        ),
      ],
      dedupKey: '$factura#$cLinea',
    );
  }
}
