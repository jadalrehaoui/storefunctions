import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.10.0.130:3000',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
          ),
        );

  Future<dynamic> post(String path, Map<String, dynamic> data) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return response.data;
  }
}
