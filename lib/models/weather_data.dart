/// Модель данных о погоде.
class WeatherData {
  final double temperature;
  final String condition; // Например, 'Clear', 'Clouds', 'Rain', 'Thunderstorm'
  final String? city;

  WeatherData({required this.temperature, required this.condition, this.city});

  /// Создает копию объекта с измененными полями
  WeatherData copyWith({double? temperature, String? condition, String? city}) {
    return WeatherData(
      temperature: temperature ?? this.temperature,
      condition: condition ?? this.condition,
      city: city ?? this.city,
    );
  }
}
