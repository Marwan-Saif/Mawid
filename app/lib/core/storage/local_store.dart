import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value store for the session and the chosen language.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';
  static const _localeKey = 'app.locale';

  String? get token => _prefs.getString(_tokenKey);

  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> clearSession() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  String? get localeCode => _prefs.getString(_localeKey);

  Future<void> saveLocale(String code) => _prefs.setString(_localeKey, code);
}
