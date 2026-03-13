import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'offline_cache.dart';

class Api {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.106:3000',
  );

  static String get baseUrl {
    final settings = Hive.isBoxOpen('settings') ? Hive.box('settings') : null;
    final custom = settings?.get('api_base_url')?.toString().trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return _defaultBaseUrl;
  }

  static String? _token() {
    final auth = Hive.box('auth');
    return auth.get('token');
  }

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = _token();
      if (t != null) {
        h['Authorization'] = 'Bearer $t';
      }
    }
    return h;
  }

  static dynamic _decodeBody(http.Response res) {
    if (res.body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(res.body);
  }

  static Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map) {
      return body.cast<String, dynamic>();
    }
    if (body is List) {
      return {'items': body};
    }
    return {'data': body};
  }

  static bool _isOfflineLike(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is HttpException;
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        throw Exception('Unauthorized (401): Please login again.');
      }
      final body = _decodeBody(res);
      if (res.statusCode >= 400) {
        throw Exception(
          body is Map && body['message'] != null
              ? body['message']
              : 'GET failed',
        );
      }
      return _asMap(body);
    } catch (e) {
      if (_isOfflineLike(e)) {
        return OfflineCache.forPath(path);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload, {
    bool auth = true,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(auth: auth),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      throw Exception('Unauthorized (401): Please login again.');
    }
    final body = _decodeBody(res);
    if (res.statusCode >= 400) {
      throw Exception(
        body is Map && body['message'] != null ? body['message'] : 'POST failed',
      );
    }
    return _asMap(body);
  }

  static Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> payload, {
    bool auth = true,
  }) async {
    final res = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers(auth: auth),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      throw Exception('Unauthorized (401): Please login again.');
    }
    final body = _decodeBody(res);
    if (res.statusCode >= 400) {
      throw Exception(
        body is Map && body['message'] != null ? body['message'] : 'PUT failed',
      );
    }
    return _asMap(body);
  }

  static Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> payload, {
    bool auth = true,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers(auth: auth),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      throw Exception('Unauthorized (401): Please login again.');
    }
    final body = _decodeBody(res);
    if (res.statusCode >= 400) {
      throw Exception(
        body is Map && body['message'] != null
            ? body['message']
            : 'PATCH failed',
      );
    }
    return _asMap(body);
  }
}
