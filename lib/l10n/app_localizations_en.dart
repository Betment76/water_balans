// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Water Balance';

  @override
  String get homeTitle => 'Home';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profileTitle => 'Profile';

  @override
  String get addWater => 'Add Water';

  @override
  String currentWaterStats(int current, int target) {
    return '$current/$target ml';
  }

  @override
  String temperatureLabel(double temp) {
    return 'Temperature: $temp°C';
  }

  @override
  String get loadingWeather => 'Loading weather...';

  @override
  String get weatherError => 'Weather loading error';

  @override
  String get noWeatherData => 'No weather data';

  @override
  String get refreshWeather => 'Refresh weather';

  @override
  String get last7days => 'Last 7 days';

  @override
  String get averageLabel => 'Average';

  @override
  String get streakLabel => 'Streak';

  @override
  String get settingsSaved => 'Settings saved, notifications updated';

  @override
  String get weight => 'Weight (kg)';

  @override
  String get weightError => 'Enter weight from 30 to 200';

  @override
  String get height => 'Height (cm, optional)';

  @override
  String get heightError => 'Height from 100 to 250';

  @override
  String get activityLevel => 'Activity level';

  @override
  String get activityLow => 'Low';

  @override
  String get activityMedium => 'Medium';

  @override
  String get activityHigh => 'High';

  @override
  String get weatherEnabled => 'Consider weather';

  @override
  String get save => 'Save';

  @override
  String get mlUnit => 'ml';

  @override
  String get daysUnit => 'days';
}
