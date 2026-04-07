import 'package:dio/dio.dart';

import '../../../services/api_client.dart';

class AuthService {
  Dio get _dio => Dio(
        BaseOptions(
          baseUrl: ApiClient.currentBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        ),
      );

  /// Returns token and privileges on success. Throws a [String] error message on failure.
  Future<({String token, List<String> privileges})> login(
      String username, String password) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data;
      if (data is Map && data['token'] != null) {
        final rawPrivileges = data['privileges'];
        final privileges = rawPrivileges is List
            ? rawPrivileges.map((e) => e.toString()).toList()
            : <String>[];
        return (token: data['token'] as String, privileges: privileges);
      }
      throw 'Respuesta inesperada del servidor';
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          throw data['message'] as String;
        }
        throw 'Error ${e.response!.statusCode}';
      }
      throw 'No se pudo conectar al servidor';
    }
  }
}
