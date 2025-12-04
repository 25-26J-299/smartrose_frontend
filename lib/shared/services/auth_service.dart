/// Mock authentication service for SmartRose app.
/// 
/// This service simulates authentication with network delays.
/// In the future, this will be replaced with real backend API calls.
class AuthService {
  const AuthService();

  /// Simulates a login request to the backend.
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Returns `true` if login is successful (accepts any non-empty input).
  /// Returns `false` if email or password is empty.
  /// 
  /// Simulates network delay of 1.5 seconds.
  Future<bool> login(String email, String password) async {
    // Validate input
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return false;
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    // For now, accept any non-empty input
    return true;
  }

  /// Simulates a registration request to the backend.
  /// 
  /// [name] - User's full name
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Returns `true` if registration is successful (accepts any non-empty input).
  /// Returns `false` if any field is empty.
  /// 
  /// Simulates network delay of 2 seconds.
  Future<bool> register(String name, String email, String password) async {
    // Validate input
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      return false;
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 2000));

    // For now, accept any non-empty input
    return true;
  }
}


