import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

sealed class ClosureDetailState {}

class ClosureDetailLoading extends ClosureDetailState {}

class ClosureDetailLoaded extends ClosureDetailState {
  final Map<String, dynamic> closure;
  ClosureDetailLoaded(this.closure);
}

class ClosureDetailFailure extends ClosureDetailState {
  final String error;
  ClosureDetailFailure(this.error);
}

class ClosureDetailCubit extends Cubit<ClosureDetailState> {
  final ApiClient _api;

  ClosureDetailCubit(this._api) : super(ClosureDetailLoading());

  Future<void> load(String id) async {
    emit(ClosureDetailLoading());
    try {
      final res = await _api.get('/api/workdb/closures/$id');
      final data = res['data'] ?? res;
      emit(ClosureDetailLoaded(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      emit(ClosureDetailFailure(e.toString()));
    }
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await _api.put('/api/workdb/closures/$id', payload);
    await load(id);
  }
}
