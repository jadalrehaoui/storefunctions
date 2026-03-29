import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

sealed class ClosuresState {}

class ClosuresInitial extends ClosuresState {}

class ClosuresLoading extends ClosuresState {}

class ClosuresLoaded extends ClosuresState {
  final List<Map<String, dynamic>> closures;
  ClosuresLoaded(this.closures);
}

class ClosuresFailure extends ClosuresState {
  final String error;
  ClosuresFailure(this.error);
}

class ClosuresCubit extends Cubit<ClosuresState> {
  final ApiClient _api;

  ClosuresCubit(this._api) : super(ClosuresInitial());

  Future<void> load() async {
    emit(ClosuresLoading());
    try {
      final data = await _api.get('/api/workdb/closures');
      final list = data is List ? data : (data['closures'] ?? data['data'] ?? []) as List;
      final closures = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      emit(ClosuresLoaded(closures));
    } catch (e) {
      emit(ClosuresFailure(e.toString()));
    }
  }
}
