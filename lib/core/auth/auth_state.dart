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
  String? get role => _user?.role;
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
          debugPrint('Error fetching profile: $e');
          await _authService.clearToken();
          _token = null;
        }
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      _token = null;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  /// Register with full_name, email, phone, password, role (farmer|florist), and location.
  /// Returns true if registration succeeded. With new backend, no token is returned
  /// so user must be approved before login.
  Future<bool> register(
    String fullName,
    String email,
    String phone,
    String password,
    String role, {
    required String locationName,
    required String locationType,
    required String locationAddress,
  }) async {
    _errorMessage = null;
    try {
      final AuthResult? result = await _authService.register(
        fullName,
        email,
        phone,
        password,
        role,
        locationName: locationName,
        locationType: locationType,
        locationAddress: locationAddress,
      );
      if (result != null) {
        _user = result.user;
        _token = result.token;
        notifyListeners();
        return true;
      }
      // New flow: registration succeeded but no token (pending approval)
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
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
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

    final AuthResult? result = await _authService.updateRoles(
      newRoles,
      _token!,
    );
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

  void updateProfileLocal({
    String? fullName,
    String? name,
    String? email,
    String? phone,
  }) {
    if (_user == null) return;
    final newFullName = fullName ?? name;
    _user = User(
      id: _user!.id,
      fullName: newFullName?.trim().isNotEmpty == true ? newFullName!.trim() : _user!.fullName,
      email: email?.trim().isNotEmpty == true ? email!.trim() : _user!.email,
      phone: phone ?? _user!.phone,
      role: _user!.role,
      status: _user!.status,
      createdAt: _user!.createdAt,
      lastLogin: _user!.lastLogin,
      isActive: _user!.isActive,
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
