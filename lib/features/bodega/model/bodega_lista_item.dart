class BodegaListaItem {
  final int id;
  final String sitsaCode;
  final String? barcode;
  final String descripcion;
  final String? modelo;
  final double? precio;
  final int qty;
  final int addedByUserId;
  final String addedByUsername;
  final DateTime addedAt;

  const BodegaListaItem({
    required this.id,
    required this.sitsaCode,
    required this.barcode,
    required this.descripcion,
    required this.modelo,
    required this.precio,
    required this.qty,
    required this.addedByUserId,
    required this.addedByUsername,
    required this.addedAt,
  });

  factory BodegaListaItem.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    return BodegaListaItem(
      id: (json['id'] as num).toInt(),
      sitsaCode: '${json['sitsa_code'] ?? ''}',
      barcode: json['barcode']?.toString(),
      descripcion: '${json['descripcion'] ?? ''}',
      modelo: json['modelo']?.toString(),
      precio: precio is num ? precio.toDouble() : null,
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      addedByUserId: (json['added_by_user_id'] as num).toInt(),
      addedByUsername: '${json['added_by_username'] ?? ''}',
      addedAt: DateTime.parse('${json['added_at']}'),
    );
  }
}
