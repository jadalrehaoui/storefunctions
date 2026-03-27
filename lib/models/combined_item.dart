class SitsaItem {
  final String description;
  final String model;
  final String classification;
  final double fob;
  final double costo;
  final double ganancia;
  final DateTime? fechaCreacion;
  final double? vendido;
  final String? codigoBarras;
  final double? disponible;

  const SitsaItem({
    required this.description,
    required this.model,
    required this.classification,
    required this.fob,
    required this.costo,
    required this.ganancia,
    this.fechaCreacion,
    this.vendido,
    this.codigoBarras,
    this.disponible,
  });

  factory SitsaItem.fromJson(Map<String, dynamic> json) {
    DateTime? fecha;
    final fechaRaw = json['Fecha_Creacion'] as String?;
    if (fechaRaw != null) fecha = DateTime.tryParse(fechaRaw);

    return SitsaItem(
      description: json['Descripcion'] as String? ?? '',
      model: json['MODELO'] as String? ?? '',
      classification: json['Clasificacion_Descripcion'] as String? ?? '',
      fob: (json['FOB'] as num?)?.toDouble() ?? 0,
      costo: (json['Costo'] as num?)?.toDouble() ?? 0,
      ganancia: (json['Ganancia'] as num?)?.toDouble() ?? 0,
      fechaCreacion: fecha,
      vendido: (json['VendidoEnSitsa'] as num?)?.toDouble(),
      codigoBarras: json['Codigo_Barras'] as String?,
      disponible: (json['Disponible'] as num?)?.toDouble(),
    );
  }
}

class MikailItem {
  final double existencia;
  final double precio;
  final double costo;
  final double utilidad;
  final double ingreso;
  final double? vendido;

  const MikailItem({
    required this.existencia,
    required this.precio,
    required this.costo,
    required this.utilidad,
    required this.ingreso,
    this.vendido,
  });

  factory MikailItem.fromJson(Map<String, dynamic> json) {
    return MikailItem(
      existencia: (json['Existencia'] as num?)?.toDouble() ?? 0,
      precio: (json['Precio'] as num?)?.toDouble() ?? 0,
      costo: (json['Costo'] as num?)?.toDouble() ?? 0,
      utilidad: (json['Utilidad'] as num?)?.toDouble() ?? 0,
      ingreso: (json['Ingreso'] as num?)?.toDouble() ?? 0,
      vendido: (json['VendidoEnMikail'] as num?)?.toDouble(),
    );
  }
}

class CombinedItem {
  final String code;
  final SitsaItem? sitsa;
  final MikailItem? mikail;
  final dynamic raw;
  final String? tica;

  const CombinedItem({
    required this.code,
    required this.raw,
    this.sitsa,
    this.mikail,
    this.tica,
  });

  double? get totalVentas {
    final s = sitsa?.vendido;
    final m = mikail?.vendido;
    if (s == null && m == null) return null;
    return (s ?? 0) + (m ?? 0);
  }

  factory CombinedItem.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return CombinedItem(code: '', raw: json);

    SitsaItem? sitsa;
    MikailItem? mikail;

    if (json['sitsa'] is Map<String, dynamic>) {
      sitsa = SitsaItem.fromJson(json['sitsa'] as Map<String, dynamic>);
    }
    if (json['mikail'] is Map<String, dynamic>) {
      mikail = MikailItem.fromJson(json['mikail'] as Map<String, dynamic>);
    }

    return CombinedItem(
      code: json['code'] as String? ?? '',
      sitsa: sitsa,
      mikail: mikail,
      raw: json,
    );
  }

  CombinedItem withTica(String? ticaValue) {
    return CombinedItem(
      code: code,
      sitsa: sitsa,
      mikail: mikail,
      raw: raw,
      tica: ticaValue,
    );
  }
}
