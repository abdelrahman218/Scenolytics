import 'app_notification.dart';

/// Matches notification DB preferences (camelCase mirrors JSON from API).
class NotificationPreferences {
  const NotificationPreferences({
    required this.inAppSubmissionNotifications,
    required this.inAppInvitationNotifications,
    required this.emailSubmissionNotifications,
    required this.emailInvitationNotifications,
  });

  final bool inAppSubmissionNotifications;
  final bool inAppInvitationNotifications;
  final bool emailSubmissionNotifications;
  final bool emailInvitationNotifications;

  factory NotificationPreferences.defaults() => const NotificationPreferences(
        inAppSubmissionNotifications: true,
        inAppInvitationNotifications: true,
        emailSubmissionNotifications: true,
        emailInvitationNotifications: true,
      );

  factory NotificationPreferences.fromJson(Map<String, dynamic> raw) {
    return NotificationPreferences(
      inAppSubmissionNotifications: AppNotification.coerceBoolFrom(
        raw['in_app_submission_notifications'],
      ),
      inAppInvitationNotifications: AppNotification.coerceBoolFrom(
        raw['in_app_invitation_notifications'],
      ),
      emailSubmissionNotifications: AppNotification.coerceBoolFrom(
        raw['email_submission_notifications'],
      ),
      emailInvitationNotifications: AppNotification.coerceBoolFrom(
        raw['email_invitation_notifications'],
      ),
    );
  }

  NotificationPreferences copyWith({
    bool? inAppSubmissionNotifications,
    bool? inAppInvitationNotifications,
    bool? emailSubmissionNotifications,
    bool? emailInvitationNotifications,
  }) {
    return NotificationPreferences(
      inAppSubmissionNotifications:
          inAppSubmissionNotifications ?? this.inAppSubmissionNotifications,
      inAppInvitationNotifications:
          inAppInvitationNotifications ?? this.inAppInvitationNotifications,
      emailSubmissionNotifications:
          emailSubmissionNotifications ?? this.emailSubmissionNotifications,
      emailInvitationNotifications:
          emailInvitationNotifications ?? this.emailInvitationNotifications,
    );
  }

  Map<String, String> toPatchBodySendingStrings() {
    // Backend treats boolean `false` as "missing"; use non-empty `'0'`/`'1'` strings.
    String bit(bool v) => v ? '1' : '0';
    return <String, String>{
      'in_app_submission_notifications': bit(inAppSubmissionNotifications),
      'in_app_invitation_notifications': bit(inAppInvitationNotifications),
      'email_submission_notifications': bit(emailSubmissionNotifications),
      'email_invitation_notifications': bit(emailInvitationNotifications),
    };
  }
}
