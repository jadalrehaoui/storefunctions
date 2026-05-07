import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/inventory_service.dart';
import 'validate_barcodes_state.dart';

export 'validate_barcodes_state.dart';

class ValidateBarcodesCubit extends Cubit<ValidateBarcodesState> {
  final InventoryService _inventoryService;
  String? _filePath;

  ValidateBarcodesCubit(this._inventoryService)
      : super(const ValidateBarcodesInitial());

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) {
      emit(const ValidateBarcodesFailure('No se pudo leer el archivo.'));
      return;
    }
    _filePath = file.path;
    emit(ValidateBarcodesInitial(selectedFileName: file.name));
  }

  void clearFile() {
    _filePath = null;
    emit(const ValidateBarcodesInitial());
  }

  Future<void> validate() async {
    final path = _filePath;
    final name = state.selectedFileName;
    if (path == null || name == null) {
      emit(const ValidateBarcodesFailure('Selecciona un archivo primero.'));
      return;
    }

    emit(ValidateBarcodesLoading(selectedFileName: name));
    try {
      final data = await _inventoryService.checkBarcodesFile(
        filePath: path,
        filename: name,
      );

      if (data is! Map || data['success'] != true) {
        final err = (data is Map ? data['error']?.toString() : null) ??
            'Respuesta inesperada del servidor.';
        emit(ValidateBarcodesFailure(err, selectedFileName: name));
        return;
      }

      final existingRaw = (data['existing'] as List?) ?? const [];
      final existing = existingRaw
          .whereType<Map>()
          .map((e) => ExistingBarcode.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      emit(ValidateBarcodesSuccess(
        allFree: data['allFree'] == true,
        message: data['message']?.toString() ?? '',
        total: (data['total'] as num?)?.toInt() ?? 0,
        existingCount: (data['existingCount'] as num?)?.toInt() ?? existing.length,
        existing: existing,
        selectedFileName: name,
      ));
    } on DioException catch (e) {
      final body = e.response?.data;
      final apiMsg = body is Map ? body['error']?.toString() : null;
      emit(ValidateBarcodesFailure(
        apiMsg ?? e.message ?? 'Error de conexión',
        selectedFileName: name,
      ));
    } catch (e) {
      emit(ValidateBarcodesFailure(e.toString(), selectedFileName: name));
    }
  }
}
