import 'dart:convert';
import 'package:http/http.dart' as http;

/// Ваш реальный API-ключ OpenWeatherMap
const String openWeatherApiKey = '9ba38d3d83984e17cf9491c36d98def5';

/// Сервис для получения данных о погоде с OpenWeatherMap
class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// Получить температуру по координатам
  static Future<double?> fetchTemperature({
    required double latitude,
    required double longitude,
  }) async {
    print('[WeatherService] fetchTemperature called');
    final url = Uri.parse('$_baseUrl?lat=$latitude&lon=$longitude&units=metric&appid=$openWeatherApiKey');
    try {
      print('[WeatherService] Запрос погоды по координатам: $latitude, $longitude');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['main']['temp'] as num).toDouble();
      } else {
        print('[WeatherService] Ошибка ответа: ${response.statusCode}');
        print('[WeatherService] Тело ответа: ${response.body}');
      }
    } catch (e) {
      print('[WeatherService] Exception: $e');
      return null;
    }
    return null;
  }

  /// Получить температуру по названию города
  static Future<double?> fetchTemperatureByCity(String city) async {
    print('[WeatherService] fetchTemperatureByCity called');
    final url = Uri.parse('$_baseUrl?q=$city&units=metric&appid=$openWeatherApiKey');
    try {
      print('[WeatherService] Запрос погоды по городу: $city');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['main']['temp'] as num).toDouble();
      } else {
        print('[WeatherService] Ошибка ответа: ${response.statusCode}');
        print('[WeatherService] Тело ответа: ${response.body}');
      }
    } catch (e) {
      print('[WeatherService] Exception: $e');
      return null;
    }
    return null;
  }
} 