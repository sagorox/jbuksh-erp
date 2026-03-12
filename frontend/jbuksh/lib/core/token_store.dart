import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _k = "access_token";

  static Future<void> save(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, token);
  }

  static Future<String?> read() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_k);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }
}