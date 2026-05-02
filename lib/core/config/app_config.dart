import 'package:flutter/foundation.dart';

/// Production API (used when [SMARTROSE_API_BASE] is not passed at compile time).
const String kDefaultProductionApiBase = 'https://api.smartroseiot.com/api/v1';

/// Resolves the API base URL.
///
/// Override for local backend:
/// `flutter run --dart-define=SMARTROSE_API_BASE=http://10.0.2.2:8000/api/v1` (Android emulator)
/// `flutter run --dart-define=SMARTROSE_API_BASE=http://localhost:8000/api/v1` (iOS simulator)
String getApiBaseUrl() {
  const String envUrl = String.fromEnvironment('SMARTROSE_API_BASE');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  if (kIsWeb) {
    return 'http://localhost:8000/api/v1';
  }

  // Mobile/desktop: default to production so emulator and physical devices work
  // without a server on the host (avoids 10.0.2.2 / connection refused when API is down).
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return kDefaultProductionApiBase;
    default:
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

