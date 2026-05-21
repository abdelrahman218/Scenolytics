import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'api/auth_api.dart';
import 'api/user_management_api.dart';
import 'auth_session_store.dart';
import 'models/auth_user.dart';
import '../utils/jwt_user_id.dart';

/// Holds the signed-in [AuthUser] and syncs to [AuthSessionStore].
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthSessionStore store,
    required AuthApi api,
    UserManagementApi? userManagementApi,
  })  : _store = store,
        _api = api,
        _userManagementApi = userManagementApi;

  final AuthSessionStore _store;
  final AuthApi _api;
  final UserManagementApi? _userManagementApi;

  AuthUser? _user;
  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// When true, the app shell blocks navigation until the actor profile is complete.
  bool _actorMustCompleteProfileSetup = false;
  bool get actorMustCompleteProfileSetup => _actorMustCompleteProfileSetup;

  /// When true, the app shell blocks navigation until the director profile is complete.
  bool _directorMustCompleteProfileSetup = false;
  bool get directorMustCompleteProfileSetup => _directorMustCompleteProfileSetup;

  void requireActorProfileSetup() {
    if (!_actorMustCompleteProfileSetup) {
      _actorMustCompleteProfileSetup = true;
      notifyListeners();
    }
  }

  void completeActorProfileSetup() {
    if (_actorMustCompleteProfileSetup) {
      _actorMustCompleteProfileSetup = false;
      _store.clearPendingProfileSetup();
      notifyListeners();
    }
  }

  void requireDirectorProfileSetup() {
    if (!_directorMustCompleteProfileSetup) {
      _directorMustCompleteProfileSetup = true;
      notifyListeners();
    }
  }

  void completeDirectorProfileSetup() {
    if (_directorMustCompleteProfileSetup) {
      _directorMustCompleteProfileSetup = false;
      notifyListeners();
    }
  }

  /// Set when sign-up succeeded but User Management profile row could not be confirmed.
  /// Use [consumeProfileBootstrapMessage] in UI (e.g. SnackBar) once per sign-up.
  String? _profileBootstrapMessage;
  String? consumeProfileBootstrapMessage() {
    final m = _profileBootstrapMessage;
    _profileBootstrapMessage = null;
    return m;
  }

  Future<void> hydrate() async {
    _user = await _store.load();
    final pending = await _store.loadPendingProfileSetup();
    if (pending == 'actor') {
      _actorMustCompleteProfileSetup = true;
    } else if (pending == 'director') {
      _directorMustCompleteProfileSetup = true;
    }
    notifyListeners();
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final u = await _api.logIn(email: email, password: password);
    _user = u;
    await _store.save(u);
    notifyListeners();
  }

  /// Offline dev login: uses a JWT already supplied via `--dart-define` (e.g. from `.env`).
  /// Does not call the identity API. [email] is a placeholder for UI only.
  Future<void> signInWithPreconfiguredJwt({
    required String token,
    required String role,
    String email = 'dev@local',
  }) async {
    final t = token.trim();
    if (t.isEmpty) {
      throw AuthApiException('No JWT configured for this role.');
    }
    final userId = userIdFromActorJwt(t);
    if (userId == null || userId.isEmpty) {
      throw AuthApiException(
        'Could not read user id from JWT. Check the token payload.',
      );
    }
    final r = role.trim().toLowerCase();
    if (r != 'actor' && r != 'director') {
      throw AuthApiException('Dev login only supports actor or director roles.');
    }
    final u = AuthUser(token: t, userId: userId, email: email.trim(), role: r);
    _user = u;
    await _store.save(u);
    notifyListeners();
  }

  /// Registers, signs in with the same password, then best-effort seeds the
  /// User Management profile with the name (and actor-only age/gender).
  ///
  /// Profile bootstrap failures are logged but do **not** fail the sign-up: the
  /// user is still signed in and the Profile page can re-create the row.
  Future<void> signUpAndSignIn({
    required String email,
    required String password,
    required String role,
    required String name,
    int? age,
    String? gender,
  }) async {
    await _api.signUp(
      email: email,
      password: password,
      role: role,
      name: name,
      age: age,
      gender: gender,
    );

    // Set before sign-in (no notify — user is still null) so the shell sees the
    // gate on first build after [signInWithPassword].
    final signedUpRole = role.trim().toLowerCase();
    if (signedUpRole == 'actor') {
      _actorMustCompleteProfileSetup = true;
      await _store.savePendingProfileSetup('actor');
    } else if (signedUpRole == 'director') {
      _directorMustCompleteProfileSetup = true;
      await _store.savePendingProfileSetup('director');
    }

    await signInWithPassword(email: email, password: password);

    _profileBootstrapMessage = null;
    final signedIn = _user;
    final um = _userManagementApi;
    if (signedIn != null && um != null) {
      try {
        if (signedUpRole == 'actor') {
          final profileFields = <String, dynamic>{
            'name': name.trim(),
            if (age != null) 'age': age,
          };
          final g = gender?.trim();
          if (g != null &&
              g.isNotEmpty &&
              const {'Male', 'Female'}.contains(g)) {
            profileFields['gender'] = g;
          }
          try {
            await um.createActorProfile(
              userId: signedIn.userId,
              fields: profileFields,
              bearerToken: signedIn.token,
            );
          } on UserManagementApiException catch (e) {
            final m = e.message.toLowerCase();
            final duplicate = m.contains('duplicate') ||
                m.contains('already exists') ||
                m.contains('unique') ||
                e.statusCode == 409;
            if (!duplicate) rethrow;
          }
        } else if (signedUpRole == 'director') {
          try {
            await um.createDirectorProfile(
              userId: signedIn.userId,
              fields: <String, dynamic>{
                'name': name.trim(),
              },
              bearerToken: signedIn.token,
            );
          } on UserManagementApiException catch (e) {
            final m = e.message.toLowerCase();
            final duplicate = m.contains('duplicate') ||
                m.contains('already exists') ||
                m.contains('unique') ||
                e.statusCode == 409;
            if (!duplicate) rethrow;
          }
        }
      } catch (e, st) {
        developer.log(
          'Post-signup profile bootstrap failed (non-fatal)',
          name: 'AuthController',
          error: e,
          stackTrace: st,
        );
        var recovered = false;
        if (signedUpRole == 'actor') {
          final row = await um.getActorProfile(
            signedIn.userId,
            bearerToken: signedIn.token,
          );
          recovered = row != null;
        } else if (signedUpRole == 'director') {
          final row = await um.getDirectorProfile(
            signedIn.userId,
            bearerToken: signedIn.token,
          );
          recovered = row != null;
        }
        if (!recovered) {
          final hint = e is UserManagementApiException
              ? e.message
              : e.toString();
          _profileBootstrapMessage =
              'Your account was created, but the profile row was not saved. '
              'Open Profile to try again. ($hint)';
        }
      }
    }
  }

  Future<void> signOut() async {
    _actorMustCompleteProfileSetup = false;
    _directorMustCompleteProfileSetup = false;
    _user = null;
    await _store.clear();
    notifyListeners();
  }

  /// Role that still owes mandatory profile fields (`actor` / `director`), if any.
  String? get pendingProfileSetupRole {
    if (_actorMustCompleteProfileSetup) return 'actor';
    if (_directorMustCompleteProfileSetup) return 'director';
    return null;
  }
}
