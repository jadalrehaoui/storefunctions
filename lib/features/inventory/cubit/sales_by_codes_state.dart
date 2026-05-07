sealed class SalesByCodesState {
  final String? selectedFileName;
  const SalesByCodesState({this.selectedFileName});
}

class SalesByCodesInitial extends SalesByCodesState {
  const SalesByCodesInitial({super.selectedFileName});
}

class SalesByCodesRunning extends SalesByCodesState {
  final int processed;
  final int total;
  const SalesByCodesRunning({
    required this.processed,
    required this.total,
    super.selectedFileName,
  });
}

class SalesByCodesSuccess extends SalesByCodesState {
  final String filePath;
  final int rowCount;
  final int notFoundCount;
  const SalesByCodesSuccess({
    required this.filePath,
    required this.rowCount,
    required this.notFoundCount,
    super.selectedFileName,
  });
}

class SalesByCodesFailure extends SalesByCodesState {
  final String error;
  const SalesByCodesFailure(this.error, {super.selectedFileName});
}
