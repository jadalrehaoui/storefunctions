import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/inventory_service.dart';
import 'enrich_codes_state.dart';

export 'enrich_codes_state.dart';

class EnrichCodesCubit extends Cubit<EnrichCodesState> {
  final InventoryService _inventoryService;
  String? _filePath;

  EnrichCodesCubit(this._inventoryService) : super(const EnrichCodesInitial());

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) {
      emit(EnrichCodesFailure('No se pudo leer el archivo.',
          ticaEnabled: state.ticaEnabled));
      return;
    }
    _filePath = file.path;
    emit(EnrichCodesInitial(
        selectedFileName: file.name, ticaEnabled: state.ticaEnabled));
  }

  void clearFile() {
    _filePath = null;
    emit(EnrichCodesInitial(ticaEnabled: state.ticaEnabled));
  }

  void setTicaEnabled(bool enabled) {
    if (state is EnrichCodesLoading) return;
    final name = state.selectedFileName;
    final s = state;
    if (s is EnrichCodesSuccess) {
      emit(EnrichCodesSuccess(
        total: s.total,
        found: s.found,
        missing: s.missing,
        items: s.items,
        selectedFileName: name,
        ticaEnabled: enabled,
      ));
    } else {
      emit(EnrichCodesInitial(selectedFileName: name, ticaEnabled: enabled));
    }
  }

  Future<void> run() async {
    final path = _filePath;
    final name = state.selectedFileName;
    final tica = state.ticaEnabled;
    if (path == null || name == null) {
      emit(EnrichCodesFailure('Selecciona un archivo primero.',
          ticaEnabled: tica));
      return;
    }
    emit(EnrichCodesLoading(selectedFileName: name, ticaEnabled: tica));
    try {
      final data = await _inventoryService.enrichCodesFile(
        filePath: path,
        filename: name,
        tica: tica,
      );
      if (data is! Map || data['success'] != true) {
        final err = (data is Map ? data['error']?.toString() : null) ??
            'Respuesta inesperada del servidor.';
        emit(EnrichCodesFailure(err,
            selectedFileName: name, ticaEnabled: tica));
        return;
      }
      final itemsRaw = (data['items'] as List?) ?? const [];
      final items = itemsRaw
          .whereType<Map>()
          .map((m) => EnrichedRow.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final missingRaw = (data['missing'] as List?) ?? const [];
      emit(EnrichCodesSuccess(
        total: (data['total'] as num?)?.toInt() ?? 0,
        found: (data['found'] as num?)?.toInt() ?? items.length,
        missing: missingRaw.map((e) => e.toString()).toList(),
        items: items,
        selectedFileName: name,
        ticaEnabled: tica,
      ));
    } on DioException catch (e) {
      final body = e.response?.data;
      final apiMsg = body is Map ? body['error']?.toString() : null;
      emit(EnrichCodesFailure(
        apiMsg ?? e.message ?? 'Error de conexión',
        selectedFileName: name,
        ticaEnabled: tica,
      ));
    } catch (e) {
      emit(EnrichCodesFailure(e.toString(),
          selectedFileName: name, ticaEnabled: tica));
    }
  }
}
