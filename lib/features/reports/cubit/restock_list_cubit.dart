import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../services/api_client.dart';

sealed class RestockListState {}

class RestockListInitial extends RestockListState {}

class RestockListLoading extends RestockListState {}

class RestockListLoaded extends RestockListState {
  final List<Map<String, dynamic>> items;
  RestockListLoaded(this.items);
}

class RestockListFailure extends RestockListState {
  final String error;
  RestockListFailure(this.error);
}

class RestockListCubit extends Cubit<RestockListState> {
  final ApiClient _api;
  static final _fmt = DateFormat('yyyy-MM-dd');

  RestockListCubit(this._api) : super(RestockListInitial());

  Future<void> load(DateTime date) async {
    emit(RestockListLoading());
    try {
      final res = await _api.post('/api/sitsa/get-restock', {
        'date': _fmt.format(date),
      });
      final list = (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      emit(RestockListLoaded(list));
    } catch (e) {
      emit(RestockListFailure(e.toString()));
    }
  }
}
