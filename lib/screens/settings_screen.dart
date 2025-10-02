import 'package:flutter/material.dart';
import 'dart:io'; // фото из профиля
import '../services/storage_service.dart';
import '../models/user_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_settings_provider.dart';
import '../providers/achievements_provider.dart';
import '../services/weather_service.dart';
import 'onboarding_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart'; // версия приложения
import 'package:url_launcher/url_launcher.dart'; // обратная связь
import 'package:file_picker/file_picker.dart'; // выбор файла
import 'package:permission_handler/permission_handler.dart'; // разрешения
import 'package:path_provider/path_provider.dart'; // запасной путь
import 'profile_settings_screen.dart'; // экран профиля
// удалили общий экран
import 'reminders_screen.dart'; // экран напоминаний
import '../services/calculation_service.dart';
import '../services/rustore_review_service.dart';
import '../services/rustore_pay_service.dart';
// import '../services/test_rustore_billing.dart'; // Удалено для релиза
import '../constants/app_colors.dart';
import 'main_navigation_screen.dart';
import '../services/backup_service.dart';

/// Экран настроек пользователя
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController dailyNormController = TextEditingController();

  int activityLevel = 1;
  String selectedUnit = 'мл';
  bool _isProUser = false;
  bool _isAdFree = false;

  String? _weightError;
  String? _heightError;
  double? _temperature;
  bool _isLoadingWeather = false;
  String? _weatherError;
  String _version = ''; // версия
  String _lastSyncText = '—'; // последняя синхронизация
  String _profileName = 'Мой профиль'; // имя из профиля
  String _profileAgeText = '—'; // возраст из профиля
  File? _profileAvatar; // фото профиля

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkProStatus();
    _checkAdFreeStatus();
    _fetchWeather();

    weightController.addListener(_updateDailyNorm);
  }

  void _updateDailyNorm() {
    final weight = int.tryParse(weightController.text);
    if (weight != null && weight > 0) {
      // 🌡️ Добавка от погоды только при температуре 30°C и выше
      int weatherAddition = 0;
      if (_temperature != null && _temperature! >= 30) {
        // Каждый градус от 30°C добавляет 50 мл (максимум 500 мл при 40°C)
        weatherAddition = ((_temperature! - 30) * 50).clamp(0, 500).round();
      }
      
      final norm = CalculationService.calculateDailyNorm(
        weight: weight,
        activityLevel: activityLevel,
        weatherAddition: weatherAddition,
      );
      
      // 🔧 ДИАГНОСТИКА расчета нормы
      print('🔧 РАСЧЕТ НОРМЫ:');
      print('  Вес: $weight кг');
      print('  Активность: $activityLevel (${[0, 250, 500][activityLevel.clamp(0,2)]} мл)');
      print('  Температура: $_temperature°C');
      print('  Погодная добавка: $weatherAddition мл');
      print('  ИТОГОВАЯ НОРМА: $norm мл');
      
      dailyNormController.text = norm.toString();
    }
  }

  /// Загрузить настройки из хранилища
  void _loadSettings() {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      weightController.text = settings.weight.toString();
      heightController.text = settings.height?.toString() ?? '';
      // Нормализуем уровень активности к 3 градациям: 0-низкий,1-средний,2-высокий
      final savedLevel = settings.activityLevel;
      activityLevel = savedLevel <= 2 ? savedLevel : (((savedLevel - 1) / 2).round()).clamp(0, 2);
      selectedUnit = settings.unit;
      
      // 🔄 ПРИНУДИТЕЛЬНО пересчитываем норму с новой логикой
      print('🔧 ДИАГНОСТИКА: Старая норма = ${settings.dailyNormML} мл');
      _updateDailyNorm();
      
      // Автоматически сохраняем новую норму и обновляем достижения
      Future.delayed(const Duration(milliseconds: 500), () async {
        final newNorm = int.tryParse(dailyNormController.text);
        if (newNorm != null && newNorm != settings.dailyNormML) {
          print('🔧 АВТОСОХРАНЕНИЕ: Обновляем норму с ${settings.dailyNormML} на $newNorm мл');
          _saveSettings();
          
          // 🏆 Обновляем достижения с новой нормой
          try {
            final achievementsService = ref.read(achievementsServiceProvider);
            await achievementsService.initialize(dailyNormML: newNorm, forceReset: false);
            print('🏆 Достижения обновлены для новой нормы $newNorm мл');
          } catch (e) {
            print('❌ Ошибка обновления достижений: $e');
          }
        }
      });
    }
    // 🧑‍💼 Загружаем профиль: имя/дата рождения/аватар
    () async {
      final name = await StorageService.getString('profile_name');
      final birthStr = await StorageService.getString('profile_birthdate');
      final avatarPath = await StorageService.getString('profile_avatar_path');
      DateTime? birth;
      if (birthStr != null) {
        birth = DateTime.tryParse(birthStr) ?? _tryParseRuDate(birthStr);
      }
      if (mounted) {
        setState(() {
          _profileName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Мой профиль';
          _profileAgeText = birth != null ? '${_age(birth)} лет' : '—';
          _profileAvatar = (avatarPath != null && File(avatarPath).existsSync()) ? File(avatarPath) : null;
        });
      }
    }();

    // 🏷️ Читаем время последнего бэкапа
    StorageService.getString('cloud_last_sync').then((ts) {
      if (!mounted) return;
      setState(() {
        _lastSyncText = ts != null
            ? _formatRelative(DateTime.tryParse(ts))
            : '—';
      });
    });
    // 📦 Версия приложения
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() => _version = '${p.version}+${p.buildNumber}');
    });
  }
  // Возраст (в годах)
  int _age(DateTime birth) {
    final now = DateTime.now();
    var a = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) a--;
    return a;
  }

  // Парсим ДД.ММ.ГГГГ
  DateTime? _tryParseRuDate(String value) {
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (m == null) return null;
    try {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }


  Future<void> _checkProStatus() async {
    final isPro = await StorageService.isProUser();
    setState(() {
      _isProUser = isPro;
    });
  }

  Future<void> _checkAdFreeStatus() async {
    try {
      final isAdFree = await RustorePayService.isAdFree();
      setState(() {
        _isAdFree = isAdFree;
      });
    } catch (e) {
      print('Ошибка проверки статуса без рекламы: $e');
    }
  }

  Future<void> _fetchWeather() async {
    setState(() { _isLoadingWeather = true; _weatherError = null; });
    try {
      // Синхронизируем с логикой главного экрана: сначала геолокация, иначе Москва
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition();
        final weather = await WeatherService.fetchWeather(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted) return;
        setState(() { _temperature = weather?.temperature; });
      } else {
        // Без координат погоду не показываем
        setState(() { _temperature = null; });
      }
      if (_temperature == null) {
        setState(() { _weatherError = 'Ошибка загрузки погоды'; });
      }
      _updateDailyNorm();
    } catch (e) {
      if (!mounted) return;
      setState(() { _weatherError = 'Ошибка: $e'; });
    } finally {
      if (mounted) setState(() { _isLoadingWeather = false; });
    }
  }

  @override
  void dispose() {
    weightController.removeListener(_updateDailyNorm);
    weightController.dispose();
    heightController.dispose();
    dailyNormController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    setState(() {
      _weightError = null;
      _heightError = null;
    });

    final weight = int.tryParse(weightController.text);
    final height = heightController.text.isNotEmpty
        ? int.tryParse(heightController.text)
        : null;
    final dailyNorm = int.tryParse(dailyNormController.text);

    if (weight == null || weight < 30 || weight > 200) {
      setState(() => _weightError = 'Введите вес от 30 до 200');
      return;
    }
    if (height != null && (height < 100 || height > 250)) {
      setState(() => _heightError = 'Рост от 100 до 250');
      return;
    }

    final settings = UserSettings(
      weight: weight,
      height: height,
      activityLevel: activityLevel,
      dailyNormML: dailyNorm ?? 0, // dailyNorm не может быть null
      isWeatherEnabled: true,
      notificationIntervalHours: 2,
      unit: selectedUnit,
    );

    ref.read(userSettingsProvider.notifier).save(settings);
    NotificationService.scheduleReminders(settings);

    // 🕒 Запоминаем время сохранения для карточки профиля
    StorageService.setString('lastSettingsSaved', DateTime.now().toIso8601String());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Настройки сохранены')));
  }

  /// 💾 Сохранить бэкап локально (SharedPreferences)
  Future<void> _performBackup() async {
    try {
      final json = await StorageService.exportAllToJson();
      await StorageService.setString('cloud_backup_json', json);
      final now = DateTime.now().toIso8601String();
      await StorageService.setString('cloud_last_sync', now);
      if (mounted) {
        setState(() {
          _lastSyncText = _formatRelative(DateTime.tryParse(now));
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бэкап сохранён локально')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка бэкапа: $e')));
      }
    }
  }

  /// ♻️ Восстановить из выбранного JSON файла
  Future<void> _performRestore() async {
    try {
      final path = await BackupService().restoreFromBackupFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path == null ? 'Восстановление отменено' : 'Данные восстановлены из: ${path.split('/').last}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка восстановления: $e')));
      }
    }
  }

  /// 💾 Сохранение бэкапа в выбранный пользователем файл (перезапись последнего)
  Future<void> _performBackupToFile() async {
    try {
      final path = await BackupService().createBackupToFile();
      if (!mounted || path == null) return;
      setState(() { _lastSyncText = _formatRelative(DateTime.now()); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено: ${path.split('/').last}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  /// 📂 Диалог выбора места сохранения (пока локально)
  void _showBackupDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Куда сохранить бэкап'),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Color(0xFF1976D2)),
                title: const Text('Сохранить в файл (Документы)'),
                subtitle: const Text('JSON резервная копия'),
                onTap: () async {
                  Navigator.pop(context);
                  await _performBackupToFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс данных'),
        content: const Text(
          'Вы уверены, что хотите сбросить все данные? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StorageService.clearAllData();
        await NotificationService.cancelAllNotifications();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Данные сброшены')));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка сброса: $e')));
        }
      }
    }
  }

  /// Запросить отзыв у пользователя
  Future<void> _requestReview() async {
    try {
      final success = await RuStoreReviewService.requestReview();
      if (mounted) {
        String message;
        Color backgroundColor;

        if (success) {
          message = 'Отзыв успешно запрощен!';
          backgroundColor = Colors.green;
        } else {
          // Получаем статистику для более детального объяснения
          final stats = await RuStoreReviewService.getRequestStats();
          final canRequest = stats['canRequest'] as bool? ?? false;
          final requestCount = stats['requestCount'] as int? ?? 0;
          final maxRequests = stats['maxRequests'] as int? ?? 3;

          if (!canRequest && requestCount >= maxRequests) {
            message = 'Достигнут лимит запросов (макс. $maxRequests)';
          } else if (!canRequest) {
            message = 'Отзыв можно запросить через несколько дней';
          } else {
            message =
                'Невозможно показать отзыв:\n'
                '• RuStore не установлен на устройстве\n'
                '• Пользователь не авторизован в RuStore\n'
                '• Приложение не опубликовано в RuStore';
          }
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Показать статистику отзывов
  Future<void> _showReviewStats() async {
    try {
      final stats = await RuStoreReviewService.getRequestStats();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Статистика отзывов'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Количество запросов: ${stats['requestCount']} / ${stats['maxRequests']}",
                ),
                const SizedBox(height: 8),
                Text("Можно запросить: ${stats['canRequest'] ? 'Да' : 'Нет'}"),
                const SizedBox(height: 8),
                if (stats['lastRequest'] != null)
                  Text(
                    "Последний запрос: ${DateTime.parse(stats['lastRequest']).toString().substring(0, 16)}",
                  ),
                const SizedBox(height: 8),
                if (stats['firstLaunch'] != null)
                  Text(
                    "Первый запуск: ${DateTime.parse(stats['firstLaunch']).toString().substring(0, 16)}",
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Правила:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("• Мин. дней между запросами: ${stats['minDaysBetween']}"),
                Text(
                  "• Мин. дней перед первым запросом: ${stats['minDaysBeforeFirst']}",
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения статистики: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Покупка отключения рекламы
  Future<void> _purchaseRemoveAds() async {
    try {
      final success = await RustorePayService.purchaseRemoveAds();
      if (mounted) {
        String message;
        Color backgroundColor;

        if (success) {
          await _checkAdFreeStatus(); // Обновляем статус
          message = 'Покупка успешно завершена! Реклама отключена.';
          backgroundColor = Colors.green;
        } else {
          message = 'Покупка не удалась. Попробуйте позже.';
          backgroundColor = Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка покупки: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Восстановление покупок
  Future<void> _restorePurchases() async {
    try {
      await RustorePayService.restorePurchases();
      if (mounted) {
        final isAdFree = await RustorePayService.isAdFree();
        String message;
        Color backgroundColor;

        if (isAdFree) {
          message = 'Покупки успешно восстановлены! Реклама отключена.';
          backgroundColor = Colors.green;
        } else {
          message = 'Активные покупки не найдены.';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка восстановления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки', style: TextStyle(color: Colors.white)), // заголовок
        centerTitle: true,
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 86, left: 16, right: 16, bottom: 16), // отступ под глобальный баннер
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              _buildProfileHeaderCard(), // карточка профиля
              const SizedBox(height: 12),
              _buildSettingsListCard(), // список настроек
              const SizedBox(height: 12),
              _buildSupportListCard(), // поддержка
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Version ${_version.isEmpty ? '—' : _version}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 👤 Карточка профиля в стиле макета
  Widget _buildProfileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0,6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE3F2FD),
                backgroundImage: _profileAvatar != null ? FileImage(_profileAvatar!) : null,
                child: _profileAvatar == null ? const Icon(Icons.person, color: Color(0xFF1976D2)) : null,
              ),
              const SizedBox(width: 16),
                  Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _profileAgeText == '—' ? _profileName : '$_profileName, $_profileAgeText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: _showBackupDialog, // сохранить бэкап
                      icon: const Icon(Icons.sync, color: Color(0xFF1976D2)),
                      tooltip: 'Сохранить бэкап',
                    ),
                  ],
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _performRestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Восстановить'),
              ),
              const Spacer(),
              Text(
                _lastSyncText,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ⚙️ Список настроек (как на скрине)
  Widget _buildSettingsListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0,6))],
      ),
      child: Column(
                children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.emoji_emotions, color: Color(0xFF1976D2))),
            title: const Text('Мой Профиль', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.alarm, color: Color(0xFFF57C00))),
            title: const Text('Настройка уведомлений', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.language, color: Color(0xFFF57C00))),
            title: const Text('Язык', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Text('Русский'),
            onTap: () {}, // зарезервировано под выбор языка
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE0F7FA), child: Icon(Icons.straighten, color: Color(0xFF00ACC1))),
            title: const Text('Единицы измерения', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text(selectedUnit.toUpperCase()),
            onTap: _showUnitPicker,
                  ),
                ],
              ),
    );
  }

  /// 💬 Поддержка/покупки/оценка
  Widget _buildSupportListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0,6))],
      ),
      child: Column(
                children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.no_adult_content, color: Color(0xFF388E3C))),
            title: const Text('Убрать рекламу', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isAdFree ? null : _purchaseRemoveAds,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFFDE7), child: Icon(Icons.star, color: Color(0xFFFFB300))),
            title: const Text('Оцените нас', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _requestReview,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.edit, color: Color(0xFF1976D2))),
            title: const Text('Обратная связь', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              // Открываем почту
              final uri = Uri.parse('mailto:support@example.com?subject=Water%20Balance%20Feedback');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
                  ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.slideshow, color: Color(0xFF1976D2))),
            title: const Text('Показать экран первого входа', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    ),
                  ),
                ],
              ),
    );
  }

  /// 🗓️ Формат «вчера/сегодня/дата»
  String _formatRelative(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final n = DateTime(now.year, now.month, now.day);
    if (d == n) return 'сегодня';
    if (d.add(const Duration(days: 1)) == n) return 'вчера';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  /// Выбор единиц измерения (мл / л / oz)
  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Миллилитры (мл)'),
                trailing: selectedUnit == 'мл' ? const Icon(Icons.check, color: Color(0xFF1976D2)) : null,
                onTap: () {
                  setState(() => selectedUnit = 'мл');
                  Navigator.pop(context);
                  _saveSettings();
                },
              ),
              ListTile(
                title: const Text('Литры (л)'),
                trailing: selectedUnit == 'л' ? const Icon(Icons.check, color: Color(0xFF1976D2)) : null,
                onTap: () {
                  setState(() => selectedUnit = 'л');
                  Navigator.pop(context);
                  _saveSettings();
                },
              ),
              ListTile(
                title: const Text('Унции (oz)'),
                trailing: selectedUnit == 'oz' ? const Icon(Icons.check, color: Color(0xFF1976D2)) : null,
                onTap: () {
                  setState(() => selectedUnit = 'oz');
                  Navigator.pop(context);
                  _saveSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🎨 Стильный заголовок экрана
  Widget _buildStylishHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 70, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
                children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Настройки', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Персонализируй свой опыт', 
                style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ],
          ),
    );
  }

  /// 🎭 Карточка настроек с градиентом
  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Заголовок с градиентом
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
                children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Содержимое карточки
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
                    ),
                  ),
                ],
      ),
    );
  }

  /// 🧩 Компактная карточка (плоская, без большого хедера)
  Widget _buildCompactCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  /// 📝 Стильное текстовое поле
  Widget _buildStylishTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? error,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null ? Colors.red.shade300 : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  /// 📏 Строка с текстовыми полями
  Widget _buildTextFieldRow(List<Widget> fields) {
    return Row(
            children: [
        for (int i = 0; i < fields.length; i++) ...[
          fields[i],
          if (i < fields.length - 1) const SizedBox(width: 12),
        ]
      ],
    );
  }

  /// 🍬 Всплывающее сообщение
  void _showSnack(String message) {
    // Показываем краткое уведомление пользователю
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// ⚡ Быстрое действие (иконка + подпись)
  // Используем локальный виджет для компактных кнопок
  // Комментарии на русском для ясности
  Widget _QuickAction({required IconData icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
              ),
            ],
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Icon(icon, color: const Color(0xFF1976D2), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  /// 🏃 Слайдер уровня активности
  Widget _buildActivitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Уровень активности',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Низкий', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('Уровень $activityLevel', 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Высокий', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Slider(
                value: activityLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    activityLevel = value.toInt();
                  });
                  _updateDailyNorm();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 💧 Отображение дневной нормы
  Widget _buildDailyNormRow() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.local_drink, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('Дневная норма', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text('${dailyNormController.text} мл',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// 🌤️ Секция погоды
  Widget _buildWeatherSection() {
    return Column(
            children: [
        if (_isLoadingWeather)
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Получение данных о погоде...')
            ],
          )
        else if (_weatherError != null)
          Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(_weatherError!, style: const TextStyle(color: Colors.red))),
            ],
          )
        else if (_temperature != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.thermostat, color: Colors.orange.shade600, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущая температура: ${_temperature!.round()}°C',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                      _temperature! >= 30 ? 'Жаркая погода - норма увеличена' : 'Комфортная погода',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          ),
      ],
    );
  }

  /// Краткий вид погоды для компактной карточки
  Widget _buildWeatherSummary() {
    if (_isLoadingWeather) {
      return const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Загрузка...')]);
    }
    if (_weatherError != null) {
      return Row(children: [Icon(Icons.error, color: Colors.red.shade400, size: 18), const SizedBox(width: 8), Expanded(child: Text(_weatherError!, maxLines: 2))]);
    }
    if (_temperature != null) {
      final hot = _temperature! >= 30;
      return Row(children: [
        Icon(Icons.thermostat, color: hot ? Colors.orange : Colors.blue, size: 20),
        const SizedBox(width: 8),
        Text('${_temperature!.round()}°C'),
        const SizedBox(width: 8),
        Text(hot ? 'Жара' : 'Комфорт', style: TextStyle(color: Colors.grey.shade600)),
      ]);
    }
    return const Text('Нет данных');
  }

  /// 🔔 Настройки уведомлений
  Widget _buildNotificationSettings() {
    return const Column(
            children: [
              ListTile(
          leading: Icon(Icons.alarm, color: Colors.blue),
          title: Text('Настройка напоминаний'),
          subtitle: Text('Перейдите в раздел "Напоминания" для настройки'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// 💎 Премиум секция
  Widget _buildPremiumSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.remove_circle_outline, color: Colors.orange),
          title: Text(_isAdFree ? 'Реклама отключена' : 'Отключить рекламу'),
          subtitle: Text(_isAdFree ? 'Спасибо за поддержку!' : 'Убрать рекламные баннеры'),
                trailing: _isAdFree
                    ? const Icon(Icons.check, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios, size: 16),
          contentPadding: EdgeInsets.zero,
                onTap: _isAdFree ? null : _purchaseRemoveAds,
              ),
        if (!_isAdFree) const SizedBox(height: 12),
        if (!_isAdFree)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.purple),
                title: const Text('Восстановить покупки'),
                subtitle: const Text('Проверить существующие покупки'),
            contentPadding: EdgeInsets.zero,
                onTap: _restorePurchases,
              ),
            ],
    );
  }

  /// ⭐ Секция отзывов
  Widget _buildReviewSection() {
    return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Оценить приложение'),
                subtitle: const Text('Оставьте отзыв в RuStore'),
          contentPadding: EdgeInsets.zero,
                onTap: _requestReview,
              ),
        const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text('Статистика отзывов'),
                subtitle: const Text('Показать информацию о запросах'),
          contentPadding: EdgeInsets.zero,
                onTap: _showReviewStats,
              ),
            ],
    );
  }

  /// ⚠️ Опасная зона
  Widget _buildDangerZone() {
    return ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Сбросить все данные'),
                subtitle: const Text('Удалить все настройки и историю'),
      contentPadding: EdgeInsets.zero,
                onTap: _resetData,
    );
  }

  /// 💾 Стильная кнопка сохранения (полноразмерная)
  Widget _buildStylishSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
              ),
            ],
          ),
      child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
      children: [
            Icon(Icons.save, color: Colors.white, size: 24),
            SizedBox(width: 12),
        Text(
              'Сохранить настройки',
              style: TextStyle(
                color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💾 Кнопка для компактной карточки
  Widget _buildPrimarySaveButton({bool textless = false}) {
    return ElevatedButton.icon(
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.save),
      label: textless ? const SizedBox.shrink() : const Text('Сохранить'),
    );
  }
}
