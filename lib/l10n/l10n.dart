import 'package:flutter/material.dart';

/// Вспомогательный класс для работы с локализацией
class L10n {
  /// Поддерживаемые локализации
  static final supportedLocales = [
    const Locale('ru'),
    const Locale('en'),
  ];

  /// Получение локализации из контекста
  static Locale? localeResolutionCallback(
      Locale? locale, Iterable<Locale> supportedLocales) {
    // Если локаль не определена или не поддерживается, используем русский язык
    if (locale == null || !isSupported(locale)) {
      return const Locale('ru');
    }
    
    return locale;
  }

  /// Проверка, поддерживается ли локаль
  static bool isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}