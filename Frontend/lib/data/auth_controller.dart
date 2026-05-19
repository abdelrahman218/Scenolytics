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

  /// True for one read after a successful sign-up + auto-sign-in. Used by the app
  /// shell to redirect the user straight to the profile page on first render.
  bool _justSignedUp = false;
  bool consumeJustSignedUpFlag() {
    final v = _justSignedUp;
    _justSignedUp = false;
    return v;
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
    await signInWithPassword(email: email, password: password);

    _profileBootstrapMessage = null;
    final signedIn = _user;
    final um = _userManagementApi;
    if (signedIn != null && um != null) {
      try {
        if (signedIn.isActor) {
          final profileFields = <String, dynamic>{
            // User Management `createActorProfile` maps `name` → `display_name`.
            'name': name.trim(),
            if (age != null) 'age': age,
          };
          final g = gender?.trim();
          if (g != null &&
              g.isNotEmpty &&
              const {'Male', 'Female', 'Other'}.contains(g)) {
            profileFields['gender'] = g;
          }
          await um.createActorProfile(
            userId: signedIn.userId,
            fields: profileFields,
            bearerToken: signedIn.token,
          );
        } else if (signedIn.isDirector) {
          await um.createDirectorProfile(
            userId: signedIn.userId,
            fields: <String, dynamic>{
              'name': name.trim(),
            },
            bearerToken: signedIn.token,
          );
        }
      } catch (e, st) {
        developer.log(
          'Post-signup profile bootstrap failed (non-fatal)',
          name: 'AuthController',
          error: e,
          stackTrace: st,
        );
        // Row may already exist (e.g. RabbitMQ `USER_CREATED` beat us) or duplicate INSERT.
        var recovered = false;
        if (signedIn.isActor) {
          final row = await um.getActorProfile(
            signedIn.userId,
            bearerToken: signedIn.token,
          );
          recovered = row != null;
        } else if (signedIn.isDirector) {
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

    _justSignedUp = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _user = null;
    await _store.clear();
    notifyListeners();
  }
}
