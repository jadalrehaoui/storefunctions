class EnrichedRow {
  final String code;
  final String? sitsaCode;
  final String? barcode;
  final String? descripcion;
  final String? modelo;
  final int? qty;
  final String? tica;
  final String? costo;
  final String? utilidad;
  final String? precio;
  final String? fob;
  final String? clasificacion;
  final String? reservada;
  final String? proveedorNombre;
  final String? ingresado;
  final String? vendido;

  const EnrichedRow({
    required this.code,
    this.sitsaCode,
    this.barcode,
    this.descripcion,
    this.modelo,
    this.qty,
    this.tica,
    this.costo,
    this.utilidad,
    this.precio,
    this.fob,
    this.clasificacion,
    this.reservada,
    this.proveedorNombre,
    this.ingresado,
    this.vendido,
  });

  /// Generic getter by the API key used in the shared column model.
  String? valueForKey(String key) {
    switch (key) {
      case 'code':
        return code;
      case 'sitsa_code':
        return sitsaCode;
      case 'barcode':
        return barcode;
      case 'descripcion':
        return descripcion;
      case 'modelo':
        return modelo;
      case 'qty':
        return qty?.toString();
      case 'tica':
        return tica;
      case 'Costo':
        return costo;
      case 'UTILIDAD':
        return utilidad;
      case 'Precio':
        return precio;
      case 'FOB':
        return fob;
      case 'Clasificacion':
        return clasificacion;
      case 'Reservada':
        return reservada;
      case 'Proveedor_Nombre':
        return proveedorNombre;
      case 'Ingresado':
        return ingresado;
      case 'Vendido':
        return vendido;
      default:
        return null;
    }
  }

  factory EnrichedRow.fromJson(Map<String, dynamic> json) {
    String? str(String k) => json[k]?.toString();
    return EnrichedRow(
      code: json['code']?.toString() ?? '',
      sitsaCode: json['sitsa_code']?.toString(),
      barcode: json['barcode']?.toString(),
      descripcion: json['descripcion']?.toString(),
      modelo: json['modelo']?.toString(),
      qty: (json['qty'] as num?)?.toInt(),
      tica: json['tica']?.toString(),
      costo: str('Costo'),
      utilidad: str('UTILIDAD'),
      precio: str('Precio'),
      fob: str('FOB'),
      clasificacion: str('Clasificacion'),
      reservada: str('Reservada'),
      proveedorNombre: str('Proveedor_Nombre'),
      ingresado: str('Ingresado'),
      vendido: str('Vendido'),
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
