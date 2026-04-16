import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

sealed class CierresPersonalesState {}

class CierresPersonalesInitial extends CierresPersonalesState {}

class CierresPersonalesLoading extends CierresPersonalesState {}

class CierresPersonalesLoaded extends CierresPersonalesState {
  final List<Map<String, dynamic>> items;
  CierresPersonalesLoaded(this.items);
}

class CierresPersonalesFailure extends CierresPersonalesState {
  final String error;
  CierresPersonalesFailure(this.error);
}

class CierresPersonalesCubit extends Cubit<CierresPersonalesState> {
  final ApiClient _api;

  CierresPersonalesCubit(this._api) : super(CierresPersonalesInitial());

  Future<void> load({String? date, String? usuario}) async {
    emit(CierresPersonalesLoading());
    try {
      final qp = <String, String>{};
      if (date != null && date.isNotEmpty) qp['date'] = date;
      if (usuario != null && usuario.isNotEmpty) qp['usuario'] = usuario;
      final query = qp.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final path = query.isEmpty
          ? '/api/workdb/cierres-personales'
          : '/api/workdb/cierres-personales?$query';
      final data = await _api.get(path);
      final list = data is List
          ? data
          : (data is Map
              ? (data['data'] ?? data['items'] ?? []) as List
              : const []);
      final items =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      emit(CierresPersonalesLoaded(items));
    } catch (e) {
      emit(CierresPersonalesFailure(e.toString()));
    }
  }
}

sealed class CierrePersonalDetailState {}

class CierrePersonalDetailLoading extends CierrePersonalDetailState {}

class CierrePersonalDetailLoaded extends CierrePersonalDetailState {
  final Map<String, dynamic> item;
  CierrePersonalDetailLoaded(this.item);
}

class CierrePersonalDetailFailure extends CierrePersonalDetailState {
  final String error;
  CierrePersonalDetailFailure(this.error);
}

class CierrePersonalDetailCubit extends Cubit<CierrePersonalDetailState> {
  final ApiClient _api;
  final String id;

  CierrePersonalDetailCubit(this._api, this.id)
      : super(CierrePersonalDetailLoading());

  Future<void> load() async {
    emit(CierrePersonalDetailLoading());
    try {
      final data = await _api.get('/api/workdb/cierre-personal/$id');
      final item = data is Map<String, dynamic>
          ? (data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data)
          : <String, dynamic>{};
      emit(CierrePersonalDetailLoaded(item));
    } catch (e) {
      emit(CierrePersonalDetailFailure(e.toString()));
    }
  }

  Future<void> delete() async {
    await _api.delete('/api/workdb/cierre-personal/$id');
  }
}
