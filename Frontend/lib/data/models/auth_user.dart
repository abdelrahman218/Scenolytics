class AuthUser {
  const AuthUser({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
  });

  final String token;
  final String userId;
  final String email;
  final String role;

  String get normalizedRole => role.trim().toLowerCase();
  bool get isActor => normalizedRole == 'actor';
  bool get isDirector => normalizedRole == 'director';
}
