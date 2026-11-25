

class AuthStorage {
  AuthStorage._();
  static final AuthStorage _instance = AuthStorage._();
  static AuthStorage get instance => _instance;

  String? _token;


  static String? get token => _instance._token;


  static void setToken(String? token) {
    _instance._token = token;
  }

  /// Dipanggil oleh AuthProvider saat logout.
  static void clear() {
    _instance._token = null;
  }
}
