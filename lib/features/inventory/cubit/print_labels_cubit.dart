import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/combined_item.dart';
import '../../../services/inventory_service.dart';
import 'print_labels_state.dart';

export 'print_labels_state.dart';

class PrintLabelsCubit extends Cubit<PrintLabelsState> {
  final InventoryService _inventoryService;

  PrintLabelsCubit(this._inventoryService) : super(PrintLabelsInitial());

  void reset() => emit(PrintLabelsInitial());

  Future<void> search(String code) async {
    final c = code.trim();
    if (c.isEmpty) return;

    emit(PrintLabelsLoading());
    try {
      final data = await _inventoryService.getItemCombined(c);
      final item = CombinedItem.fromJson(data);
      emit(PrintLabelsSuccess(item));
    } on DioException catch (e) {
      emit(PrintLabelsFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(PrintLabelsFailure(e.toString()));
    }
  }
}
