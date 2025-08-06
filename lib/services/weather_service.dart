import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/weather_data.dart';

/// Сервис для получения данных о погоде
class WeatherService {
  static const String _apiKey = '9ba38d3d83984e17cf9491c36d98def5'; // Замените на ваш ключ OpenWeatherMap
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// Получить погоду по координатам
  static Future<WeatherData?> fetchWeather({required double latitude, required double longitude}) async {
    final url = '$_baseUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        final city = placemarks.isNotEmpty ? placemarks.first.locality : null;
        return WeatherData(
          temperature: data['main']['temp'],
          condition: data['weather'][0]['main'],
          city: city,
        );
      }
    } catch (e) {
      print('Ошибка при загрузке погоды: $e');
    }
    return null;
  }

  /// Получить погоду по названию города
  static Future<WeatherData?> fetchWeatherByCity(String city) async {
    final url = '$_baseUrl?q=$city&appid=$_apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData(
          temperature: data['main']['temp'],
          condition: data['weather'][0]['main'],
          city: city,
        );
      }
    } catch (e) {
      print('Ошибка при загрузке погоды: $e');
    }
    return null;
  }
} 