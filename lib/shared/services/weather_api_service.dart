import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

import 'location_service.dart';

class WeatherModel {
  const WeatherModel({
    required this.temperature,
    required this.highTemp,
    required this.lowTemp,
    required this.humidity,
    required this.precipitation,
    required this.pressure,
    required this.windSpeed,
    required this.condition,
    required this.sunrise,
    required this.sunset,
    this.icon,
    this.locationName,
  });

  final double temperature;
  final double highTemp;
  final double lowTemp;
  final double humidity;
  final double precipitation;
  final double pressure;
  final double windSpeed;
  final String condition;
  final String sunrise;
  final String sunset;
  final String? icon;
  final String? locationName;

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    // Format time from Unix timestamp or string
    String formatTime(dynamic time) {
      if (time is int) {
        // Unix timestamp
        final dateTime = DateTime.fromMillisecondsSinceEpoch(time * 1000);
        return DateFormat('h:mm a').format(dateTime);
      } else if (time is String) {
        if (time.contains('AM') || time.contains('PM')) {
          return time;
        }
      }
      return time.toString();
    }

    // Handle OpenWeatherMap response structure
    final main = json['main'] ?? <String, dynamic>{};
    final weather = (json['weather'] as List?)?.first ?? <String, dynamic>{};
    final sys = json['sys'] ?? <String, dynamic>{};
    final wind = json['wind'] ?? <String, dynamic>{};
    final rain = json['rain'] ?? <String, dynamic>{};
    
    // Extract location name - OpenWeatherMap provides city name in 'name' field
    // Also try to get country from sys.country
    String? locationName;
    final String? cityName = json['name'] as String?;
    final String? countryCode = sys['country'] as String?;
    
    if (cityName != null && cityName.isNotEmpty) {
      if (countryCode != null && countryCode.isNotEmpty) {
        locationName = '$cityName, $countryCode';
      } else {
        locationName = cityName;
      }
    }

    return WeatherModel(
      temperature: (main['temp'] ?? 0).toDouble(),
      highTemp: (main['temp_max'] ?? main['temp'] ?? 0).toDouble(),
      lowTemp: (main['temp_min'] ?? main['temp'] ?? 0).toDouble(),
      humidity: (main['humidity'] ?? 0).toDouble(),
      precipitation: (rain['1h'] ?? rain['3h'] ?? 0).toDouble(),
      pressure: (main['pressure'] ?? 1013).toDouble(),
      windSpeed: ((wind['speed'] ?? 0) * 3.6).toDouble(), // Convert m/s to km/h
      condition: weather['main'] ?? 'Clear',
      sunrise: formatTime(sys['sunrise'] ?? '6:00'),
      sunset: formatTime(sys['sunset'] ?? '18:00'),
      icon: weather['icon'],
      locationName: locationName,
    );
  }

  IconData getConditionIcon() {
    final String lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('clear')) {
      return Icons.wb_sunny_rounded;
    } else if (lowerCondition.contains('cloud')) {
      return Icons.wb_cloudy_rounded;
    } else if (lowerCondition.contains('rain') ||
        lowerCondition.contains('drizzle')) {
      return Icons.grain_rounded;
    } else if (lowerCondition.contains('storm') ||
        lowerCondition.contains('thunder')) {
      return Icons.flash_on_rounded;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit_rounded;
    } else if (lowerCondition.contains('mist') ||
        lowerCondition.contains('fog')) {
      return Icons.blur_on_rounded;
    }
    return Icons.wb_sunny_rounded;
  }
}

class WeatherApiService {
  WeatherApiService({
    http.Client? client,
    LocationService? locationService,
  })  : _client = client ?? http.Client(),
        _locationService = locationService ?? LocationService();

  final http.Client _client;
  final LocationService _locationService;
  static const String _apiKey = '7f8d76675aeb296c6e19984412b1b126';

  // Default location (Colombo, Sri Lanka) - fallback if location unavailable
  static const double _defaultLatitude = 6.9271;
  static const double _defaultLongitude = 79.8612;

  Future<WeatherModel?> fetchCurrentWeather({double? lat, double? lon}) async {
    try {
      double latitude;
      double longitude;
      bool usingDefaultLocation = false;

      // Use provided coordinates, or get current location, or use default
      if (lat != null && lon != null) {
        latitude = lat;
        longitude = lon;
        debugPrint('📍 Using provided coordinates: $latitude, $longitude');
      } else {
        // Try to get current location
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          debugPrint('📍 Using current location: $latitude, $longitude');
        } else {
          // Fallback to default location
          latitude = _defaultLatitude;
          longitude = _defaultLongitude;
          usingDefaultLocation = true;
          debugPrint('📍 Using default location (Colombo, Sri Lanka): $latitude, $longitude');
        }
      }

      // OpenWeatherMap API endpoint
      // Get free API key from: https://openweathermap.org/api
      final Uri uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      debugPrint('🌤️ Fetching weather from: $uri');

      final response = await _client
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Weather API request timed out');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Weather data received successfully');
        WeatherModel weather = WeatherModel.fromJson(data);
        
        // If location name is not in the response, try reverse geocoding
        if (weather.locationName == null || weather.locationName!.isEmpty) {
          final String? locationName = await _getLocationName(latitude, longitude);
          if (locationName != null) {
            // Create a new WeatherModel with the location name
            weather = WeatherModel(
              temperature: weather.temperature,
              highTemp: weather.highTemp,
              lowTemp: weather.lowTemp,
              humidity: weather.humidity,
              precipitation: weather.precipitation,
              pressure: weather.pressure,
              windSpeed: weather.windSpeed,
              condition: weather.condition,
              sunrise: weather.sunrise,
              sunset: weather.sunset,
              icon: weather.icon,
              locationName: locationName,
            );
          } else if (usingDefaultLocation) {
            // Use default location name if reverse geocoding fails and we're using default coordinates
            weather = WeatherModel(
              temperature: weather.temperature,
              highTemp: weather.highTemp,
              lowTemp: weather.lowTemp,
              humidity: weather.humidity,
              precipitation: weather.precipitation,
              pressure: weather.pressure,
              windSpeed: weather.windSpeed,
              condition: weather.condition,
              sunrise: weather.sunrise,
              sunset: weather.sunset,
              icon: weather.icon,
              locationName: 'Colombo, Sri Lanka',
            );
          }
        }
        
        return weather;
      } else {
        final errorBody = response.body;
        debugPrint(
          '❌ Weather API error: ${response.statusCode} - $errorBody',
        );
        // Check if it's an API key error
        if (response.statusCode == 401) {
          debugPrint('⚠️ Invalid API key. Please check your OpenWeatherMap API key.');
        }
        // Return null to let the UI show error state
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ WeatherApiService.fetchCurrentWeather error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Return null to let the UI show error state
      return null;
    }
  }

  /// Get location name from coordinates using reverse geocoding
  /// Uses OpenStreetMap Nominatim API (free, no API key required)
  Future<String?> _getLocationName(double lat, double lon) async {
    try {
      final Uri uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1',
      );

      final response = await _client
          .get(
            uri,
            headers: <String, String>{
              'User-Agent': 'SmartRose Weather App',
            },
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Reverse geocoding request timed out');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic>? address = data['address'] as Map<String, dynamic>?;
        
        if (address != null) {
          // Try to get city name, fallback to other location names
          final String? city = address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['municipality'] as String?;
          final String? state = address['state'] as String?;
          final String? country = address['country'] as String?;
          
          if (city != null && city.isNotEmpty) {
            if (country != null && country.isNotEmpty) {
              return '$city, $country';
            }
            return city;
          } else if (state != null && state.isNotEmpty) {
            if (country != null && country.isNotEmpty) {
              return '$state, $country';
            }
            return state;
          } else if (country != null && country.isNotEmpty) {
            return country;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Reverse geocoding failed: $e');
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}
