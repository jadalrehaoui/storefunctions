import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/article_result.dart';
import '../../../services/inventory_service.dart';
import 'print_labels_state.dart';

export 'print_labels_state.dart';

class PrintLabelsCubit extends Cubit<PrintLabelsState> {
  final InventoryService _inventoryService;

  PrintLabelsCubit(this._inventoryService) : super(PrintLabelsInitial());

  void reset() => emit(PrintLabelsInitial());

  Future<void> searchByBarcode(String articleId) async {
    final id = articleId.trim();
    if (id.isEmpty) return;

    emit(PrintLabelsLoading());
    try {
      final response = await _inventoryService.searchByBarcode(id);
      final data = response['data'] as List<dynamic>;
      final results = data
          .map((e) => ArticleResult.fromJson(e as Map<String, dynamic>))
          .toList();
      emit(PrintLabelsSuccess(results));
    } on DioException catch (e) {
      emit(PrintLabelsFailure(e.message ?? 'Error de conexión'));
    } catch (e) {
      emit(PrintLabelsFailure(e.toString()));
    }
  }
}
