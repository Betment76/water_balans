import 'package:flutter_rustore_review/flutter_rustore_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Сервис для работы с системой отзывов и рейтингов RuStore
class RuStoreReviewService {
  static const String _lastReviewRequestKey = 'last_review_request';
  static const String _reviewRequestCountKey = 'review_request_count';
  static const String _firstLaunchDateKey = 'first_launch_date';

  /// Минимальное количество дней между запросами отзывов
  static const int _minDaysBetweenRequests = 7;

  /// Минимальное количество дней использования приложения перед первым запросом
  static const int _minDaysBeforeFirstRequest = 3;

  /// Максимальное количество запросов отзывов
  static const int _maxRequestCount = 3;

  /// Инициализация RuStore Review SDK
  static Future<void> initialize() async {
    try {
      await RustoreReviewClient.initialize();
      print('RuStore Review SDK инициализирован успешно');

      // Сохраняем дату первого запуска, если её ещё нет
      await _saveFirstLaunchDateIfNeeded();
    } catch (e) {
      print('Ошибка инициализации RuStore Review SDK: $e');
    }
  }

  /// Сохранить дату первого запуска приложения
  static Future<void> _saveFirstLaunchDateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstLaunchDateKey)) {
      await prefs.setString(
        _firstLaunchDateKey,
        DateTime.now().toIso8601String(),
      );
    }
  }

  /// Проверить, можно ли показать запрос на отзыв
  static Future<bool> canRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Проверяем количество запросов
      final requestCount = prefs.getInt(_reviewRequestCountKey) ?? 0;
      if (requestCount >= _maxRequestCount) {
        return false;
      }

      // Проверяем, прошло ли достаточно времени с первого запуска
      final firstLaunchStr = prefs.getString(_firstLaunchDateKey);
      if (firstLaunchStr != null) {
        final firstLaunch = DateTime.parse(firstLaunchStr);
        final daysSinceFirstLaunch = DateTime.now()
            .difference(firstLaunch)
            .inDays;
        if (daysSinceFirstLaunch < _minDaysBeforeFirstRequest) {
          return false;
        }
      }

      // Проверяем, прошло ли достаточно времени с последнего запроса
      final lastRequestStr = prefs.getString(_lastReviewRequestKey);
      if (lastRequestStr != null) {
        final lastRequest = DateTime.parse(lastRequestStr);
        final daysSinceLastRequest = DateTime.now()
            .difference(lastRequest)
            .inDays;
        if (daysSinceLastRequest < _minDaysBetweenRequests) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Ошибка при проверке возможности запроса отзыва: $e');
      return false;
    }
  }

  /// Запросить отзыв у пользователя
  static Future<bool> requestReview() async {
    try {
      // Проверяем, можно ли показать запрос
      if (!await canRequestReview()) {
        print('Запрос отзыва недоступен по условиям');
        return false;
      }

      // Выполняем запрос отзыва
      await RustoreReviewClient.request();

      // Показываем форму отзыва
      await RustoreReviewClient.review();

      // Обновляем статистику запросов
      await _updateRequestStats();

      return true;
    } catch (e) {
      final errorMessage = e.toString();

      if (errorMessage.contains('RuStoreNotInstalled')) {
        print('RuStore не установлен на устройстве');
      } else if (errorMessage.contains('RuStoreOutdated')) {
        print('Версия RuStore устарела');
      } else if (errorMessage.contains('RuStoreUserUnauthorized')) {
        print('Пользователь не авторизован в RuStore');
      } else if (errorMessage.contains('RuStoreRequestLimitReached')) {
        print('Достигнут лимит запросов отзывов');
      } else if (errorMessage.contains('RuStoreReviewExists')) {
        print('Пользователь уже оставил отзыв');
      } else if (errorMessage.contains('RuStoreInvalidReviewInfo')) {
        print('Некорректная информация для отзыва');
      } else {
        print('Ошибка при запросе отзыва: $e');
      }

      return false;
    }
  }

  /// Обновить статистику запросов отзывов
  static Future<void> _updateRequestStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Обновляем дату последнего запроса
      await prefs.setString(
        _lastReviewRequestKey,
        DateTime.now().toIso8601String(),
      );

      // Увеличиваем счётчик запросов
      final currentCount = prefs.getInt(_reviewRequestCountKey) ?? 0;
      await prefs.setInt(_reviewRequestCountKey, currentCount + 1);
    } catch (e) {
      print('Ошибка при обновлении статистики запросов: $e');
    }
  }

  /// Получить статистику запросов отзывов
  static Future<Map<String, dynamic>> getRequestStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'requestCount': prefs.getInt(_reviewRequestCountKey) ?? 0,
        'lastRequest': prefs.getString(_lastReviewRequestKey),
        'firstLaunch': prefs.getString(_firstLaunchDateKey),
        'canRequest': await canRequestReview(),
        'maxRequests': _maxRequestCount,
        'minDaysBetween': _minDaysBetweenRequests,
        'minDaysBeforeFirst': _minDaysBeforeFirstRequest,
      };
    } catch (e) {
      print('Ошибка при получении статистики запросов: $e');
      return {};
    }
  }

  /// Сбросить статистику запросов (внутренний метод)
  static Future<void> _resetRequestStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastReviewRequestKey);
      await prefs.remove(_reviewRequestCountKey);
      await prefs.remove(_firstLaunchDateKey);
      print('Статистика запросов отзывов сброшена');
    } catch (e) {
      print('Ошибка при сбросе статистики запросов: $e');
    }
  }
}
