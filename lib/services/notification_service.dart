import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/user_settings.dart';

/// Сервис для работы с локальными уведомлениями
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Инициализация уведомлений
  static Future initialize() async {
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

  /// Отключить все уведомления
  static Future cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Отменить все уведомления (алиас для cancelAll)
  static Future cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
