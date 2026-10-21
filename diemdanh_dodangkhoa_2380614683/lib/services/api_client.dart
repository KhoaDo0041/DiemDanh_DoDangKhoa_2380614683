import 'dart:async';
import 'dart:convert';

import 'package:diemdanh_dodangkhoa_2380614683/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lỗi trả về từ API (kèm mã HTTP và dữ liệu gốc)
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.data});

  final int statusCode; // 0 = không kết nối được
  final String message;
  final dynamic data;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Gọi API: tự gắn token "Authorization: Bearer ...", tự đọc JSON, tự báo lỗi tiếng Việt
class ApiClient {
  static const tokenKey = 'jwt_token';

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  static Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    var uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      final Future<http.Response> future = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: encoded),
        'PUT' => http.put(uri, headers: headers, body: encoded),
        _ => http.delete(uri, headers: headers),
      };
      res = await future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(0, 'Server không phản hồi - kiểm tra API đã chạy và BASE_URL trong .env');
    } catch (e) {
      throw ApiException(0, 'Không kết nối được server (${AppConfig.baseUrl})');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = res.body;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(res.statusCode, _message(res.statusCode, data), data: data);
  }

  static String _message(int code, dynamic data) {
    if (data is Map) {
      if (data['message'] is String) return data['message'];
      // Lỗi kiểm tra dữ liệu của ASP.NET: { errors: { Email: ["..."] } }
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['title'] is String) return data['title'];
    }
    return switch (code) {
      401 => 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
      403 => 'Bạn không có quyền thực hiện chức năng này',
      404 => 'Không tìm thấy dữ liệu',
      423 => 'Tài khoản đang tạm khóa',
      _ => 'Lỗi máy chủ ($code)',
    };
  }
}
