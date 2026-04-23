import 'package:dio/dio.dart';

class ApiClient {
  static const String remoteBaseUrl = 'https://jads-mac-mini.tail2ce668.ts.net';
  static const String localBaseUrl = 'http://10.10.0.130:8081';
  static String currentBaseUrl = localBaseUrl;

  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: currentBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
          ),
        );

  void setBaseUrl(String url) {
    currentBaseUrl = url;
    _dio.options.baseUrl = url;
  }

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

  Future<dynamic> deleteWithBody(String path, Map<String, dynamic> data) async {
    final response = await _dio.delete<dynamic>(path, data: data);
    return response.data;
  }

  Future<ResponseBody> getStream(String path) async {
    final response = await _dio.get<ResponseBody>(
      path,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        receiveTimeout: Duration.zero,
      ),
    );
    return response.data!;
  }
}
