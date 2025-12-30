import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

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
  WeatherApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _apiKey = 'AIzaSyBd1Kp8V_zDxCBqFHEvRmkdCAKy6Fru4MM';

  Future<WeatherModel?> fetchCurrentWeather({double? lat, double? lon}) async {
    try {
      // Default location (Colombo, Sri Lanka) - you can get from device location using Google API
      final latitude = lat ?? 6.9271;
      final longitude = lon ?? 79.8612;

      // OpenWeatherMap API endpoint
      // Get free API key from: https://openweathermap.org/api
      final Uri uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      debugPrint('🌤️ Fetching weather from: $uri');

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Weather data received: $data');
        return WeatherModel.fromJson(data);
      } else {
        debugPrint(
          '❌ Weather API error: ${response.statusCode} - ${response.body}',
        );
        // Return mock data if API fails (fallback)
        return _getMockWeather();
      }
    } catch (e) {
      debugPrint('❌ WeatherApiService.fetchCurrentWeather error: $e');
      // Return mock data as fallback
      return _getMockWeather();
    }
  }

  WeatherModel _getMockWeather() {
    final now = DateTime.now();
    return WeatherModel(
      temperature: 26.5,
      highTemp: 30.0,
      lowTemp: 22.0,
      humidity: 68.0,
      precipitation: 0.0,
      pressure: 1013.2,
      windSpeed: 12.5,
      condition: 'Clear',
      sunrise: DateFormat('h:mm a').format(now.copyWith(hour: 6, minute: 24)),
      sunset: DateFormat('h:mm a').format(now.copyWith(hour: 18, minute: 48)),
    );
  }

  void dispose() {
    _client.close();
  }
}
