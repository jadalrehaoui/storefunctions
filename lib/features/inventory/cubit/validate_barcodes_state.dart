class ExistingBarcode {
  final dynamic pkArticulo;
  final String codigoBarras;
  final String descripcion;
  final String modelo;

  ExistingBarcode({
    required this.pkArticulo,
    required this.codigoBarras,
    required this.descripcion,
    required this.modelo,
  });

  factory ExistingBarcode.fromJson(Map<String, dynamic> json) {
    return ExistingBarcode(
      pkArticulo: json['PK_Articulo'],
      codigoBarras: json['Codigo_Barras']?.toString() ?? '',
      descripcion: json['Descripcion']?.toString() ?? '',
      modelo: json['MODELO']?.toString() ?? '',
    );
  }
}

sealed class ValidateBarcodesState {
  final String? selectedFileName;
  const ValidateBarcodesState({this.selectedFileName});
}

class ValidateBarcodesInitial extends ValidateBarcodesState {
  const ValidateBarcodesInitial({super.selectedFileName});
}

class ValidateBarcodesLoading extends ValidateBarcodesState {
  const ValidateBarcodesLoading({super.selectedFileName});
}

class ValidateBarcodesSuccess extends ValidateBarcodesState {
  final bool allFree;
  final String message;
  final int total;
  final int existingCount;
  final List<ExistingBarcode> existing;

  const ValidateBarcodesSuccess({
    required this.allFree,
    required this.message,
    required this.total,
    required this.existingCount,
    required this.existing,
    super.selectedFileName,
  });
}

class ValidateBarcodesFailure extends ValidateBarcodesState {
  final String error;
  const ValidateBarcodesFailure(this.error, {super.selectedFileName});
}
