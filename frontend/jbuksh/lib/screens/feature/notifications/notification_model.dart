class NotificationItem {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final String? refType;
  final int? refId;
  final int isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.refType,
    required this.refId,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  bool get unread => isRead == 0;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'SYSTEM').toString(),
      refType: json['ref_type']?.toString(),
      refId: json['ref_id'] == null ? null : _toInt(json['ref_id']),
      isRead: _toInt(json['is_read']),
      readAt: _toDateTime(json['read_at']),
      createdAt: _toDateTime(json['created_at']),
    );
  }

  NotificationItem copyWith({
    int? id,
    int? userId,
    String? title,
    String? body,
    String? type,
    String? refType,
    int? refId,
    int? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      refType: refType ?? this.refType,
      refId: refId ?? this.refId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class NotificationListResponse {
  final bool ok;
  final int unreadCount;
  final List<NotificationItem> notifications;

  NotificationListResponse({
    required this.ok,
    required this.unreadCount,
    required this.notifications,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['notifications'] as List<dynamic>? ?? [])
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return NotificationListResponse(
      ok: json['ok'] == true,
      unreadCount: NotificationItem._toInt(json['unread_count']),
      notifications: list,
    );
  }
}