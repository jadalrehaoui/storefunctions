sealed class ExportInventoryState {}

class ExportInventoryInitial extends ExportInventoryState {}

class ExportInventoryLoading extends ExportInventoryState {
  final String? stage;
  ExportInventoryLoading({this.stage});
}

class ExportInventorySuccess extends ExportInventoryState {
  final String filePath;
  final int rowCount;
  ExportInventorySuccess({required this.filePath, required this.rowCount});
}

class ExportInventoryFailure extends ExportInventoryState {
  final String error;
  ExportInventoryFailure(this.error);
}
