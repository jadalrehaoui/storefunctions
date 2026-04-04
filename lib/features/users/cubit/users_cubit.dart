import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';

sealed class UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<Map<String, dynamic>> users;
  UsersLoaded(this.users);
}

class UsersFailure extends UsersState {
  final String error;
  UsersFailure(this.error);
}

class UsersDeleteError extends UsersState {
  final String error;
  UsersDeleteError(this.error);
}

class UsersCubit extends Cubit<UsersState> {
  final ApiClient _api;

  UsersCubit(this._api) : super(UsersLoading());

  Future<void> load() async {
    emit(UsersLoading());
    try {
      final data = await _api.get('/api/workdb/users');
      final list = data is List
          ? data
          : (data is Map && data['users'] is List)
              ? data['users'] as List
              : <dynamic>[];
      emit(UsersLoaded(
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      ));
    } catch (e) {
      emit(UsersFailure(e.toString()));
    }
  }

  Future<void> createUser({
    required String username,
    required String password,
    required List<String> privileges,
  }) async {
    await _api.post('/api/workdb/users', {
      'username': username,
      'password': password,
      'privileges': privileges,
    });
    await load();
  }

  Future<void> editUser(
    int id, {
    required String username,
    String? password,
    required List<String> privileges,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'privileges': privileges,
      if (password != null) 'password': password,
    };
    await _api.put('/api/workdb/users/$id', body);
    await load();
  }

  Future<void> deleteUser(int id) async {
    try {
      await _api.delete('/api/workdb/users/$id');
    } catch (e) {
      emit(UsersDeleteError(e.toString()));
    }
    await load();
  }
}
