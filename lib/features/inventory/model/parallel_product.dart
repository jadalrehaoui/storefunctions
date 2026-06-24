double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// A Parallel-only product stored in WorkDB (billable when not found in SITSA).
class ParallelProduct {
  final int? id;
  final String codigo;
  final String? barcode;
  final String descripcion;
  final String? modelo;
  final double precio;
  final double costo;
  final double utilidad;
  final int qty;
  final bool activo;
  final String? createdBy;
  final DateTime? createdAt;

  const ParallelProduct({
    this.id,
    required this.codigo,
    this.barcode,
    required this.descripcion,
    this.modelo,
    this.precio = 0,
    this.costo = 0,
    this.utilidad = 0,
    this.qty = 1,
    this.activo = true,
    this.createdBy,
    this.createdAt,
  });

  factory ParallelProduct.fromJson(Map<String, dynamic> json) =>
      ParallelProduct(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse(json['id']?.toString() ?? ''),
        codigo: json['codigo']?.toString() ?? '',
        barcode: json['barcode'] as String?,
        descripcion: json['descripcion']?.toString() ?? '',
        modelo: json['modelo'] as String?,
        precio: _toDouble(json['precio']),
        costo: _toDouble(json['costo']),
        utilidad: _toDouble(json['utilidad']),
        qty: json['qty'] is int
            ? json['qty'] as int
            : (int.tryParse(json['qty']?.toString() ?? '') ?? 1),
        activo: json['activo'] is bool
            ? json['activo'] as bool
            : (json['activo']?.toString() != 'false'),
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'barcode': barcode,
        'descripcion': descripcion,
        'modelo': modelo,
        'precio': precio,
        'costo': costo,
        'utilidad': utilidad,
        'qty': qty,
      };
}
