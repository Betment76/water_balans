import 'package:flutter/material.dart';
import '../models/weather_data.dart';

class WeatherWidget extends StatelessWidget {
  final WeatherData? weatherData;

  const WeatherWidget({super.key, this.weatherData});

  @override
  Widget build(BuildContext context) {
    if (weatherData == null) {
      return const SizedBox.shrink(); // Если данных нет, ничего не показываем
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getWeatherIcon(weatherData!.condition),
          const SizedBox(width: 10),
          Text(
            '${weatherData!.temperature.round()}°C',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return const Icon(Icons.wb_sunny, color: Colors.orange, size: 30);
      case 'Clouds':
        return const Icon(Icons.wb_cloudy, color: Colors.grey, size: 30);
      case 'Rain':
        return const Icon(Icons.beach_access, color: Colors.blue, size: 30);
      case 'Thunderstorm':
        return const Icon(Icons.flash_on, color: Colors.yellow, size: 30);
      default:
        return const Icon(Icons.thermostat, color: Colors.blue, size: 30);
    }
  }
}
