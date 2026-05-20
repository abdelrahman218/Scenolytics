import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';

const _kToken = 'scenolytics.auth.token';
const _kUserId = 'scenolytics.auth.userId';
const _kEmail = 'scenolytics.auth.email';
const _kRole = 'scenolytics.auth.role';
/// `actor` or `director` while mandatory profile setup is pending after sign-up.
const _kPendingProfileSetup = 'scenolytics.auth.pendingProfileSetup';

/// Persists the Identity Provider session on device (mobile + web).
class AuthSessionStore {
  const AuthSessionStore();

  Future<AuthUser?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken)?.trim() ?? '';
    final userId = prefs.getString(_kUserId)?.trim() ?? '';
    final email = prefs.getString(_kEmail)?.trim() ?? '';
    final role = prefs.getString(_kRole)?.trim() ?? '';
    if (token.isEmpty || userId.isEmpty || email.isEmpty || role.isEmpty) {
      return null;
    }
    return AuthUser(
      token: token,
      userId: userId,
      email: email,
      role: role,
    );
  }

  Future<void> save(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, user.token);
    await prefs.setString(_kUserId, user.userId);
    await prefs.setString(_kEmail, user.email);
    await prefs.setString(_kRole, user.role);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kRole);
    await prefs.remove(_kPendingProfileSetup);
  }

  /// Persists which role still owes mandatory profile fields after sign-up.
  Future<void> savePendingProfileSetup(String role) async {
    final r = role.trim().toLowerCase();
    if (r != 'actor' && r != 'director') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingProfileSetup, r);
  }

  Future<String?> loadPendingProfileSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString(_kPendingProfileSetup)?.trim().toLowerCase() ?? '';
    if (r == 'actor' || r == 'director') return r;
    return null;
  }

  Future<void> clearPendingProfileSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingProfileSetup);
  }
}
