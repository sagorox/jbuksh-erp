import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jbuksh/core/offline_cache.dart';
import 'token_store.dart';

class AuthClient {
  static Future<http.Response> get(Uri url) async {
    final token = await TokenStore.read();
    try {
      return await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    } catch (_) {
      return http.Response(jsonEncode(OfflineCache.forPath(url.toString())), 200, headers: {'content-type': 'application/json'});
    }
  }

  static Future<http.Response> post(Uri url, {Object? body}) async {
    final token = await TokenStore.read();
    return http.post(url, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    }, body: body == null ? null : jsonEncode(body));
  }
}
