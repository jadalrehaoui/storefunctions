class EnrichedRow {
  final String code;
  final String? sitsaCode;
  final String? barcode;
  final String? descripcion;
  final String? modelo;
  final int? qty;
  final String? tica;

  const EnrichedRow({
    required this.code,
    this.sitsaCode,
    this.barcode,
    this.descripcion,
    this.modelo,
    this.qty,
    this.tica,
  });

  factory EnrichedRow.fromJson(Map<String, dynamic> json) {
    return EnrichedRow(
      code: json['code']?.toString() ?? '',
      sitsaCode: json['sitsa_code']?.toString(),
      barcode: json['barcode']?.toString(),
      descripcion: json['descripcion']?.toString(),
      modelo: json['modelo']?.toString(),
      qty: (json['qty'] as num?)?.toInt(),
      tica: json['tica']?.toString(),
    );
  }
}

sealed class EnrichCodesState {
  final String? selectedFileName;
  final bool ticaEnabled;
  const EnrichCodesState({this.selectedFileName, this.ticaEnabled = true});
}

class EnrichCodesInitial extends EnrichCodesState {
  const EnrichCodesInitial({super.selectedFileName, super.ticaEnabled});
}

class EnrichCodesLoading extends EnrichCodesState {
  const EnrichCodesLoading({super.selectedFileName, super.ticaEnabled});
}

class EnrichCodesFailure extends EnrichCodesState {
  final String error;
  const EnrichCodesFailure(this.error,
      {super.selectedFileName, super.ticaEnabled});
}

class EnrichCodesSuccess extends EnrichCodesState {
  final int total;
  final int found;
  final List<String> missing;
  final List<EnrichedRow> items;
  const EnrichCodesSuccess({
    required this.total,
    required this.found,
    required this.missing,
    required this.items,
    super.selectedFileName,
    super.ticaEnabled,
  });
}
