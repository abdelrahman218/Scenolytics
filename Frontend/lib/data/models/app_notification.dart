class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.relatedId,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String? relatedId;
  final DateTime? createdAt;
  final DateTime? readAt;

  AppNotification copyWith({
    String? title,
    String? message,
    String? notificationType,
    bool? isRead,
    String? relatedId,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> raw) {
    return AppNotification(
      id: raw['id']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      message: raw['message']?.toString() ?? '',
      notificationType: raw['notification_type']?.toString() ?? '',
      isRead: coerceBoolFrom(raw['is_read']),
      relatedId: raw['related_id']?.toString(),
      createdAt: _parseDt(raw['created_at']),
      readAt: _parseDt(raw['read_at']),
    );
  }

  static bool coerceBoolFrom(Object? value) {
    if (value is bool) return value;
    final s = value?.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  static DateTime? _parseDt(Object? value) {
    if (value == null) return null;
    try {
      return DateTime.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
