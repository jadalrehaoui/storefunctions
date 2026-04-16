import '../model/invoice_models.dart';

/// Result of an item lookup against /api/sitsa/get-item.
class InvoiceItemPreview {
  final String sitsaCode;
  final String? barcode;
  final String description;
  final double unitPrice;

  const InvoiceItemPreview({
    required this.sitsaCode,
    required this.barcode,
    required this.description,
    required this.unitPrice,
  });
}

class InvoiceFormState {
  final List<InvoiceLineItem> items;

  // Header
  final String clientName;
  final String clientId;
  final DateTime date;
  final String notes;

  // Lookup
  final bool lookupLoading;
  final InvoiceItemPreview? lookupResult;
  final String? lookupError;

  // Submit
  final bool submitting;
  final String? submitError;
  final String? createdInvoiceId;

  // Discount escalation token (set after successful authorize-discount call)
  final String? discountAuthToken;

  const InvoiceFormState({
    this.items = const [],
    this.clientName = '',
    this.clientId = '',
    required this.date,
    this.notes = '',
    this.lookupLoading = false,
    this.lookupResult,
    this.lookupError,
    this.submitting = false,
    this.submitError,
    this.createdInvoiceId,
    this.discountAuthToken,
  });

  factory InvoiceFormState.initial() => InvoiceFormState(date: DateTime.now());

  double get subtotal =>
      items.fold(0, (sum, i) => sum + (i.unitPrice * i.quantity));

  double get discountAmount => items.fold(
      0, (sum, i) => sum + (i.unitPrice * i.quantity * (i.discountPct / 100)));

  double get total => subtotal - discountAmount;

  bool get hasHighDiscount => items.any((i) => i.discountPct > 15);

  InvoiceFormState copyWith({
    List<InvoiceLineItem>? items,
    String? clientName,
    String? clientId,
    DateTime? date,
    String? notes,
    bool? lookupLoading,
    InvoiceItemPreview? lookupResult,
    bool clearLookupResult = false,
    String? lookupError,
    bool clearLookupError = false,
    bool? submitting,
    String? submitError,
    bool clearSubmitError = false,
    String? createdInvoiceId,
    bool clearCreatedInvoiceId = false,
    String? discountAuthToken,
    bool clearDiscountAuthToken = false,
  }) {
    return InvoiceFormState(
      items: items ?? this.items,
      clientName: clientName ?? this.clientName,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      lookupLoading: lookupLoading ?? this.lookupLoading,
      lookupResult:
          clearLookupResult ? null : (lookupResult ?? this.lookupResult),
      lookupError: clearLookupError ? null : (lookupError ?? this.lookupError),
      submitting: submitting ?? this.submitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      createdInvoiceId: clearCreatedInvoiceId
          ? null
          : (createdInvoiceId ?? this.createdInvoiceId),
      discountAuthToken: clearDiscountAuthToken
          ? null
          : (discountAuthToken ?? this.discountAuthToken),
    );
  }
}
