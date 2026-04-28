import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';

const _kToken = 'scenolytics.auth.token';
const _kUserId = 'scenolytics.auth.userId';
const _kEmail = 'scenolytics.auth.email';
const _kRole = 'scenolytics.auth.role';

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
  }
}
