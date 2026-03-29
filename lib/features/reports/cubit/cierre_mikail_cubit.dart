import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';

sealed class CierreMikailState {}

class CierreMikailInitial extends CierreMikailState {}

class CierreMikailLoading extends CierreMikailState {}

class CierreMikailLoaded extends CierreMikailState {
  final Map<String, dynamic> data;
  CierreMikailLoaded(this.data);
}

class CierreMikailFailure extends CierreMikailState {
  final String error;
  CierreMikailFailure(this.error);
}

class CierreMikailCubit extends Cubit<CierreMikailState> {
  final ApiClient _api;
  static final _fmt = DateFormat('yyyy-MM-dd');

  CierreMikailCubit(this._api) : super(CierreMikailInitial());

  Future<String> saveOrUpdate(Map<String, dynamic> payload,
      {String? closureId}) async {
    if (closureId != null) {
      await _api.put('/api/workdb/closures/$closureId', payload);
      return closureId;
    } else {
      final result = await _api.post('/api/workdb/closures', payload);
      return result['id'].toString();
    }
  }

  Future<void> load(DateTime date) async {
    emit(CierreMikailLoading());
    try {
      final data = await _api.post('/api/mikail/get-daily-report', {
        'date': _fmt.format(date),
      });
      emit(CierreMikailLoaded(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      emit(CierreMikailFailure(e.toString()));
    }
  }
}
