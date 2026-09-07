import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Your Mac's LAN address — works over WiFi as long as the phone and Mac
// are on the same network. Update this if your Mac's IP changes (check with
// `ipconfig getifaddr en0`).
const String _baseUrl = 'http://192.168.86.243:5000/api';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'knightmarket', publicKey: 'knightmarket_key'),
  );
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path, {dynamic data}) => _dio.delete(path, data: data);

  Future<Response> postMultipart(String path, FormData formData) =>
      _dio.post(path, data: formData);

  Future<Response> putMultipart(String path, FormData formData) =>
      _dio.put(path, data: formData);

  Future<void> saveToken(String token) =>
      _storage.write(key: 'token', value: token);

  Future<void> clearToken() => _storage.deleteAll();

  Future<String?> getToken() => _storage.read(key: 'token');
}
