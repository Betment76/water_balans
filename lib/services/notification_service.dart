import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/user_settings.dart';

/// Сервис для работы с локальными уведомлениями
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Инициализация уведомлений
  static Future initialize() async {
    // Инициализируем таймзоны (без этого расписание может не работать корректно)
    tzdata.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _notifications.initialize(settings);

    // Запрашиваем разрешения (Android 13+ и iOS)
    if (Platform.isAndroid) {
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImpl = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isMacOS) {
      final macImpl = _notifications.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      await macImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Запланировать напоминания по пользовательским настройкам
  static Future scheduleReminders(UserSettings settings, {DateTime? lastIntake}) async {
    await _notifications.cancelAll();
    final now = DateTime.now();
    final int startHour = settings.notificationStartHour;
    final int endHour = settings.notificationEndHour;
    final int interval = settings.notificationIntervalHours;
    final bool smartMode = true; // Можно вынести в настройки
    final bool disableAtNight = true;

    DateTime firstTime = DateTime(now.year, now.month, now.day, startHour);

    if (lastIntake != null && smartMode) {
      // Если "умный режим" — уведомление через интервал после последнего приёма
      firstTime = lastIntake.add(Duration(hours: interval));
      if (firstTime.hour < startHour) {
        firstTime = DateTime(now.year, now.month, now.day, startHour);
      }
      if (firstTime.hour > endHour) {
        return; // Не планируем уведомления на ночь
      }
    }

    if (interval <= 0) return; // если напоминания выключены

    for (int hour = firstTime.hour; hour <= endHour; hour += interval) {
      if (disableAtNight && (hour < startHour || hour > endHour)) continue;

      final scheduled = DateTime(now.year, now.month, now.day, hour);
      if (scheduled.isBefore(now)) continue;

      await _notifications.zonedSchedule(
        hour, // id
        'Пейте воду!',
        'Ваша норма: ${settings.dailyNormML} мл',
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'water_reminder', 'Напоминания о воде',
              channelDescription: 'Регулярные напоминания пить воду',
              importance: Importance.max,
              priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Быстрая проверка статуса разрешений (для диагностики)
  static Future<Map<String, dynamic>> checkPermissionsStatus() async {
    final result = <String, dynamic>{};
    if (Platform.isAndroid) {
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImpl?.areNotificationsEnabled();
      result['post_notifications_granted'] = granted ?? false;
    } else if (Platform.isIOS) {
      final iosImpl = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await iosImpl?.requestPermissions();
      result['permissions_granted'] = granted ?? false;
    } else if (Platform.isMacOS) {
      final macImpl = _notifications.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await macImpl?.requestPermissions();
      result['permissions_granted'] = granted ?? false;
    }
    return result;
  }

  /// Отключить все уведомления
  static Future cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Отменить все уведомления (алиас для cancelAll)
  static Future cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
