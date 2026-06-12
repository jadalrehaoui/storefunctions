import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static const String remoteBaseUrl = 'https://jads-mac-mini.tail2ce668.ts.net';
  static const String localBaseUrl = 'http://10.10.0.130:8081';
  static const String devBaseUrl = 'http://localhost:8082';

  // Environment selection:
  //   • debug builds (`flutter run`)            -> dev  (local API on :8082)
  //   • release builds (`flutter build` / CI)   -> prod (the live mini)
  //   • override either way: --dart-define=APP_ENV=dev|prod
  // Result: shipped/release builds are always production, local runs default to dev,
  // and `flutter run --dart-define=APP_ENV=prod` runs prod on your Mac.
  static const String _envOverride = String.fromEnvironment('APP_ENV');
  static bool get isDev =>
      _envOverride.isNotEmpty ? _envOverride == 'dev' : kDebugMode;

  static String currentBaseUrl = isDev ? devBaseUrl : localBaseUrl;

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

  Future<dynamic> postMultipart(String path, FormData data) async {
    final response = await _dio.post<dynamic>(
      path,
      data: data,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
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
