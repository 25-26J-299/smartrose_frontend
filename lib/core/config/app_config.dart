import 'package:flutter/foundation.dart';

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

