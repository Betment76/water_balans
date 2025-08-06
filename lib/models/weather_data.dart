/// Модель данных о погоде.
class WeatherData {
  final double temperature;
  final String condition; // Например, 'Clear', 'Clouds', 'Rain', 'Thunderstorm'
  final String? city;

  WeatherData({required this.temperature, required this.condition, this.city});
}
