class ItemListMembership {
  final String type;
  final int qty;
  final DateTime? addedAt;

  const ItemListMembership({
    required this.type,
    required this.qty,
    this.addedAt,
  });

  factory ItemListMembership.fromJson(Map<String, dynamic> json) {
    return ItemListMembership(
      type: json['type']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['added_at']?.toString() ?? ''),
    );
  }
}
