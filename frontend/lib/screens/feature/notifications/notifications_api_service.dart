import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:jbuksh/core/offline_cache.dart';

import 'notification_model.dart';

class NotificationsApiService {
  final String baseUrl;
  final Future<String?> Function() tokenProvider;

  NotificationsApiService({
    required this.baseUrl,
    required this.tokenProvider,
  });

  Future<NotificationListResponse> fetchNotifications() async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/notifications');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final data = _decode(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['message']?.toString() ?? 'Failed to load notifications');
      }

      final rows = (data['notifications'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      await _cacheRows(rows);
      return NotificationListResponse.fromJson(data);
    } on SocketException {
      return NotificationListResponse.fromJson(
        OfflineCache.forPath('/api/v1/notifications'),
      );
    }
  }

  Future<void> markRead(int id) async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$id/read');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final data = _decode(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['message']?.toString() ?? 'Failed to mark notification as read');
      }
    } on SocketException {
      // fall through to local update
    }

    await _markReadLocal(id);
  }

  Future<void> markAllRead() async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/notifications/read-all');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final data = _decode(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['message']?.toString() ?? 'Failed to mark all notifications as read');
      }
    } on SocketException {
      // fall through to local update
    }

    await _markAllReadLocal();
  }

  Future<void> _cacheRows(List<Map<String, dynamic>> rows) async {
    if (!Hive.isBoxOpen('notifications')) return;
    final box = Hive.box('notifications');
    for (final row in rows) {
      await box.put('${row['id'] ?? row['created_at']}', row);
    }
  }

  Future<void> _markReadLocal(int id) async {
    if (!Hive.isBoxOpen('notifications')) return;
    final box = Hive.box('notifications');
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is! Map) continue;
      final row = v.cast<String, dynamic>();
      if ('${row['id'] ?? ''}' == '$id') {
        row['is_read'] = 1;
        row['read_at'] = DateTime.now().toIso8601String();
        await box.put(key, row);
        return;
      }
    }
  }

  Future<void> _markAllReadLocal() async {
    if (!Hive.isBoxOpen('notifications')) return;
    final box = Hive.box('notifications');
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is! Map) continue;
      final row = v.cast<String, dynamic>();
      row['is_read'] = 1;
      row['read_at'] = DateTime.now().toIso8601String();
      await box.put(key, row);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
