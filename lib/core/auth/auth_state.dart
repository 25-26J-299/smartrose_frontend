import 'package:flutter/foundation.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';

/// Auth state backed by the API + secure storage.
class AuthState extends ChangeNotifier {
  AuthState({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  User? _user;
  String? _token;
  String? _errorMessage;
  bool _initializing = true;

  User? get user => _user;
  List<String> get roles => _user?.roles ?? <String>[];
  bool get isAuthenticated => _token != null;
  bool get isInitializing => _initializing;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    try {
      _token = await _authService.loadToken();
      if (_token != null) {
        try {
          _user = await _authService.fetchProfile(_token!);
          if (_user == null) {
            await _authService.clearToken();
            _token = null;
          }
        } catch (e) {
          // If profile fetch fails, clear token and continue
          debugPrint('Error fetching profile: $e');
          await _authService.clearToken();
          _token = null;
        }
      }
    } catch (e) {
      // If token loading fails, continue without authentication
      debugPrint('Error restoring session: $e');
      _token = null;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _errorMessage = null;
    final AuthResult? result =
        await _authService.register(name, email, password);
    if (result == null) {
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }

    _user = result.user;
    _token = result.token;
    notifyListeners();
    return true;
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    try {
      final AuthResult? result = await _authService.login(email, password);
      if (result == null) {
        _errorMessage = 'Invalid credentials. Please try again.';
        notifyListeners();
        return false;
      }
      _user = result.user;
      _token = result.token;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error in AuthState: $e');
      _errorMessage = 'Network error. Please check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRoles(List<String> newRoles) async {
    _errorMessage = null;
    if (_token == null) {
      _errorMessage = 'You must be logged in to update roles.';
      notifyListeners();
      return false;
    }

    final AuthResult? result =
        await _authService.updateRoles(newRoles, _token!);
    if (result == null) {
      _errorMessage = 'Failed to update roles.';
      notifyListeners();
      return false;
    }

    _user = result.user;
    _token = result.token;
    notifyListeners();
    return true;
  }

  void updateProfileLocal({String? name, String? email}) {
    if (_user == null) return;
    _user = User(
      id: _user!.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : _user!.name,
      email: email?.trim().isNotEmpty == true ? email!.trim() : _user!.email,
      roles: _user!.roles,
      createdAt: _user!.createdAt,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.clearToken();
    _user = null;
    _token = null;
    notifyListeners();
  }
}


