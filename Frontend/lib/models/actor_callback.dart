import 'callback_status.dart';

/// One row from casting `GET /api/v1/casting/actor/callbacks`.
class ActorCallbackInfo {
  const ActorCallbackInfo({
    required this.auditionId,
    this.callbackStatus = CallbackStatus.scheduled,
    this.callbackDatetime,
    this.link,
    this.createdAt,
  });

  final String auditionId;
  final CallbackStatus callbackStatus;
  final DateTime? callbackDatetime;

  /// Meet / calendar join URL when the director linked Google Calendar.
  final String? link;

  final DateTime? createdAt;

  static ActorCallbackInfo? tryParse(Map<String, dynamic> raw) {
    final aid = raw['audition_id']?.toString().trim() ?? '';
    if (aid.isEmpty) return null;
    final linkRaw = raw['link']?.toString().trim() ?? '';
    return ActorCallbackInfo(
      auditionId: aid,
      callbackStatus: parseCallbackStatus(raw['callback_status']),
      link: linkRaw.isEmpty ? null : linkRaw,
      callbackDatetime: _parseFlexibleDt(raw['callback_datetime']),
      createdAt: _parseFlexibleDt(raw['created_at']),
    );
  }

  static DateTime? _parseFlexibleDt(Object? v) => parseMysqlFlexibleDateTime(v);
}

/// Director view of `GET …/director/auditions/:id/callbacks` (keyed by submission id).
class DirectorAuditionCallback {
  const DirectorAuditionCallback({
    required this.id,
    required this.auditionSubmissionId,
    required this.status,
    this.callbackDatetime,
    this.link,
  });

  final String id;
  final String auditionSubmissionId;
  final CallbackStatus status;
  final DateTime? callbackDatetime;
  final String? link;

  static DirectorAuditionCallback? tryParse(Map<String, dynamic> raw) {
    final id = raw['id']?.toString().trim() ?? '';
    final sid = raw['audition_submission_id']?.toString().trim() ?? '';
    if (id.isEmpty || sid.isEmpty) return null;
    final linkRaw = raw['link']?.toString().trim() ?? '';
    return DirectorAuditionCallback(
      id: id,
      auditionSubmissionId: sid,
      status: parseCallbackStatus(raw['callback_status']),
      callbackDatetime: parseMysqlFlexibleDateTime(raw['callback_datetime']),
      link: linkRaw.isEmpty ? null : linkRaw,
    );
  }
}

DateTime? parseMysqlFlexibleDateTime(Object? v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}
