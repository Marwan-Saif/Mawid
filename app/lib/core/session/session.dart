import '../../features/auth/domain/entities/app_user.dart';

/// The signed-in user and token for this run of the app. The API client reads the token
/// from here; the fake backend reads the user id to know "who is asking".
class Session {
  String? _token;
  AppUser? _user;

  String? get token => _token;
  AppUser? get user => _user;

  void set(String token, AppUser user) {
    _token = token;
    _user = user;
  }

  void clear() {
    _token = null;
    _user = null;
  }
}
