import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';
import '../service/auth_service.dart';
import 'auth_state.dart';

export 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final ApiClient _apiClient;

  AuthCubit(this._authService, this._apiClient) : super(AuthUnauthenticated());

  Future<void> login(String username, String password) async {
    emit(AuthLoading());
    try {
      final result = await _authService.login(username, password);
      _apiClient.setToken(result.token);
      emit(AuthAuthenticated(username, privileges: result.privileges));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  void logout() {
    _apiClient.clearToken();
    emit(AuthUnauthenticated());
  }
}
