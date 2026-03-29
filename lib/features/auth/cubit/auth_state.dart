sealed class AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String username;
  final List<String> privileges;
  AuthAuthenticated(this.username, {this.privileges = const []});

  bool hasPrivilege(String privilege) => privileges.contains(privilege);
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}
