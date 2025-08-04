// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Водный баланс';

  @override
  String get homeTitle => 'Главная';

  @override
  String get statsTitle => 'Статистика';

  @override
  String get settingsTitle => 'Персонализация';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get addWater => 'Добавить воду';

  @override
  String currentWaterStats(int current, int target) {
    return '$current/$target мл';
  }

  @override
  String temperatureLabel(double temp) {
    return 'Температура: $temp°C';
  }

  @override
  String get loadingWeather => 'Загрузка погоды...';

  @override
  String get weatherError => 'Ошибка загрузки погоды';

  @override
  String get noWeatherData => 'Нет данных о погоде';

  @override
  String get refreshWeather => 'Обновить погоду';

  @override
  String get last7days => 'Последние 7 дней';

  @override
  String get averageLabel => 'Среднее';

  @override
  String get streakLabel => 'Серия';

  @override
  String get settingsSaved => 'Настройки сохранены, уведомления обновлены';

  @override
  String get weight => 'Вес (кг)';

  @override
  String get weightError => 'Введите вес от 30 до 200';

  @override
  String get height => 'Рост (см, опционально)';

  @override
  String get heightError => 'Рост от 100 до 250';

  @override
  String get activityLevel => 'Уровень активности';

  @override
  String get activityLow => 'Низкий';

  @override
  String get activityMedium => 'Средний';

  @override
  String get activityHigh => 'Высокий';

  @override
  String get weatherEnabled => 'Учитывать погоду';

  @override
  String get save => 'Сохранить';

  @override
  String get mlUnit => 'мл';

  @override
  String get daysUnit => 'дней';
}
