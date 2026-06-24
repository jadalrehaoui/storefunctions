import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/parallel_products_service.dart';
import '../model/parallel_product.dart';

sealed class ParallelProductsState {}

class ParallelProductsInitial extends ParallelProductsState {}

class ParallelProductsLoading extends ParallelProductsState {}

class ParallelProductsSuccess extends ParallelProductsState {
  final List<ParallelProduct> products;
  ParallelProductsSuccess(this.products);
}

class ParallelProductsFailure extends ParallelProductsState {
  final String error;
  ParallelProductsFailure(this.error);
}

class ParallelProductsCubit extends Cubit<ParallelProductsState> {
  final ParallelProductsService _service;

  ParallelProductsCubit(this._service) : super(ParallelProductsInitial());

  Future<void> load() async {
    emit(ParallelProductsLoading());
    try {
      final data = await _service.getProducts();
      // The API returns `{ items: [...] }`; tolerate `{ data: [...] }` or a bare list too.
      final raw = (data is Map && data['items'] is List)
          ? data['items'] as List
          : (data is Map && data['data'] is List)
              ? data['data'] as List
              : (data is List ? data : const []);
      final products = raw
          .whereType<Map<String, dynamic>>()
          .map(ParallelProduct.fromJson)
          .toList()
        ..sort((a, b) => a.codigo.compareTo(b.codigo));
      emit(ParallelProductsSuccess(products));
    } on DioException catch (e) {
      emit(ParallelProductsFailure(e.message ?? 'error'));
    } catch (e) {
      emit(ParallelProductsFailure(e.toString()));
    }
  }

  Future<void> createProduct(ParallelProduct product) async {
    await _service.addProduct(product.toJson());
    await load();
  }

  Future<void> editProduct(int id, ParallelProduct product) async {
    await _service.updateProduct(id, product.toJson());
    await load();
  }

  Future<void> deleteProduct(int id) async {
    await _service.deleteProduct(id);
    await load();
  }
}
