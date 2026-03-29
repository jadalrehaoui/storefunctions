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
    String? username,
    String? password,
    List<String>? privileges,
  }) async {
    final body = <String, dynamic>{
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (privileges != null) 'privileges': privileges,
    };
    await _api.put('/api/workdb/users/$id', body);
    await load();
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('/api/workdb/users/$id');
    await load();
  }
}
