import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.10.0.148:3000',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
          ),
        );

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<dynamic> post(String path, Map<String, dynamic> data) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return response.data;
  }

  Future<dynamic> get(String path) async {
    final response = await _dio.get<dynamic>(path);
    return response.data;
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    final response = await _dio.put<dynamic>(path, data: data);
    return response.data;
  }

  Future<dynamic> delete(String path) async {
    final response = await _dio.delete<dynamic>(path);
    return response.data;
  }
}
