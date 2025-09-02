import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/weather_data.dart';

/// Сервис для получения данных о погоде через Open-Meteo API (бесплатный)
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// Получить погоду по координатам
  static Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final url =
        '$_baseUrl?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code&timezone=auto';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentWeather = data['current'];

        // Получаем название города по координатам
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        final city = placemarks.isNotEmpty ? placemarks.first.locality : null;

        return WeatherData(
          temperature: currentWeather['temperature_2m'].toDouble(),
          condition: _getConditionFromCode(currentWeather['weather_code']),
          city: city,
        );
      }
    } catch (e) {
      print('Ошибка при загрузке погоды Open-Meteo: $e');
    }
    return null;
  }

  /// Получить погоду по названию города
  static Future<WeatherData?> fetchWeatherByCity(String city) async {
    try {
      // Сначала получаем координаты города
      final geocodingUrl =
          '$_geocodingUrl?name=$city&count=1&language=ru&format=json';
      final geocodingResponse = await http.get(Uri.parse(geocodingUrl));

      if (geocodingResponse.statusCode == 200) {
        final geocodingData = json.decode(geocodingResponse.body);
        final results = geocodingData['results'] as List;

        if (results.isNotEmpty) {
          final location = results.first;
          final latitude = location['latitude'];
          final longitude = location['longitude'];

          // Получаем погоду по координатам
          final weather = await fetchWeather(
            latitude: latitude,
            longitude: longitude,
          );
          return weather?.copyWith(city: city);
        }
      }
    } catch (e) {
      print('Ошибка при загрузке погоды по городу Open-Meteo: $e');
    }
    return null;
  }

  /// Преобразует код погоды Open-Meteo в читаемое состояние
  static String _getConditionFromCode(int code) {
    // Open-Meteo Weather Codes: https://open-meteo.com/en/docs
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Clouds';
    if (code >= 45 && code <= 48) return 'Fog';
    if (code >= 51 && code <= 67) return 'Rain';
    if (code >= 80 && code <= 82) return 'Rain';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 85 && code <= 86) return 'Snow';
    return 'Clear'; // По умолчанию
  }
}
