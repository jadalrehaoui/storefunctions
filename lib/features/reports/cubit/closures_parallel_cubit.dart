import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

sealed class ClosuresParallelState {}

class ClosuresParallelInitial extends ClosuresParallelState {}

class ClosuresParallelLoading extends ClosuresParallelState {}

class ClosuresParallelLoaded extends ClosuresParallelState {
  final List<Map<String, dynamic>> closures;
  ClosuresParallelLoaded(this.closures);
}

class ClosuresParallelFailure extends ClosuresParallelState {
  final String error;
  ClosuresParallelFailure(this.error);
}

class ClosuresParallelCubit extends Cubit<ClosuresParallelState> {
  final ApiClient _api;

  ClosuresParallelCubit(this._api) : super(ClosuresParallelInitial());

  Future<void> load() async {
    emit(ClosuresParallelLoading());
    try {
      final data = await _api.get('/api/workdb/closures-parallel');
      final list = data is List
          ? data
          : (data['closures'] ?? data['data'] ?? []) as List;
      final closures =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      emit(ClosuresParallelLoaded(closures));
    } catch (e) {
      emit(ClosuresParallelFailure(e.toString()));
    }
  }
}
