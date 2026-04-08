DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    // Unix epoch — seconds or milliseconds.
    final n = v.toInt();
    return DateTime.fromMillisecondsSinceEpoch(n > 1e12 ? n : n * 1000);
  }
  final s = v.toString();
  if (s.isEmpty) return null;
  // Try numeric string first.
  final asNum = int.tryParse(s);
  if (asNum != null) {
    return DateTime.fromMillisecondsSinceEpoch(
        asNum > 1000000000000 ? asNum : asNum * 1000);
  }
  return DateTime.tryParse(s);
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// In-memory line item used during invoice creation/editing.
class InvoiceLineItem {
  final String sitsaCode;
  final String? barcode;
  final String description;
  final String? tica;
  double unitPrice;
  double quantity;
  double discountPct;

  InvoiceLineItem({
    required this.sitsaCode,
    required this.barcode,
    required this.description,
    required this.unitPrice,
    this.tica,
    this.quantity = 1,
    this.discountPct = 0,
  });

  double get lineTotal =>
      unitPrice * quantity * (1 - (discountPct / 100));

  Map<String, dynamic> toJson() => {
        'sitsa_code': sitsaCode,
        'barcode': barcode,
        'description': description,
        'unit_price': unitPrice,
        'quantity': quantity,
        'discount_pct': discountPct,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        sitsaCode: json['sitsa_code']?.toString() ?? '',
        barcode: json['barcode'] as String?,
        description: json['description'] as String? ?? '',
        unitPrice: _toDouble(json['unit_price']),
        quantity: json['quantity'] == null ? 1 : _toDouble(json['quantity']),
        discountPct: _toDouble(json['discount_pct']),
      );
}

/// Lightweight summary used in the list view.
class InvoiceSummary {
  final String id;
  final DateTime date;
  final String? clientName;
  final double subtotal;
  final double discount;
  final double total;
  final String status; // 'active' | 'voided'
  final String? createdBy;

  const InvoiceSummary({
    required this.id,
    required this.date,
    required this.clientName,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdBy,
  });

  bool get isActive => status == 'active';

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => InvoiceSummary(
        id: json['id'].toString(),
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        clientName: json['client_name'] as String?,
        subtotal: _toDouble(json['subtotal']),
        discount: _toDouble(json['discount']),
        total: _toDouble(json['total']),
        status: json['status'] as String? ?? 'active',
        createdBy: json['created_by'] as String?,
      );
}

/// Full invoice returned from the detail endpoint.
class InvoiceDetail {
  final String id;
  final DateTime date;
  final String? clientName;
  final String? clientId;
  final String? notes;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;
  final List<InvoiceLineItem> items;

  const InvoiceDetail({
    required this.id,
    required this.date,
    required this.clientName,
    required this.clientId,
    required this.notes,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.items,
  });

  bool get isActive => status == 'active';

  double get subtotal =>
      items.fold(0, (sum, i) => sum + (i.unitPrice * i.quantity));

  double get discountAmount =>
      items.fold(0, (sum, i) => sum + (i.unitPrice * i.quantity * (i.discountPct / 100)));

  double get total => subtotal - discountAmount;

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return InvoiceDetail(
      id: json['id'].toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      clientName: json['client_name'] as String?,
      clientId: json['client_id'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'active',
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_ts'] ??
          json['created_at_ts'] ??
          json['created_at'] ??
          json['createdAt']),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(InvoiceLineItem.fromJson)
          .toList(),
    );
  }
}
