import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_provider.dart';
import '../services/notification_service.dart';

const Color kBlue = Color(0xFF1976D2);
const Color kLightBlue = Color(0xFF64B5F6);
const Color kWhite = Colors.white;

/// Экран настроек напоминаний
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _notificationsEnabled = true;
  int _intervalHours = 2;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Загрузить настройки из провайдера
  void _loadSettings() {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      setState(() {
        _notificationsEnabled = settings.notificationIntervalHours > 0;
        _intervalHours = settings.notificationIntervalHours;
        _startTime = TimeOfDay(hour: settings.notificationStartHour, minute: 0);
        _endTime = TimeOfDay(hour: settings.notificationEndHour, minute: 0);
      });
    }
  }

  /// Сохранить настройки
  Future<void> _saveSettings() async {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      final updatedSettings = settings.copyWith(
        notificationIntervalHours: _notificationsEnabled ? _intervalHours : 0,
        notificationStartHour: _startTime.hour,
        notificationEndHour: _endTime.hour,
      );

      await ref.read(userSettingsProvider.notifier).save(updatedSettings);

      if (_notificationsEnabled) {
        await NotificationService.scheduleReminders(updatedSettings);
      } else {
        await NotificationService.cancelAllNotifications();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки уведомлений сохранены'),
            backgroundColor: kBlue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Напоминания'),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainSwitch(),
            const SizedBox(height: 24),

            if (_notificationsEnabled) ...[
              _buildIntervalSection(),
              const SizedBox(height: 24),

              _buildTimeSection(),
              const SizedBox(height: 24),

              _buildInfoCard(),
            ] else ...[
              _buildDisabledMessage(),
            ],
          ],
        ),
      ),
    );
  }

  /// Основной переключатель уведомлений
  Widget _buildMainSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _notificationsEnabled ? kBlue : Colors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: kWhite,
            size: 24,
          ),
        ),
        title: const Text(
          'Включить напоминания',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _notificationsEnabled ? 'Уведомления активны' : 'Уведомления отключены',
          style: TextStyle(
            color: _notificationsEnabled ? Colors.green : Colors.grey,
          ),
        ),
        trailing: Switch(
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
            _saveSettings();
          },
          activeColor: kBlue,
        ),
      ),
    );
  }

  /// Секция интервала уведомлений
  Widget _buildIntervalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Интервал уведомлений',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12.0,
          children: List.generate(3, (index) {
            final hour = index + 1;
            return ElevatedButton(
              onPressed: () {
                setState(() {
                  _intervalHours = hour;
                });
                _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _intervalHours == hour ? kBlue : kWhite,
                foregroundColor: _intervalHours == hour ? kWhite : kBlue,
                side: const BorderSide(color: kBlue),
              ),
              child: Text('$hour ч.'),
            );
          }),
        ),
      ],
    );
  }

  /// Секция времени активности
  Widget _buildTimeSection() {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: kBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Время активности',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeCard(
                    title: 'Начало',
                    time: _startTime,
                    onTap: () => _selectTime(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeCard(
                    title: 'Конец',
                    time: _endTime,
                    onTap: () => _selectTime(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка времени
  Widget _buildTimeCard({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kLightBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLightBlue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Информационная карточка
  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: kLightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightBlue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.info_outline,
                color: kWhite,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Уведомления будут приходить каждые $_intervalHours ${_getHourText(_intervalHours)} '
                'с ${_startTime.format(context)} до ${_endTime.format(context)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: kBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Сообщение когда уведомления отключены
  Widget _buildDisabledMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.notifications_off,
              size: 48,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Уведомления отключены',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Включите уведомления, чтобы получать напоминания о питье воды',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Выбор времени
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _saveSettings();
    }
  }

  /// Получить правильную форму слова "час"
  String _getHourText(int hours) {
    if (hours == 1) return 'час';
    if (hours >= 2 && hours <= 4) return 'часа';
    return 'часов';
  }
} 