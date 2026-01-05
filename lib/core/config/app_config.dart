import 'package:flutter/foundation.dart';

/// Get the default API base URL based on the platform
String getApiBaseUrl() {
  // Check if base URL is provided via environment variable
  const String envUrl = String.fromEnvironment('SMARTROSE_API_BASE');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  // Platform-specific defaults
  if (kIsWeb) {
    return 'http://localhost:8000/api/v1';
  }

  // Use defaultTargetPlatform to detect iOS vs Android
  // iOS simulator can access localhost directly
  // Android emulator needs 10.0.2.2 to access host machine
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'http://localhost:8000/api/v1';
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000/api/v1';
    default:
      // Default to localhost for other platforms (macOS, Linux, Windows)
      return 'http://localhost:8000/api/v1';
  }
}

class AppConfig {
  const AppConfig._();

  static bool _initialized = false;

  static Future<void> init({AppConfigState? appConfigState}) async {
    if (_initialized) {
      return;
    }

    // TODO: Load remote/local configuration here (env, APIs, etc.)

    _initialized = true;
    appConfigState?.markInitialized();
  }

  static bool get isInitialized => _initialized;
}

class AppConfigState extends ChangeNotifier {
  bool _initialized = false;

  bool get isInitialized => _initialized;

  void markInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    notifyListeners();
  }
}

